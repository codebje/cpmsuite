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

		;; get the 0-3 boot select value into bits 4 & 5
		sub	'1'
		rlca
		rlca
		rlca
		rlca

		;; set the warm boot flag
		or	$40

		; read version
		in0	d, (FPGA_VERSION)

		; reboot
		out0	(FPGA_CTRL), a

		ld	a, d
		call	bin_to_hex
		ld	(versionbyte), de
		ld	de, versionmsg
		ld	c, CPM_WRITESTR
		call	BDOS

		ld	de, booted
		ld	c, CPM_WRITESTR
		call	BDOS

		in0	a, (FPGA_VERSION)
		call	bin_to_hex
		ld	(versionbyte), de
		ld	de, versionmsg
		jr	bail

bad_args:	ld	de, usage
bail:		ld	c, CPM_WRITESTR
		call	BDOS
		rst	0

usage:		.text	'usage: fpgaboot <1-4>', 13, 10, '$'

booted:		.text	'FPGA rebooted.', 13, 10, '$'

versionmsg:	.text	'FPGA version: '
versionbyte:	.text	'??', 13, 10, '$'

#include	"src/bin2hex.z80"
