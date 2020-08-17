		.z180

#target		bin
#code		TEXT, $100
#data		DATA, *

#include	"z180registers.inc"
#include	"tbios.z80"

#code		TEXT

		org	$100

		ld	sp, $d000

		ld	de, starting
		ld	c, CPM_WRITESTR
		call	5

		ld	de, $5555
		ld	a, $90
		call	sst_command

		; read ID bytes
		xor	a
		out0	(SAR0L), a
		out0	(SAR0H), a
		out0	(SAR0B), h
		ld	bc, idbytes
		out0	(DAR0L), c
		out0	(DAR0H), b
		out0	(DAR0B), l
		ld	a, 2
		out0	(BCR0L), a
		out0	(DSTAT), d

		ld	de, $5555
		ld	a, $f0
		call	sst_command

		ld	a, (idbytes)
		call	bin_to_hex
		ld	(idvalue), de
		ld	a, (idbytes+1)
		call	bin_to_hex
		ld	(idvalue+2), de

		ld	de, idmessage
		ld	c, CPM_WRITESTR
		call	5

		or	a			; clear carry
		ld	de, (idbytes)
		ld	hl, $d6bf		; BF = SST manuf. ID, D6 = SST39LF020
		sbc	hl, de
		jr	nz, badrom

		; open the default fcb
		ld	de, CPM_FCB
		ld	c, CPM_FOPEN
		call	5
		inc	a
		jr	z, badfile

loadloop:
		;; read up to 4096 bytes
		call	load_bytes
		jr	z, close		; if there was nothing to read, do no work
		;; erase sector
		call	erase_sector
		;; write sector
		call	burn_bytes

		ld	hl, (sector)
		ld	de, $1000
		add	hl, de
		ld	(sector), hl

		jr	loadloop

close:		ld	de, CPM_FCB
		ld	c, CPM_FCLOSE
		call	5

		or	a
		ld	hl, (sector)
		ld	de, $2000
		sbc	hl, de

		ld	a, h
		call	bin_to_hex
		ld	(erasedmsg), de
		ld	a, l
		call	bin_to_hex
		ld	(erasedmsg+2), de

		ld	de, donemsg
		ld	c, CPM_WRITESTR
		call	5

		rst	0

badrom:		ld	de, badrommsg
		ld	c, CPM_WRITESTR
		call	5
		rst	0

badfile:	ld	de, badfilemsg
		ld	c, CPM_WRITESTR
		call	5
		rst	0

starting:	defm	'SST39F0x0 ROM tool',13,10,'$'
idbytes:	dw	0
idmessage:	defm	'ID data: '
idvalue:	defm	'????', 13, 10, '$'
badrommsg:	defm	'Invalid ROM identifier',13,10,'$'
badfilemsg:	defm	'Cannot load ROM disk image - file invalid',13,10,'$'
gotsome:	defm	'File was not empty',13,10,'$'
donemsg:	defm	'Programming complete. '
erasedmsg:	defm	'???? bytes erased and programmed.',13,10,'$'

sector:		dw	$2000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; load_bytes - read up to 4096 bytes into readbuf
;;
;; out:		f	zf set when no bytes could be read
#local
load_bytes::
		;; reset readbuf to all $ff
		ld	a, $ff
		ld	(readbuf), a
		ld	hl, readbuf
		ld	de, readbuf+1
		ld	bc, 4095
		ldir

		;; read up to 32 sectors
		ld	b, 32

		ld	de, readbuf
		ld	(readaddr), de

readloop:	push	bc

		ld	de, (readaddr)
		ld	c, CPM_DMAOFF
		call	5

		;; read next sector
		ld	de, CPM_FCB
		ld	c, CPM_FREAD
		call	5
		or	a
		jr	nz, readerr

		ld	hl, (readaddr)
		ld	bc, 128
		add	hl, bc
		ld	(readaddr), hl

		pop	bc
		djnz	readloop

		or	1			; reset zf
		ret

readerr:	
		pop	bc
		ld	a, b
		cp	32			; zf set if first sector was EOF
		ret

readaddr	dw	readbuf

#endlocal

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sst_command - execute an SST ROM command
;;
;; Set DE to $5555 for issuing commands, and to the sector address for
;; a sector erase operation.
;;
;; in:		a	the command byte to send
;;		de	the memory address for the third command
#local
sst_command::
		ld	(command+2), a
		ld	(finaladdr), de

		xor	a
		out0	(BCR0H), a
		ld	de, 0110000000000010b
		out0	(DMODE), e

		ld	a, 1
		ld	hl, $0800

		ld	bc, command
		out0	(SAR0L), c
		out0	(SAR0H), b
		out0	(SAR0B), l
		out0	(DAR0B), h

		ld	bc, $5555
		out0	(DAR0L), c
		out0	(DAR0H), b
		out0	(BCR0L), a
		out0	(DSTAT), d

		; write byte 2
		ld	bc, $2aaa
		out0	(DAR0L), c
		out0	(DAR0H), b
		out0	(BCR0L), a
		out0	(DSTAT), d

		; write byte 3
		ld	bc, $5555
finaladdr:	equ	$ - 2
		out0	(DAR0L), c
		out0	(DAR0H), b
		out0	(BCR0L), a
		out0	(DSTAT), d
		ret

command:	db	$aa, $55, $00

#endlocal

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; wait_op - wait for a programming operation to complete
;;
;; in:		a	the expected byte value
;;		de	the byte value's address
#local
wait_op::
		;; set up DMA to read from ROM and write to RAM
		ld	hl, $0800
		out0	(SAR0B), h
		out0	(DAR0B), l

						; DE = SAR0L, SAR0H
		ld	hl, rombyte		; HL = DAR0L, DAR0H
		ld	b, a			; B = compare target

		xor	a
		out0	(BCR0H), a

		ld	c, 00000010b
		out0	(DMODE), c
		ld	c, 01100000b		; C = DSTAT enable DMA0

waitloop:
		ld	a, 1
		out0	(BCR0L), a
		out0	(SAR0L), e
		out0	(SAR0H), d
		out0	(DAR0L), l
		out0	(DAR0H), h
		out0	(DSTAT), c

		;; bit 7 will be inverted until the op is done
		ld	a, (hl)
		xor	b
		tst	$80
		jr	nz, waitloop
		;; if trying to write 0xff
		;; will read 0x00/0x40/0x00/...
		;; xor 0xff with 0x00 = 0xff

		ret

rombyte:	db	0
#endlocal

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; erase_sector - erase the next ROM sector
;;
#local
erase_sector::

		ld	a, (sector)
		call	bin_to_hex
		ld	(eraseaddr+2), de
		ld	a, (sector+1)
		call	bin_to_hex
		ld	(eraseaddr), de
		ld	de, erasemsg
		ld	c, CPM_WRITESTR
		call	5

		ld	a, $80
		ld	de, $5555
		call	sst_command
		ld	a, $30
		ld	de, (sector)
		call	sst_command

		ld	a, $ff
		ld	de, (sector)
		call	wait_op

		ret

erasemsg:	defm	'Erasing sector at 08'
eraseaddr:	defm	'????',13,10,'$'

#endlocal

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; burn_bytes - burn bytes to ROM
;;
#local
burn_bytes::
		ld	bc, 16

		ld	de, readbuf
		ld	(src), de
		ld	de, (sector)
		ld	(dst), de

program:	
		push	bc

		;; enable byte programming
		ld	a, $a0
		ld	de, $5555
		call	sst_command

		;; sst_command leaves SAR0B, DAR0B, BCR0H, DMODE correct
		;; and leaves D set up to program DSTAT for burst mode

		;; write the byte
		ld	bc, (src)
		out0	(SAR0L), c
		out0	(SAR0H), b
		inc	bc
		ld	(src), bc

		ld	bc, (dst)
		out0	(DAR0L), c
		out0	(DAR0H), b
		inc	bc
		ld	(dst), bc

		ld	a, 1
		out0	(BCR0L), a
		out0	(DSTAT), d

		ld	hl, (src)
		dec	hl
		ld	a, (hl)
		ld	de, (dst)
		dec	de
		call	wait_op

		pop	bc
		djnz	program
		dec	c
		jr	nz, program

		ret

src		dw	0
dst		dw	0

#endlocal

#include	"bin2hex.inc"

#data		DATA
		.org	TEXT_end
readbuf:	ds	4096
