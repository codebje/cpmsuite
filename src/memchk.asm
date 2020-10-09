		.z180

#target		bin
#code		TEXT, $100

#include	"src/z180registers.z80"

		.org	$100

		;; set up the bank area at $c000 logical
		ld	a, $fc
		out0	(CBAR), a

		;; the first bank to test should be physical $10000
		;; which now maps into the BBR as $10000-$c000 = $4000
		;; the bank counter will run from $4 to $73
		ld	d, $4

bankloop:	out0	(BBR), d
		ld	sp, $b000	; safely out of the ay
		ld	hl, $c000
		ld	bc, $10		; 16 outer loops, 256 inner loops, 4096 each time

loop:		ld	a, (hl)
		push	af
		xor	$be		; less predictable bit pattern
		ld	(hl), a
		ld	e, a
		ld	a, (hl)
		cp	e
		jr	nz, fail	; if a different value is read back, it's bad
		pop	af
		ld	(hl), a		; restore what was there

		djnz	loop		; dec b, loop if not zero
		dec	c
		jr	nz, loop	; ... 16 times

		call	cleanup
		jp	0

cleanup:	ld	bc, $f000
		out0	(BBR), c
		out0	(CBAR), b
		ret

fail:		push	bc
		call	cleanup
		pop	bc

		ld	a, d
		call	bin_to_hex
		ld	(badmsg), de
		; bc counts down from $1000, s.t. when bc=$1000 the third three digits should be 000
		; and when bc=$0001 the third three digits should be FFF
		ld	a, $10
		sub	b
		call	bin_to_hex
		ld	a, e
		ld	(badmsg+2), a
		xor	a
		sub	c
		call	bin_to_hex
		ld	(badmsg+3), de
		ld	c, 9
		call	5
		jp	0

badmsg:		.text	'?????: memory test failed',13,10,'$'

#include	"src/bin2hex.z80"

#end
