		.z180

#target		bin
#code		TEXT, $100

#include	"src/z180registers.z80"

		.org	$100
start:		ld	hl, $81
		ld	de, srcaddr

spaces:		ld	a, (hl)
		inc	hl
		or	a
		jr	z, noargs
		cp	a, ' '
		jr	z, spaces

digits:		call	read_hex
		jr	c, badarg
		ex	de, hl
		rld
		inc	hl
		rld
		dec	hl
		ex	de, hl
		or	a
		jr	nz, overflow

		ld	a, (hl)
		inc	hl
		or	a
		jr	z, memcpy
		jr	digits

badarg:		dec	hl
		ld	a, (hl)
		ld	(badchar), a
		ld	de, badmsg
		jr	bail
noargs:		ld	de, usage
		jr	bail
overflow:	ld	de, toobig
bail:		ld	c, 9
		call	5
		jp	0

memcpy:		;; (srcaddr) contains the desired memory read location, address bits 20:4
		;; SAR0L should be set to address bits 7:0, SAR0H to 15:8, SAR0B to 20:16
		;; the first rld sets (srcaddr) to bits 7:0 and moves bits 11:8 into a
		;; the second rld moves bits 11:8 into (srcaddr+1) and shifts bits 15:12 up
		;; and also moves bits 20:16 into the low nibble of a
		ld	de, (srcaddr)
		ld	hl, srcaddr		; a is zero when arriving here
		rld				; a[3:0] = (hl)[7:4], (hl)[7:0] = {(hl)[3:0], a[3:0]}
		inc	hl			; high byte
		rld				; a[3:0] = (hl)[7:4], (hl)[7:0] = {(hl)[3:0], a[3:0]}
		out0	(SAR0B), a
		ld	bc, (srcaddr)
		out0	(SAR0L), c
		out0	(SAR0H), b

		;; put (srcaddr) back to how it was
		ld	(srcaddr), de

		xor	a
		out0	(DAR0B), a
		out0	(DAR0L), a
		ld	a, $10
		out0	(DAR0H), a

		ld	bc, 320
		out0	(BCR0L), c
		out0	(BCR0H), b

		ld	bc, 0110000000000010b
		out0	(DMODE), c
		out0	(DSTAT), b		; burst mode will halt CPU until complete

		ld	hl, $1000
		ld	c, 20
		call	dump_hex
		jp	0

srcaddr:	.dw	0
badmsg:		.text	'Invalid HEX digit "'
badchar:	.text	'?"',13,10,'$'
toobig:		.text	'Address too large - max. 4 digits',13,10,'$'
usage:		.text	'Usage: romdump <addr>',13,10,'    <addr>   the 16-bit page address to dump',13,10,'$'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read_hex - read an ascii HEX digit and convert it to binary
;;
;; in:		a	the hex digit to convert
;; out:		a	the binary digit, lower nibble
;;		cf	set if invalid input, clear otherwise
;;
#local
read_hex::
		sub	48			; convert to binary, if it's 0-9
		jr	c, invalid		; if < '0', it's no good
		cp	10
		jr	c, good			; if < 10, conversion is done
		or	$20			; convert to lower case
		sub	$31			; 'a' == 0
		jr	c, invalid		; less than 'a', it's no good
		add	$a			; 'a' == $a
		cp	$10			; should be $a-$f
		ccf				; invert cf from the cp
		ret
good:		or	a
		ret
invalid:	scf
		ret
#endlocal

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; dump_hex - dump a region of memory in canonical hex output format
;;
;; in:		hl	the region of memory to dump
;;		c	the number of rows of 16 bytes to dump
#local
dump_hex::
		;; print a row of (up to) 16 bytes
		ld	a, (srcaddr)
		call	bin_to_hex
		ld	(linemsg+2), de
		ld	a, (srcaddr+1)
		call	bin_to_hex
		ld	(linemsg), de

		ld	de, (srcaddr)
		inc	de
		ld	(srcaddr), de

		ld	b, 16
		ld	ix, linemsg+7
		ld	iy, linemsg+59

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
		jr	nz, dump_hex
		ret

linemsg:	.text	'????:  ?? ?? ?? ?? ?? ?? ?? ??  ?? ?? ?? ?? ?? ?? ?? ??    ????????????????', 13, 10, '$'

#endlocal

#include	"src/bin2hex.z80"

buffer		equ	$1000
