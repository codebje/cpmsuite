;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; bin_to_hex - convert an 8-bit binary value to hex digits
;;
;; https://stackoverflow.com/questions/22838444/convert-an-8bit-number-to-hex-in-z80-assembler
;;
;; in:		a	value
;; out:		de	hex digits
#local
bin_to_hex::	push	af
		push	bc
		ld	c, a
		call	shift
		ld	e, a
		ld	a, c
		call	convert
		ld	d, a
		pop	bc
		pop	af
		ret

shift:		rra		; shift higher nibble to lower
		rra
		rra
		rra
convert:	or	a, $f0
		daa		; I've no idea if this will work on a Z180...
		add	a, $a0
		adc	a, $40
		ret
#endlocal


