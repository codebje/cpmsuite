		.z180

#target		bin
#code		TEXT, $100
#data		DATA, *

#include	"src/z180registers.z80"
#include	"src/tbios.z80"

#code		TEXT

		.org	$100

		;; FPGA firmware revision
		ld	bc, $0101
		in	a, (c)
		call	bin_to_hex
		ld	(versionbyte), de
		ld	de, versionmsg
		ld	c, CPM_WRITESTR
		call	BDOS

		ld	bc, $0100
		in	a, (c)

		call	bin_to_hex
		ld	(statusbyte), de

		ld	de, statusmsg
		ld	c, 9
		call	5

		ld	a, 0b00001001		; set one LED on and one auto-blinking
		ld	bc, $0100
		out	(c), a

		;; read the manufacturer's ID
		or	a, $10			; turn on the SPI master
		out	(c), a

		ld	c, $04			; switch to SPI data port
		ld	a, $AB			; command: wake from power-down
		out	(c), a
		xor	a
		out	(c), a			; three dummy bytes
		out	(c), a
		out	(c), a

		in	a, (c)			; Manufacturer's ID
		call	bin_to_hex
		ld	(idbyte1), de

		in	a, (c)			; Device ID
		call	bin_to_hex
		ld	(idbyte2), de

		ld	a, $0c			; restore usual blinky lights, turn off SPI
		ld	bc, $100
		out	(c), a

		ld	de, idmsg
		ld	c, 9
		call	5

		ld	a, $1c
		ld	bc, $100
		out	(c), a

		ld	a, $90
		ld	c, $04
		out	(c), a
		xor	a
		out	(c), a
		out	(c), a
		out	(c), a

		in	a, (c)
		call	bin_to_hex
		ld	(idbyte1), de

		in	a, (c)
		call	bin_to_hex
		ld	(idbyte2), de

		ld	a, $0c			; restore usual blinky lights, turn off SPI
		ld	bc, $100
		out	(c), a

		ld	de, idmsg
		ld	c, 9
		call	5

		ld	a, $1c
		ld	bc, $100
		out	(c), a

		ld	c, $04
		ld	a, $0b
		out	(c), a
		xor	a
		out	(c), a
		ld	a, $80
		out	(c), a
		xor	a
		out	(c), a
		out	(c), a

		ld	hl, pagebuffer
		ld	de, 32220
readloop:	in	a, (c)
		ld	(hl), a
		inc	hl
		dec	de
		ld	a, d
		or	e
		jr	nz, readloop

		ld	a, $0c			; restore usual blinky lights, turn off SPI
		ld	bc, $100
		out	(c), a

		ld	de, $800
		ld	hl, pagebuffer
		ld	c, 16
		call	dump_hex

		ld	de, 0
		ld	hl, pagebuffer
		ld	bc, 32220
		call	ym_crc

		push	de
		ld	a, d
		call	bin_to_hex
		ld	(imagecrcbytes), de
		pop	de
		ld	a, e
		call	bin_to_hex
		ld	(imagecrcbytes+2), de
		ld	de, imagecrcmsg
		ld	c, CPM_WRITESTR
		call	BDOS

		;; read status register 1
		ld	d, $05
		call	readreg

		ld	de, spistatusmsg
		ld	c, 9
		call	5

		;; read status register 2
		ld	d, $35
		call	readreg

		ld	hl, spistatusreg
		inc	(hl)
		ld	de, spistatusmsg
		ld	c, 9
		call	5

		;; read status register 3
		ld	d, $15
		call	readreg

		ld	hl, spistatusreg
		inc	(hl)
		ld	de, spistatusmsg
		ld	c, 9
		call	5

		jp	0

readreg:	ld	a, $1c
		ld	bc, $100
		out	(c), a

		ld	a, d
		ld	c, $04
		out	(c), a

		in	a, (c)
		call	bin_to_hex
		ld	(spistatusbyte), de

		ld	a, $0c			; restore usual blinky lights, turn off SPI
		ld	bc, $100
		out	(c), a

		ret

versionmsg:	.text	'FPGA firmware revision '
versionbyte:	.text	'??', 13, 10, '$'

statusmsg:	.text	'FPGA status byte: '
statusbyte:	.text	'??', 13, 10, '$'

idmsg:		.text	'Manufacturer ID: '
idbyte1:	.text	'??', 13, 10, 'Device ID: '
idbyte2:	.text	'??', 13, 10, '$'

spistatusmsg:	.text	'SPI Flash status register '
spistatusreg:	.text	'1: '
spistatusbyte:	.text	'??', 13, 10, '$'

imagecrcmsg:	.text	'Image CRC-16: '
imagecrcbytes:	.text	'????', 13, 10, '$'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; dump_hex - dump a region of memory in canonical hex output format
;;
;; in:		hl	the region of memory to dump
;;		de	the starting address for display,
;;		c	the number of rows of 16 bytes to dump
#local
dump_hex::
		ld	(srcaddr), de

		;; print a row of (up to) 16 bytes
rowloop:	ld	a, (srcaddr)
		call	bin_to_hex
		ld	(linemsg+2), de
		ld	a, (srcaddr+1)
		call	bin_to_hex
		ld	(linemsg), de

		ld	de, (srcaddr)
		inc	de
		ld	(srcaddr), de

		ld	b, 16
		ld	ix, linemsg+8
		ld	iy, linemsg+60

writeloop:	ld	a, (hl)
		inc	hl
		ld	(iy+0), a

		cp	' '			; control characters, replace with a dot
		jr	c, dot
		cp	'$'			; '$' would terminate the print...
		jr	z, dot
		cp	'~'			; high bit set, replace with a dot
		jr	c, hex

dot:		ld	(iy+0), '.'

hex:		inc	iy
		call	bin_to_hex
		ld	(ix+0), e
		ld	(ix+1), d
		inc	ix
		inc	ix
		inc	ix

		ld	a, 9
		cp	b
		jr	nz, loopy
		inc	ix

loopy:		djnz	writeloop

		push	bc
		push	hl
		ld	de, linemsg
		ld	c, 9
		call	5
		pop	hl
		pop	bc

		dec	c
		jr	nz, rowloop
		ret

linemsg:	.text	'????0:  ?? ?? ?? ?? ?? ?? ?? ??  ?? ?? ?? ?? ?? ?? ?? ??    ????????????????', 13, 10, '$'
srcaddr:	.dw	0

#endlocal

#include	"src/bin2hex.z80"
#include	"src/ymcrc.z80"

#data		DATA

		.org	TEXT_end
pagebuffer:	.ds	32220
