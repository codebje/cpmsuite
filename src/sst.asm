		.z180

#target		bin
#code		TEXT, $100
#data		DATA, *

#include	"z180registers.inc"
#include	"tbios.z80"

#code		TEXT

		org	$100

		ld	de, starting
		ld	c, CPM_WRITESTR
		call	5

		; from first 64k of RAM to first 64k of ROM
		ld	hl, $0800
		out0	(SAR0B) ,l
		out0	(DAR0B), h

		ld	bc, idmode
		out0	(SAR0L), c
		out0	(SAR0H), b

		ld	bc, $5555
		out0	(DAR0L), c
		out0	(DAR0H), b

		xor	a
		out0	(BCR0H), a
		ld	a, 1
		out0	(BCR0L), a

		; write byte 1
		ld	de, 0110000000000010b
		out0	(DMODE), e
		out0	(DSTAT), d

		; write byte 2
		ld	bc, $2aaa
		out0	(DAR0L), c
		out0	(DAR0H), b
		out0	(BCR0L), a
		out0	(DSTAT), d

		; write byte 3
		ld	bc, $5555
		out0	(DAR0L), c
		out0	(DAR0H), b
		out0	(BCR0L), a
		out0	(DSTAT), d

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

		; exit ID mode
		ld	bc, idexit
		out0	(SAR0L), c
		out0	(SAR0H), b
		out0	(SAR0B), l
		out0	(DAR0B), h
		ld	a, 1

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
		out0	(DAR0L), c
		out0	(DAR0H), b
		out0	(BCR0L), a
		out0	(DSTAT), d

		ld	a, (idbytes)
		call	bin_to_hex
		ld	(idvalue), de
		ld	a, (idbytes+1)
		call	bin_to_hex
		ld	(idvalue+2), de

		ld	de, idmessage
		ld	c, CPM_WRITESTR
		call	5
		rst	0

starting:	defm	'SST39F0x0 ROM tool',13,10,'$'
idmode:		db	$aa, $55, $90
idexit:		db	$aa, $55, $f0
idbytes:	dw	0
idmessage:	defm	'ID data: '
idvalue:	defm	'????', 13, 10, '$'

#include	"bin2hex.inc"

#data		DATA
