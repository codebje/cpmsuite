		.z180

#target		bin
#code		TEXT, $100
#data		DATA, *

#include	"src/z180registers.z80"
#include	"src/tbios.z80"

#code		TEXT

		.org	$100

		ld	a, SPI_CTRL_SDCARD | SPI_CTRL_400KHZ
		out0	(SPI_CTRL), a

		;; Send 80 clock pulses with CS and DI high
		ld	b, 10
pulseloop:	ld	a, $ff
		out0	(SPI_DATA), a
		call	busy
		djnz	pulseloop

		;; Set CS low
		ld	a, SPI_CTRL_SDCARD | SPI_CTRL_400KHZ | SPI_CTRL_ENABLE
		out0	(SPI_CTRL), a

		;; Send CMD0
		ld	hl, cmd0
		call	sendcmd
		call	getr1

		;; Send CMD0
		ld	hl, cmd0
		call	sendcmd
		call	getr1

		ld	hl, cmd8
		call	sendcmd
		call	getr1

		cp	1				; CMD8 should return 1 for v2+ SD cards
		jp	nz, exit

		call	getr7
		; TODO check for supported voltage and correct bit pattern echo

		ld	hl, cmd58			; interrogate OCR
		call	sendcmd
		call	getr1
		tst	%01111110
		jp	nz, exit
		call	getr7				; technically an r3

initcard:
		ld	hl, cmd55
		call	sendcmd
		call	getr1
		tst	%01111110
		jp	nz, exit
		ld	hl, acmd41
		call	sendcmd
		call	getr1
		or	a
		jr	z, initialised
		ld	hl, ctr
		dec	(hl)
		jr	nz, initcard
		jp	exit

initialised:
		ld	a, SPI_CTRL_SDCARD | SPI_CTRL_400KHZ
		out0	(SPI_CTRL), a
		ld	a, SPI_CTRL_SDCARD | SPI_CTRL_25MHZ | SPI_CTRL_ENABLE
		out0	(SPI_CTRL), a

		ld	hl, cmd58			; interrogate OCR
		call	sendcmd
		call	getr1
		tst	%01111111
		jp	nz, exit
		call	getr7				; technically an r3

		;; the OCR read above is incorrect on my SD card, returning all zero.

		;; move on to reading CID
		;ld	hl, cmd10			; read CID
		;call	sendcmd
		;call	getr1
		;tst	%01111111
		;jp	nz, exit

		;ld	hl, csdbytes
		;ld	bc, 16
		;call	getdata

		;ld	hl, csdbytes
		;ld	de, 0
		;ld	c, 1
		;call	dump_hex

		ld	a, SPI_CTRL_SDCARD | SPI_CTRL_25MHZ
		out0	(SPI_CTRL), a
		ld	a, SPI_CTRL_SDCARD | SPI_CTRL_25MHZ | SPI_CTRL_ENABLE
		out0	(SPI_CTRL), a

		ld	hl, cmd58			; interrogate OCR
		call	sendcmd
		call	getr1
		tst	%01111111
		jp	nz, exit
		call	getr7				; technically an r3

		;; now read the first block
		ld	hl, cmd17
		call	sendcmd
		call	getr1
		tst	%01111111
		jp	nz, exit

		ld	hl, block
		ld	bc, 512
		call	getdata

		ld	hl, block
		ld	de, 0
		ld	c, 512/16
		call	dump_hex

exit:
		xor	a
		out0	(SPI_CTRL), a

		rst	0
ctr:		.db	0

;; sendcmd: send a 6-byte command sequence from hl to (SPI_DATA)
#local
sendcmd::	ld	bc, $06 << 8 | SPI_DATA

byteloop:	outi
		call	busy
		or	b
		jr	nz, byteloop

		ret
#endlocal

;; wait for SPI to be done
#local
busy::		in0	a, (SPI_CTRL)
		and	SPI_CTRL_BUSY
		jr	nz, busy
		ret
#endlocal

;; get (and print) an R1 response
#local
getr1::		ld	b, 9

readloop:	ld	a, $ff
		out0	(SPI_DATA), a
		call	busy
		in0	a, (SPI_DATA)
		tst	$80
		jr	z, success

		djnz	readloop

		ld	de, r1fail
		ld	c, CPM_WRITESTR
		call	BDOS
		ld	a, $ff
		ret

success:
		push	af
		;; print the R1 response
		call	bin_to_hex
		ld	(r1data), de
		ld	de, r1msg
		ld	c, CPM_WRITESTR
		call	BDOS
		pop	af

		ret
#endlocal

;; get (and print) an R7 response, assuming the R1 response has been received already
#local
getr7::
		ld	hl, r7bytes
		ld	bc, $04 << 8 | SPI_DATA
		ld	d, $ff
readloop:	out0	(SPI_DATA), d
		call	busy
		ini
		jr	nz, readloop

		ld	a, (r7bytes)
		call	bin_to_hex
		ld	(r7data), de
		ld	a, (r7bytes+1)
		call	bin_to_hex
		ld	(r7data+3), de
		ld	a, (r7bytes+2)
		call	bin_to_hex
		ld	(r7data+6), de
		ld	a, (r7bytes+3)
		call	bin_to_hex
		ld	(r7data+9), de

		ld	de, r7msg
		ld	c, CPM_WRITESTR
		call	BDOS

		ret
#endlocal

;; getdata - read a data block
;; hl - where to write
;; bc - the number of bytes to read
#local
getdata::
		push	bc

		ld	b, 0
tokenloop:	ld	a, $ff
		out0	(SPI_DATA), a
		call	busy
		in0	a, (SPI_DATA)
		cp	$ff
		jr	nz, responded
		djnz	tokenloop

		pop	bc
		ld	de, datatimeout
		ld	c, CPM_WRITESTR
		call	BDOS
		ret

responded:	
		;; print what's what
		push	af
		push	hl
		call	bin_to_hex
		ld	(tokenbyte), de
		ld	de, datatoken
		ld	c, CPM_WRITESTR
		call	BDOS
		pop	hl
		pop	af
		pop	bc

		cp	$fe
		ret	nz

bytes:		ld	a, $ff
		out0	(SPI_DATA), a
		call	busy
		in0	a, (SPI_DATA)
		ld	(hl), a
		inc	hl

		dec	bc
		ld	a, b
		or	c
		jr	nz, bytes

		;; skip two CRC bytes
		ld	a, $ff
		out0	(SPI_DATA), a
		call	busy
		out0	(SPI_DATA), a
		call	busy

		ret

#endlocal

#include	"src/bin2hex.z80"
#include	"src/dump_hex.z80"

cmd0:		.db	$40, $00, $00, $00, $00, $95		; puts the card into SPI mode
cmd8:		.db	$48, $00, $00, $01, $aa, $87		; sets voltage to 01 = 2.7v-3.6v
cmd9:		.db	$49, $00, $00, $00, $00, $01		; read CSD
cmd10:		.db	$4a, $00, $00, $00, $00, $01		; read CID
cmd13:		.db	$4d, $00, $00, $00, $00, $01		; read status
cmd17:		.db	$51, $00, $00, $00, $00, $01		; read block
cmd55:		.db	$77, $00, $00, $00, $00, $01		; application command follows
cmd58:		.db	$7a, $00, $00, $00, $00, $01		; read OCR

acmd41:		.db	$69, $40, $00, $00, $00, $01		; initialise card

r1msg:		.db	'R1 response byte: '
r1data:		.db	'??', 13, 10, '$'
r1fail:		.db	'No R1 response received', 13, 10, '$'

r7bytes:	.db	0, 0, 0, 0

r7msg:		.db	'R7 response bytes: '
r7data:		.db	'?? ?? ?? ??', 13, 10, '$'

statusmsg:	.db	'Card status: '
statusdata:	.db	'??', 13, 10, '$'

datatimeout:	.db	'Timeout waiting for data response', 13, 10, '$'
datatoken:	.db	'Data token byte: '
tokenbyte:	.db	'??', 13, 10, '$'

csdbytes	.ds	16

block:		.ds	512
