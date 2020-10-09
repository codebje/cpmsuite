		.z180

#target		bin
#code		TEXT, $100
#data		DATA, *

#include	"src/z180registers.z80"
#include	"src/tbios.z80"

#code		TEXT

		org	$100

		ld	sp, $d000

		; open the default fcb
		ld	de, CPM_FCB
		ld	c, CPM_FOPEN
		call	5
		inc	a
		jp	z, badfile

		; erase sector
		call	write_enable
		ld	bc, $100
		ld	a, $1c
		out	(c), a
		ld	c, $04
		ld	a, $52				; erase 32Kb block
		out	(c), a
		ld	ix, writeaddr
		ld	a, (ix+0)
		out	(c), a				; address 23-16
		ld	a, (ix+1)
		out	(c), a				; address 15-8
		ld	a, (ix+2)
		out	(c), a				; address 7-0
		ld	c, $00
		ld	a, $0c
		out	(c), a

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

		ld	a, (writeaddr+1)
		inc	a
		ld	(writeaddr+1), a
		cp	$10
		jr	nc, loadloop

		ld	de, oversizemsg
		ld	c, CPM_WRITESTR
		call	BDOS

written:	ld	de, completemsg
		ld	c, CPM_WRITESTR
		call	BDOS

		rst	0

badfile:	ld	de, badfilemsg
		ld	c, CPM_WRITESTR
		call	BDOS
		rst	0

write_enable:	ld	bc, $100			; begin SPI
		ld	a, $1c
		out	(c), a

		ld	c, $04				; cmd 06: Write Enable
		ld	a, $06
		out	(c), a

		ld	c, $00				; end SPI
		ld	a, $0c
		out	(c), a
		ret

readreg:	ld	a, $1c
		ld	bc, $100
		out	(c), a

		ld	a, d
		ld	c, $04
		out	(c), a

		in	a, (c)
		call	bin_to_hex
		ld	(spistatusbyte), de

		ld	d, $0c			; restore usual blinky lights, turn off SPI
		ld	bc, $100
		out	(c), d

		ret


;; wait until busy bit is clear
wait_busy:	ld	bc, $100
		ld	a, $1c
		out	(c), a

		ld	c, $04
		ld	a, $05
		out	(c), a

wait_loop:	in	a, (c)
		tst	$01
		jr	nz, wait_loop

waited:		ld	c, $00
		ld	a, $0c
		out	(c), a

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

		ld	bc, $100
		ld	a, $1c
		out	(c), a

		ld	c, $04
		ld	a, $02
		out	(c), a
		ld	ix, writeaddr
		ld	a, (ix+0)
		out	(c), a
		ld	a, (ix+1)
		out	(c), a
		ld	a, (ix+2)
		out	(c), a

		ld	d, 0
		ld	hl, pagebuffer

write_loop:	ld	a, (hl)
		out	(c), a
		inc	hl
		dec	d
		jr	nz, write_loop

		ld	c, $00
		ld	a, $0c
		out	(c), a

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

writeaddr	.db	$00, $80, $00

badfilemsg:	.text	'File invalid, cannot open',13,10,'$'
completemsg:	.text	'File successfully written',13,10,'$'
oversizemsg:	.text	'File larger than 32K: truncated',13,10,'$'
spistatusmsg:	.text	'SPI Flash status register '
spistatusreg:	.text	'1: '
spistatusbyte:	.text	'??', 13, 10, '$'
timeout:	.text	'dnf',13,10,'$'
erased:		.text	'Erase complete',13,10,'$'
pageread:	.text	'Read a page from file',13,10,'$'
pagewrote:	.text	'Wrote a page to flash',13,10,'$'

#data		DATA

		.org	TEXT_end
pagebuffer:	.ds	256
