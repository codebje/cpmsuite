
		.z180

#target		bin
#code		TEXT, $100

#include	"z180registers.inc"

DM1_ENABLE	equ	01100000b	; set bits DE0, /DWE1
D_MEMF_MEMI_B	equ	00001010b	; DM1=00 SM1=10 MMOD=1
D_MEMF_MEMF_B	equ	00000010b	; DM1=00 SM1=00 MMOD=1

		.org	$100

		xor	a
		out0	(STAT0), a

		ld	hl, startmsg
		call	showmsg

		; use DMA to write fill byte to $20000
		ld	bc, fill_byte
		out0	(SAR0H), b
		out0	(SAR0L), c
		xor	a
		out0	(SAR0B), a
		out0	(DAR0H), a
		out0	(DAR0L), a
		ld	a, 2
		out0	(DAR0B), a
		ld	bc, 1
		out0	(BCR0L), c
		out0	(BCR0H), b
		ld	de, 1*(DM1_ENABLE << 8) | D_MEMF_MEMF_B
		out0	(DMODE), e
		out0	(DSTAT), d
		call	show_dma

		; now SAR can point to the fill byte, and DAR one byte later
		xor	a
		out0	(SAR0H), a
		out0	(SAR0L), a
		out0	(DAR0H), a
		inc	a
		out0	(DAR0L), a
		ld	a, 2
		out0	(SAR0B), a
		out0	(DAR0B), a

		; copy 65,535 bytes each time
		ld	b, 6			; 6 64k banks to write
		xor	a
		ld	de, 1*(DM1_ENABLE << 8) | D_MEMF_MEMF_B

runloop:	out0	(BCR0L), a
		out0	(BCR0H), a

		out0	(DMODE), e
		out0	(DSTAT), d

		; show the status of the DMA system
		call	show_dma

		djnz	runloop

		;ld	bc, 6
		;out0	(BCR0L), c
		;out0	(BCR0H), b
		;out0	(DMODE), e
		;out0	(DSTAT), d

		ld	a, 00100000b
		out0	(DSTAT), a

		jp	0

startmsg:	.text	'Formatting RAM drive A:', 13, 10, 0

show_dma::
		push	af
		push	bc
		push	de
		push	hl

		in0	a, (SAR0B)
		call	bin_to_hex
		call	wait2
		ld	bc, SAR0H
		call	showreg
		ld	bc, SAR0L
		call	showreg

		ld	hl, arrow
		call	showmsg

		in0	a, (DAR0B)
		call	bin_to_hex
		call	wait2
		ld	bc, DAR0H
		call	showreg
		ld	bc, DAR0L
		call	showreg

		ld	hl, listsep
		call	showmsg

		ld	bc, BCR0L
		call	showreg
		ld	bc, BCR0H
		call	showreg

		ld	hl, listsep
		call	showmsg

		ld	bc, DSTAT
		call	showreg

		ld	hl, listsep
		call	showmsg

		ld	bc, DMODE
		call	showreg

		ld	hl, newline
		call	showmsg

		pop	hl
		pop	de
		pop	bc
		pop	af
		ret

arrow:		.text	' -> ', 0
listsep:	.text	', ', 0
newline:	.text	13, 10, 0

#local
showmsg::
		ld	a, (hl)
		or	a
		jr	z, exit
		ld	d, a
		call	wait2
		inc	hl
		jr	showmsg
exit:		ret
#endlocal

showreg::
		in	a, (c)
		call	bin_to_hex
wait1:		in0	a, (STAT0)
		tst	TDRE
		jr	z, wait1
		out0	(TDR0), e
wait2:		in0	a, (STAT0)
		tst	TDRE
		jr	z, wait2
		out0	(TDR0), d
		ret

#include	"bin2hex.inc"

fill_byte:	.db	$e5

#end
