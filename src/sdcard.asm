		.z180

#target		bin
#code		TEXT, $100
#data		DATA, *

#include	"src/z180registers.z80"
#include	"src/tbios.z80"

SPI_SPEED:	equ	SPI_CTRL_6MHZ
SPI_PAUSE:	equ	SPI_CTRL_SDCARD | SPI_SPEED
SPI_RESUME:	equ	SPI_CTRL_SDCARD | SPI_SPEED | SPI_CTRL_ENABLE

#code		TEXT

		.org	$100

		ld	a, SPI_CTRL_SDCARD | SPI_CTRL_400KHZ
		out0	(SPI_CTRL), a
		ld	a, 2
		out0	(FPGA_CTRL), a

		;; Send 80 clock pulses with CS and DI high
		ld	b, 10
pulseloop:	ld	a, $ff
		out0	(SPI_DATA), a
		call	busy
		djnz	pulseloop

		;; Attempt to put the SD card into SPI mode
		ld	de, spimodemsg
		ld	c, CPM_WRITESTR
		call	BDOS

		ld	b, 1
spimodeloop:	push	bc
		ld	hl, cmd0
		ld	b, 0
		call	sdcommand
		pop	bc
		tst	%11111110
		jp	z, spimodeon
		djnz	spimodeloop
		jp	r1errexit

r1val:		.db	'?? $'
spimodeon:	
		call	bin_to_hex
		ld	(r1val), de
		ld	de, r1val
		ld	c, CPM_WRITESTR
		call	BDOS

		;; try to set the voltage
		ld	de, voltagemsg
		ld	c, CPM_WRITESTR
		call	BDOS

		ld	hl, cmd8
		ld	b, 1
		call	sdcommand
		tst	%11111110
		jp	nz, r1errexit

		;ld	h, a
		;ld	a, $aa
		;cp	e
		;jr	nz, setvoltage

		;; TODO test de = $01AA

		push	hl
		ld	a, b
		ld	(r7bytes), a
		ld	a, c
		ld	(r7bytes+1), a
		ld	a, d
		ld	(r7bytes+2), a
		ld	a, e
		ld	(r7bytes+3), a
		call	printr7
		pop	hl

		ld	a, h
		call	bin_to_hex
		ld	(r1val), de
		ld	de, r1val
		ld	c, CPM_WRITESTR
		call	BDOS

		ld	de, ocrmsg
		ld	c, CPM_WRITESTR
		call	BDOS

setvoltage:
		ld	hl, cmd58
		ld	b, 1
		call	sdcommand
		tst	%11111110
		jp	nz, r1errexit

		push	af
		ld	a, b
		ld	(r7bytes), a
		ld	a, c
		ld	(r7bytes+1), a
		ld	a, d
		ld	(r7bytes+2), a
		ld	a, e
		ld	(r7bytes+3), a
		call	printr7
		pop	af

		call	bin_to_hex
		ld	(r1val), de
		ld	de, r1val
		ld	c, CPM_WRITESTR
		call	BDOS

		ld	de, initmsg
		ld	c, CPM_WRITESTR
		call	BDOS

		;; repeatedly send the init. card message until the card is no longer idle

		;; play with LEDs
		ld	a, 0
		out0	(FPGA_CTRL), a

		ld	de, 0
		ld	(ctr), de
initcard:
		ld	a, 3
		out0	(FPGA_CTRL), a
		ld	hl, cmd55
		ld	b, 0
		call	sdcommand
		tst	%01111110
		jp	nz, r1errexit
		ld	a, 2
		out0	(FPGA_CTRL), a
		ld	hl, acmd41
		ld	b, 0
		call	sdcommand
		tst	%01111110
		jp	nz, r1errexit
		tst	%00000001
		jr	z, initialised
		ld	hl, (ctr)
		dec	hl
		ld	(ctr), hl
		ld	a, h
		or	l
		jr	nz, initcard
		ld	de, broken
		ld	c, CPM_WRITESTR
		call	BDOS

		ld	a, $ff
		jp	r1errexit
broken:		.db	'got nothing $'

initialised:
		ld	de, okmsg
		ld	c, CPM_WRITESTR
		call	BDOS
		jp	exit

		ld	a, SPI_PAUSE
		out0	(SPI_CTRL), a
		ld	a, SPI_RESUME
		out0	(SPI_CTRL), a

		ld	hl, cmd58			; interrogate OCR
		call	sendcmd
		call	getr1
		tst	%01111111
		jp	nz, exit
		call	getr7				; technically an r3

		;; Read the CSD
		ld	hl, cmd9			; read CSD
		call	sendcmd
		call	getr1
		tst	%01111111
		jp	nz, exit

		ld	hl, csdbytes
		ld	bc, 16
		call	getdata

		ld	a, SPI_PAUSE
		out0	(SPI_CTRL), a

		ld	hl, csdbytes
		ld	de, 0
		ld	c, 1
		call	dump_hex

		ld	a, SPI_RESUME
		out0	(SPI_CTRL), a

		ld	hl, cmd13
		call	sendcmd
		call	getr1
		ld	a, $ff
		out0	(SPI_DATA), a

		;; now read the first block
		ld	hl, cmd17
		call	sendcmd
		call	getr1
		tst	%01111111
		jp	nz, exit

		ld	hl, block
		ld	bc, 512
		call	getdata

		ld	a, SPI_PAUSE
		out0	(SPI_CTRL), a

		ld	hl, block
		ld	de, 0
		ld	c, 512/16
		;call	dump_hex

		ld	a, SPI_RESUME
		out0	(SPI_CTRL), a

		ld	hl, cmd13
		call	sendcmd
		call	getr1
		ld	a, $ff
		out0	(SPI_DATA), a

		;; now read the first block
		ld	hl, cmd17
		call	sendcmd
		call	getr1
		tst	%01111111
		jp	nz, exit

		ld	hl, block
		ld	bc, 512
		call	getdata

		ld	a, SPI_PAUSE
		out0	(SPI_CTRL), a

		;ld	hl, block
		;ld	de, 0
		;ld	c, 512/16
		;call	dump_hex

		;; show the drive size, using the CSD
		call	show_size
		jp	exit

#local
r1byte:		.db	0
r1errexit::
		ld	(r1byte), a
		tst	%10000000		; timeout error
		jr	z, paramtest
		ld	de, timeoutmsg
		ld	c, CPM_WRITESTR
		call	BDOS
		jr	exit

paramtest:	ld	a, (r1byte)
		tst	%01000000		; parameter error
		jr	z, addrtest
		ld	de, paramerrmsg
		ld	c, CPM_WRITESTR
		call	BDOS

addrtest:	ld	a, (r1byte)
		tst	%00100000		; address error
		jr	z, seqtest
		ld	de, addrerrmsg
		ld	c, CPM_WRITESTR
		call	BDOS

seqtest:	ld	a, (r1byte)
		tst	%00010000		; erase sequence error
		jr	z, crctest
		ld	de, eseqerrmsg
		ld	c, CPM_WRITESTR
		call	BDOS

crctest:	ld	a, (r1byte)
		tst	%00001000		; crc error
		jr	z, cmdtest
		ld	de, crcerrmsg
		ld	c, CPM_WRITESTR
		call	BDOS

cmdtest:	ld	a, (r1byte)
		tst	%00000100		; illegal command
		jr	z, erasetest
		ld	de, illegalerrmsg
		ld	c, CPM_WRITESTR
		call	BDOS

erasetest:	ld	a, (r1byte)
		tst	%00000010		; erase reset
		jr	z, idletest
		ld	de, eraseerrmsg
		ld	c, CPM_WRITESTR
		call	BDOS

idletest:	ld	a, (r1byte)
		tst	%00000010		; erase reset
		jr	z, r1done
		ld	de, idleerrmsg
		ld	c, CPM_WRITESTR
		call	BDOS

r1done:

#endlocal

errexit:	ld	de, failmsg
		ld	c, CPM_WRITESTR
		call	BDOS

exit:
		xor	a
		out0	(SPI_CTRL), a

		rst	0
ctr:		.dw	0

#local
show_size::
		ld	ix, csdbytes

		ld	a, (ix+0)		; check command structure version
		and	%11000000		; only want bits 7 and 6
		jr	z, csd_version_1	; version 1 = 00
		cp	%01000000		; version 2 = 01
		jr	z, csd_version_2

		ld	de, csd_bad_msg
		ld	c, CPM_WRITESTR
		call	BDOS
		ret

csd_version_1:	;; version 1 CSD structure
		;; C_SIZE is 12 bits at 73:62
		;; C_SIZE_MULT is 3 bits at 49:47
		;; READ_BL_LEN is 4 bits at 83:80
		;; Card size is (C_SIZE+1) * 2^(C_SIZE_MULT+2) * 2^READ_BL_LEN

		ld	de, csd_nov1_msg
		ld	c, CPM_WRITESTR
		call	BDOS
		ret

csd_version_2:	;; version 2 CSD structure
		;; C_SIZE is 22 bits at 69:48, bytes 7, 8, and 9
		;; Card size is (C_SIZE+1) * 512K, minimum size is 2GB, maximum size is 2TB

		;; Load C_SIZE+1 into A, H, L
		ld	a, (ix+7)
		and	a, $3f				; C_SIZE is only 22 bits
		ld	e, a
		ld	a, (ix+9)
		add	a, 1
		ld	l, a
		ld	a, (ix+8)
		adc	a, 0
		ld	h, a
		ld	a, e				; (ix+7) & $3f
		adc	a, 0				; This will not have carry

		;; Divide it all by 2
		rra
		rr	h
		rr	l

		;; Convert to decimal text - 0x200000 is at most 7 decimal digits
		ld	e, a
		ld	ix, csd_available+6
		call	bin_to_dec

		push	ix
		pop	de
		ld	c, CPM_WRITESTR
		call	BDOS

		ret
#endlocal

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; bin_to_dec - convert a 24-bit binary value to decimal digits
;;
;; in:		e	bits 23:16
;;		hl	bits 15:0
;;		ix	last character position to write to
;; out:		ix	left-most character written
#local
bin_to_dec::
		;; divide by ten and store the remainder
		call	div10
		add	a, '0'
		ld	(ix), a

		;; if ehl is zero the gig is up and be done
		ld	a, e
		or	a, h
		jr	nz, cont
		or	a, l
		jr	z, done

cont:		dec	ix
		jr	bin_to_dec

done:		ret

#endlocal

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; div10 - divide EHL by ten
;;
;; http://z80-heaven.wikidot.com/math#toc22
;;
;; An 8-bit number can be represented as 10 times powers of two, plus a remainder.
;; eg, 218 is 10*2^4 + 10*2^2 + 10*2^0 + 8; strip out the 10* components and the
;; remainder and you get 2^4 + 2^2 + 2^0 = %00010101 = 21.
;;
;; The algorithm here shifts the number to be divided to the left, until the value
;; shifted is greater than or equal to ten. Bit 0 of the dividend is set and the
;; shifted value has ten subtracted from it; as the remaining bits of the original
;; dividend are shifted the set bit will wind up in the correct position in what
;; will have become the quotient, with any remaining shifted bits being the remainder.
;;
;; The algorithm can be chained with multiple inputs: the remainder of the higher
;; set of bits is used as the shifted off bits of the lower set of bits. In this
;; routine, the 8 bits in E are divided first, then the 16 bits in HL.
;;
;; in:		ehl	24-bit dividend
;; out:		ehl	24-bit quotient
;;		a	remainder
;;		bc	10
#local
div10::		xor	a
		sla	e
		rla
		sla	e
		rla
		sla	e
		rla

		ld	bc, $050a
first:		sla	e
		rla
		cp	c
		jr	c, nosub1
		sub	c
		inc	e
nosub1:		djnz	first

		ld	b, 16
second:		add	hl, hl
		rla
		cp	c
		jr	c, nosub2
		sub	c
		inc	l
nosub2:		djnz	second

		ret
#endlocal

#include	"src/bin2hex.z80"
#include	"src/dump_hex.z80"
#include	"src/sdlib.z80"

;; Messages indicating progress through setting up the card
spimodemsg:	.db			'Enabling SPI mode...       $'
voltagemsg:	.db	'OK', 13, 10,	'Setting voltage to 3.3v... $'
ocrmsg:		.db	'OK', 13, 10,	'Reading OCR...             $'
initmsg:	.db	'OK', 13, 10,	'Initialising card...       $'

okmsg:		.db	'OK', 13, 10, '$'
failmsg:	.db	'FAIL', 13, 10, '$'
paramerrmsg:	.db	'PARAM $'
addrerrmsg:	.db	'ADDR $'
eseqerrmsg:	.db	'SEQ $'
crcerrmsg:	.db	'CRC $'
illegalerrmsg:	.db	'CMD $'
eraseerrmsg:	.db	'ERASE $'
idleerrmsg:	.db	'IDLE $'
timeoutmsg:	.db	'TIMEOUT', 13, 10, '$'

statusmsg:	.db	'Card status: '
statusdata:	.db	'??', 13, 10, '$'

datatimeout:	.db	'Timeout waiting for data response', 13, 10, '$'
datatoken:	.db	'Data token byte: '
tokenbyte:	.db	'??', 13, 10, '$'

csd_bad_msg:	.db	'Invalid CSD structure version, card unknown', 13, 10, '$'
csd_nov1_msg:	.db	'CSD version 1.0 unsupported', 13, 10, '$'
csd_available:	.db	'???????K available user storage', 13, 10, '$'

csdbytes	.ds	16

block:		.ds	512
