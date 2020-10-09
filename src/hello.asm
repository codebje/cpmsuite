
		.z180

#target		bin
#code		TEXT, $100
#data		DATA, *

#include	"src/z180registers.z80"
#include	"src/tbios.z80"

#code		TEXT

		org	$100

		ld	de, hello
		ld	c, 9
		call	5
		jp	0

hello:		.text	'hello world', 13, 10, '$'
