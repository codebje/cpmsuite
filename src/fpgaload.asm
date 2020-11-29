		.z180

#target		bin
#code		TEXT, $100
#data		DATA, *

#include	"src/z180registers.z80"
#include	"src/tbios.z80"

SPI_BEGIN	equ	SPI_CTRL_ENABLE | SPI_CTRL_FLASHROM | SPI_CTRL_50MHZ

#code		TEXT

		org	$100

		; check the default FCB for a second argument
		; ($6d) should contain '1'-'4' or ' '
		ld	a, (CPM_FCB_2+1)
		cp	a, ' '
		jr	z, open				; if it's a space there's no 2nd argument

		sub	a, '1'
		jp	c, badargs
		cp	a, 4
		jp	nc, badargs

		ld	h, a
		ld	l, $80
		mlt	hl
		ld	a, h
		ld	h, l
		ld	l, a
		ld	(writeaddr), hl

open:
		; open the default fcb
		ld	de, CPM_FCB
		ld	c, CPM_FOPEN
		call	5
		inc	a
		jp	z, badfile

		; erase sector
		call	write_enable

		ld	a, SPI_BEGIN
		out0	(SPI_CTRL), a

		ld	hl, writecmd
		ld	bc, $04 << 8 | SPI_DATA
		otir

		xor	a
		out0	(SPI_CTRL), a

		;; Update the write command to Page Program for the write loop
		ld	a, $02
		ld	(writecmd), a

		call	wait_busy

		ld	de, erased
		ld	c, CPM_WRITESTR
		call	BDOS

		;; do some delay-type stuff
		ld	d, $05
		call	readreg

		ld	de, spistatusmsg
		ld	c, 9
		call	5

		ld	b, 0
busyloop:	djnz	busyloop

loadloop:	call	load_page			; read in 256 bytes
		jr	z, written

		call	write_page			; write it to SPI

		ld	hl, writeaddr+1
		inc	(hl)
		ld	hl, loadcount
		dec	(hl)
		jr	nz, loadloop

		ld	de, oversizemsg
		jr	exit

loadcount:	.db	129

written:	ld	de, completemsg
		jr	exit

badargs:	ld	de, badargsmsg
		jr	exit

badfile:	ld	de, badfilemsg
exit:		ld	c, CPM_WRITESTR
		call	BDOS
		rst	0

write_enable:	ld	a, SPI_BEGIN			; begin SPI
		out0	(SPI_CTRL), a

		ld	a, $06				; cmd 06: Write Enable
		out0	(SPI_DATA), a

		xor	a				; end SPI
		out0	(SPI_CTRL), a

		ret

readreg:	ld	a, SPI_BEGIN
		out0	(SPI_CTRL), a

		out0	(SPI_DATA), d

		ld	a, $ff
		out0	(SPI_DATA), a
		in0	a, (SPI_DATA)

		call	bin_to_hex
		ld	(spistatusbyte), de

		xor	a
		out0	(SPI_CTRL), a

		ret


;; wait until busy bit is clear
wait_busy:	ld	a, SPI_BEGIN | SPI_CTRL_BULKREAD
		out0	(SPI_CTRL), a

		ld	a, $05
		out0	(SPI_DATA), a
		in0	a, (SPI_DATA)

wait_loop:	in0	a, (SPI_DATA)
		tst	$01
		jr	nz, wait_loop

		xor	a
		out0	(SPI_CTRL), a

		ret

;; load page
#local
load_page::	;; clear the page buffer to $ff
		ld	a, $ff
		ld	(pagebuffer), a
		ld	hl, pagebuffer
		ld	de, pagebuffer+1
		ld	bc, $ff
		ldir

		;; Set up DMA reads to the start of the page buffer
		ld	de, pagebuffer
		ld	c, CPM_DMAOFF
		call	BDOS

		;; Read first sector
		ld	de, CPM_FCB
		ld	c, CPM_FREAD
		call	BDOS
		or	a
		jr	nz, nodata

		;; Next read into second half of page buffer
		ld	de, pagebuffer+128
		ld	c, CPM_DMAOFF
		call	BDOS

		;; it's okay if this one doesn't get any data
		ld	de, CPM_FCB
		ld	c, CPM_FREAD
		call	BDOS

		or	1				; clear zf
		ret

nodata:		xor	a				; set zf
		ret

#endlocal

;; write a page to SPI flash
#local
write_page::	call	write_enable

		ld	a, SPI_BEGIN
		out0	(SPI_CTRL), a

		ld	hl, writecmd
		ld	bc, $04 << 8 | SPI_DATA
		otir

		;; write 256 bytes of data
		ld	hl, pagebuffer
		ld	bc, SPI_DATA
		otir

		xor	a
		out0	(SPI_CTRL), a

		call	wait_busy

		ret
#endlocal

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

writecmd:	.db	$52			; initial command: erase 32kb sector
writeaddr:	.db	$00, $80, $00

badfilemsg:	.text	'File invalid, cannot open',13,10,'$'
badargsmsg:	.text	'Second argument should be an image number or nothing',13,10,'$'
completemsg:	.text	'File successfully written',13,10,'$'
oversizemsg:	.text	'File larger than 32K: truncated',13,10,'$'
spistatusmsg:	.text	'SPI Flash status register '
spistatusreg:	.text	'1: '
spistatusbyte:	.text	'??', 13, 10, '$'
timeout:	.text	'dnf',13,10,'$'
erased:		.text	'Erase complete',13,10,'$'
pageread:	.text	'Read a page from file',13,10,'$'
pagewrote:	.text	'Wrote a page to flash',13,10,'$'
targetaddrmsg:	.text	'Would erase 32kb sector at '
targetaddr:	.text	'????00',13,10,'$'

#data		DATA

		.org	TEXT_end
pagebuffer:	.ds	256
