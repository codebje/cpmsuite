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

		ld	hl, cmd55
		ld	b, 0
		call	sdcommand
		tst	%01111110
		ld	de, cmd55msg
		jp	nz, exit
		ld	a, 2
		out0	(FPGA_CTRL), a
		ld	hl, acmd41
		ld	b, 0
		call	sdcommand
		tst	%01111110
		ld	de, acmd41msg
		jp	nz, exit
		tst	%00000001
		ld	de, idlemsg
		jr	nz, exit

		ld	hl, cmd58
		ld	b, 1
		call	sdcommand

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

		;; now read the first block
		ld	hl, cmd17
		call	sendcmd
		call	getr1
		tst	%01111111
		ld	de, cmd17msg
		jp	nz, exit

		ld	hl, block
		ld	bc, 512
		call	getdata

		ld	hl, block + 0x1be
		ld	de, 0
		ld	c, 4
		call	dump_hex
		rst	0

exit:
		push	de
		call	bin_to_hex
		pop	hl
		ld	(hl), e
		inc	hl
		ld	(hl), d
		dec	hl
		ld	de, hl
		ld	c, CPM_WRITESTR
		call	BDOS

		rst	0

cmd55msg:	.db	'?? cmd55', 13, 10, '$'
acmd41msg:	.db	'?? acmd41', 13, 10, '$'
idlemsg:	.db	'?? idle', 13, 10, '$'
cmd17msg:	.db	'?? cmd17', 13, 10, '$'

#include	"src/bin2hex.z80"
#include	"src/dump_hex.z80"
#include	"src/sdlib.z80"

csd_bad_msg:	.db	'Invalid CSD structure version, card unknown', 13, 10, '$'
csd_nov1_msg:	.db	'CSD version 1.0 unsupported', 13, 10, '$'
csd_available:	.db	'???????K available user storage', 13, 10, '$'

r1val:		.db	'??', 13, 10, '$'
block:		.ds	512
