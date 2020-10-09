		.z180

#target		bin
#code		TEXT, $100
#data		DATA, *

YM_SOH		equ	$01			; start of a 128-byte packet
YM_STX		equ	$02			; start of a 1024-byte packet
YM_EOT		equ	$04			; end of transmission
YM_ACK		equ	$06			; received ok
YM_NAK		equ	$15			; receive error
YM_CAN		equ	$18			; cancel transmission
YM_CRC		equ	'C'			; request CRC-16 mode

#include	"src/z180registers.z80"
#include	"src/tbios.z80"

#code		TEXT

		org	$100
start:		ld	de, welcome
		ld	c, CPM_WRITESTR
		call	5

		call	receive

		rst	0

welcome:	.text	'YModem receive ready',13,10,'$'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; receive
;;
;; Receive files and write to current disk
#local
receive::

receive_file:	ld	c, YM_CRC
		ld	hl, recvbuf
		call	recv_packet
		jp	z, abort

		cp	a, YM_EOT
		jp	z, ack_eot

		; a NUL filename indicates all done
		ld	a, (hl)
		or	a
		jp	z, complete

		;; set up the FCB for file creation
		xor	a
		ld	(fcb), a			; default drive
		ld	(fcb+12), a			; EX=0
		ld	(fcb+14), a			; S2=0
		ld	(fcb+15), a			; RC=0
		ld	(fcb+32), a			; CR=0

		;; erase the filename in the FCB
		push	hl
		ld	a, $20
		ld	(fcb+1), a
		ld	hl, fcb+1
		ld	de, fcb+2
		ld	bc, 10
		ldir
		pop	hl

		;; extract filename from YModem metadata block to FCB
		ld	b, 9
		ld	de, fcb+1
loadfn:		ld	a, (hl)
		or	a
		jr	z, fndone
		cp	a, '.'
		jr	z, loadext
		dec	b
		jp	z, fnbad1
		ld	a, (hl)
		call	checkfn
		jp	c, fnbad2
		ld	(de), a
		inc	de
		inc	hl
		jr	loadfn

loadext:	ld	bc, 4
		ld	de, fcb+9
		inc	hl
extloop:	ld	a, (hl)
		or	a
		jr	z, fndone
		dec	bc
		ld	a, b
		or	c
		jp	z, fnbad3
		ld	a, (hl)
		call	checkfn
		jp	c, fnbad4
		ld	(de), a
		inc	de
		inc	hl
		jr	extloop

fndone:		ld	de, fcb
		ld	c, CPM_FDELETE		; delete the file, if it exists
		call	5			; ignore result

		ld	de, fcb
		ld	c, CPM_FMAKE
		call	5
		inc	a
		jr	z, ferror

		ld	e, YM_ACK
		ld	c, ERAWOUT
		rst	$30
		ld	e, YM_CRC
		ld	c, ERAWOUT
		rst	$30

		ld	a, 1
		ld	(block_nr), a
		ld	c, YM_CRC
receive_data:	ld	hl, recvbuf
		call	recv_packet
		cp	a, YM_EOT	; EOT indicates file transfer complete
		jr	z, eot_file
		ld	b, a
		ld	a, (block_nr)
		cp	a, c
		jr	nz, block_error
		inc	a
		ld	(block_nr), a	; update block number
		ld	a, b

		;; SOH writes one 128-byte sector, STX writes 8 sectors
		ld	b, 1
		cp	a, YM_SOH
		jr	z, $+4
		ld	b, 8
		ld	de, recvbuf
		ld	hl, 128
write_file:	
		push	bc
		push	de
		push	hl
		ld	c, CPM_DMAOFF
		call	5
		ld	de, fcb
		ld	c, CPM_FWRITE
		call	5
		pop	hl
		pop	de
		pop	bc
		ex	de, hl
		add	hl, de
		ex	de, hl
		djnz	write_file

		ld	e, YM_ACK
		ld	c, ERAWOUT
		rst	$30
		ld	c, YM_ACK
		jr	receive_data	; go back for next block

eot_file:	ld	de, fcb
		ld	c, CPM_FCLOSE
		call	5

ack_eot:	ld	e, YM_ACK
		ld	c, ERAWOUT
		rst	$30
		ld	e, YM_CRC
		ld	c, ERAWOUT
		rst	$30
		jp	receive_file

ferror:		ld	e, YM_CAN
		ld	c, ERAWOUT
		rst	$30
		ld	e, YM_CAN
		ld	c, ERAWOUT
		rst	$30
		call	flush_rx
		ld	de, msg_ferror
		jr	print

abort: 		ld	e, YM_CAN
		ld	c, ERAWOUT
		rst	$30
		ld	e, YM_CAN
		ld	c, ERAWOUT
		rst	$30
		call	flush_rx
		ld	de, msg_aborted
		jr	print

block_error:	dec	a		; might be last block re-sent?
		cp	a, c
		jr	nz, abort	; alas no, give up
		ld	e, YM_ACK	; if yes, re-ACK it
		ld	c, ERAWOUT
		rst	$30
		jp	receive_data

complete:	ld	e, YM_ACK
		ld	c, ERAWOUT
		rst	$30
		call	flush_rx
		ld	de, msg_complete
print:		ld	c, CPM_WRITESTR
		call	5

		ret

fnbad1:		ld	de, msg_badfn1
		ld	(badmsg), de
		jr	fnbad
fnbad2:		ld	de, msg_badfn2
		ld	(badmsg), de
		jr	fnbad
fnbad3:		ld	de, msg_badfn3
		ld	(badmsg), de
		jr	fnbad
fnbad4:		ld	de, msg_badfn4
		ld	(badmsg), de
fnbad:		ld	e, YM_CAN
		ld	c, ERAWOUT
		rst	$30
		ld	e, YM_CAN
		ld	c, ERAWOUT
		rst	$30
		call	flush_rx
		ld	de, (badmsg)
		jr	print

bail:		ld	e, YM_CAN
		ld	c, ERAWOUT
		rst	$30
		ld	e, YM_CAN
		ld	c, ERAWOUT
		rst	$30
		rst	0

badmsg		.dw	msg_badfn1
msg_aborted:	.text	'aborted', 13, 10, '$'
msg_complete:	.text	'complete', 13, 10, '$'
msg_badfn1:	.text	'invalid filename 1', 13, 10, '$'
msg_badfn2:	.text	'invalid filename 2', 13, 10, '$'
msg_badfn3:	.text	'invalid filename 3', 13, 10, '$'
msg_badfn4:	.text	'invalid filename 4', 13, 10, '$'
msg_ferror:	.text	'file system error', 13, 10, '$'

cmd		.ds	1		; the received command byte
block_nr	.ds	1		; the expected block number

#endlocal

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; checkfn - check character for validity in a file name
;;
;; in		a	the character to test
;; out		a	the modified character
;;		f	CF set on invalid
#local
checkfn::
		cp	' '+1		; space and control chars
		ret	c
		cp	':'		; ':' to '?' are illegal
		jr	c, digit
		cp	'?'+1
		ret	c

digit:		cp	'.'
		jr	z, bad
		cp	','
		jr	z, bad
		cp	'*'
		jr	z, bad
		cp	'_'
		jr	z, bad

		cp	'a'
		jr	c, good
		cp	'z'+1
		jr	nc, good

		; convert a-z to upper case
		and	01011111b

good:		and	01111111b
		ret
bad:		scf
		ret
#endlocal

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; recv_packet
;;
;; Receive a Y-Modem packet, retrying up to ten times.
;;
;; in:		hl	destination of packet (1026 bytes required)
;; 		c	the byte to send in case of timeout
;; out:		zf	set on error
;;		a	the command code received
;;		c	the packet sequence number
;;		b	the number of retries remaining
#local
recv_packet::	push	de
		push	hl

		ld	a, c
		ld	(metadata+1), a

		ld	b, 10		; retry ten times
		jr	read_cmd

metadata:	ld	e, 0
		ld	c, ERAWOUT
		rst	$30

read_cmd:	ld	de, 5*100
		call	recv_byte
		jr	z, retry

		cp	a, YM_CAN	; Cancel?
		jr	z, cancel

		cp	a, YM_EOT	; End of transmission?
		jr	z, eot

		cp	a, YM_SOH
		jr	z, recv_body

		cp	a, YM_STX
		jr	z, recv_body

		call	flush_rx	; anything else, clear it out and retry

retry:		djnz	metadata
		xor	a		; djnz doesn't set zf, so set it here

done:		pop	hl
		pop	de
		ret

cancel:		ld	de, 5*100
		call	recv_byte
		jr	z, retry
		cp	a, YM_CAN
		jr	z, done
		jr	retry

eot:		or	a		; clear zf - a contains a non-zero value
		jr	done

recv_body:	ld	(cmd), a
		ld	de, 1*100
		call	recv_byte
		jr	z, retry
		ld	c, a
		call	recv_byte
		jr	z, retry
		cpl
		cp	a, c
		jr	nz, retry
		ld	(seq), a

		pop	hl

		push	hl
		push	bc

		ld	bc, 130
		ld	a, (cmd)
		cp	a, YM_SOH
		jr	z, $+5
		ld	bc, 1026

		push	hl
		push	bc

		ld	de, 1*100
		call	recv_wait

		pop	bc
		pop	hl

		jr	z, body_retry

		ld	de, 0
		call	ym_crc		; CRC should be zero

		pop	bc

		ld	a, d
		or	e
		jr	nz, retry
		ld	a, (seq)
		ld	c, a
		ld	a, (cmd)
		or	a		; clear zf
		jr	done

body_retry:	pop	bc
		jr	retry

cmd:		.db	0
seq:		.db	0

#endlocal

#local
recv_byte::
		push	bc
		push	de
		push	hl

		; reset PRT0 counter flag
		in0	a, (TCR)
		in0	a, (TMDR0L)
		in0	a, (TMDR0H)

waitc:		push	de
		ld	c, ERAWIN
		rst	$30
		pop	de
		jr	nz, return

		in0	a, (TCR)		; check if timer has fired
		tst	01000000b
		jr	z, waitc
		in0	a, (TMDR0L)
		in0	a, (TMDR0H)
		dec	de
		ld	a, d
		or	e
		jr	nz, waitc

return:		pop	hl
		pop	de
		pop	bc
		ret
#endlocal

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; recv_wait - read a data buffer, with max. delay
;;
;; in:		bc	count of bytes to read
;;		de	timeout, in 100Hz units
;;		hl	destination buffer
;; out:		f	zf set on timeout
#local
recv_wait::	ld	(pblock), bc
		ld	(pblock+2), de
		ld	(pblock+4), hl
loop:		call	recv_byte
		ret	z
		ld	(hl), a
		inc	hl
		dec	bc
		ld	a, b
		or	c
		jr	nz, loop
		or	1			; clear zf
		ret
		db	$de, $ad, $be, $ef
pblock:		dw	0, 0, 0
#endlocal

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; flush_rx
;;
;; Flush the RX pipeline
;;
;; in:		none
;; out:		none
#local
flush_rx::	push	af
		push	de
		ld	de, 10		; brief timeout only
loop:		call	recv_byte
		jr	nz, loop
		pop	de
		pop	af
		ret
#endlocal

#include	"src/ymcrc.z80"

#data		DATA
		.org	TEXT_end

fcb		.ds	36

recvbuf		.ds	1026

#end

