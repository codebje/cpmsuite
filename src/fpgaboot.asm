		.z180

#target		bin
#code		TEXT, $100
#data		DATA, *

#include	"src/z180registers.z80"
#include	"src/tbios.z80"

#code		TEXT

		.org	$100

		;; scan command line for 1-4
		ld	hl, $81
spaces:		ld	a, (hl)
		inc	hl
		or	a
		jr	z, bad_args
		cp	a, ' '
		jr	z, spaces
		cp	a, '1'
		jr	c, bad_args
		cp	a, '4'+1
		jr	nc, bad_args

		;; get the 0-3 boot select value into bits 5 & 6
		sub	'1'
		rrca
		rrca
		rrca

		;; set the warm boot flag
		or	$80

		ld	bc, $100
		in	d, (c)
		or	d

		push	af
		ld	a, d
		call	bin_to_hex
		ld	(statusbyte), de
		ld	de, statusmsg
		ld	c, CPM_WRITESTR
		call	BDOS
		pop	af

		ld	bc, $100
		out	(c), a

		call	bin_to_hex
		ld	(statusbyte), de
		ld	de, statusmsg
		jr	bail

bad_args:	ld	de, usage
bail:		ld	c, CPM_WRITESTR
		call	BDOS
		rst	0

usage:		.text	'usage: fpgaboot <1-4>', 13, 10, '$'

statusmsg:	.text	'FPGA status byte: '
statusbyte:	.text	'??', 13, 10, '$'

#include	"src/bin2hex.z80"
