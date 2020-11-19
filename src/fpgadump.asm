		.z180

#target		bin
#code		TEXT, $100
#data		DATA, *

#include	"src/z180registers.z80"
#include	"src/tbios.z80"

#code		TEXT

		.org	$100

		;; FPGA firmware revision
		in0	a, (FPGA_VERSION)
		call	bin_to_hex
		ld	(versionbyte), de
		ld	de, versionmsg
		ld	c, CPM_WRITESTR
		call	BDOS

		;; SPI control register
		in0	a, (SPI_CTRL)
		call	bin_to_hex
		ld	(statusbyte), de

		ld	de, statusmsg
		ld	c, 9
		call	5

		;; read the manufacturer's ID
		ld	a, SPI_CTRL_FLASH_READ
		out0	(SPI_CTRL), a

		ld	a, $AB			; command: wake from power-down
		out0	(SPI_DATA), a
		xor	a
		out0	(SPI_DATA), a		; four dummy bytes for command plus one read
		out0	(SPI_DATA), a
		out0	(SPI_DATA), a
		out0	(SPI_DATA), a

		in0	a, (SPI_DATA)		; Device ID
		call	bin_to_hex
		ld	(idbyte2), de

		xor	a			; Turn off SPI
		out0	(SPI_CTRL), a

		ld	de, idmsg		; Print the IDs
		ld	c, 9
		call	5

		;; Wake from power-down only returns Device ID, so ask for Manufacturer ID too
		ld	a, SPI_CTRL_FLASH_READ
		out0	(SPI_CTRL), a

		ld	a, $90			; Read Manufacturer/Device ID
		out0	(SPI_DATA), a
		xor	a
		out0	(SPI_DATA), a		; Three address bytes, all zero
		out0	(SPI_DATA), a
		out0	(SPI_DATA), a
		out0	(SPI_DATA), a		; One byte to begin reading

		in0	a, (SPI_DATA)		; Manufacturer ID
		call	bin_to_hex
		ld	(idbyte1), de

		in0	a, (SPI_DATA)		; Device ID
		call	bin_to_hex
		ld	(idbyte2), de

		xor	a			; Turn off SPI
		out0	(SPI_CTRL), a

		ld	de, idmsg		; Print the IDs
		ld	c, 9
		call	5

		;; Read the second FPGA bitstream
		ld	a, SPI_CTRL_FLASH_READ
		out0	(SPI_CTRL), a

		ld	a, $0b			; SPI Flash fast read command
		out0	(SPI_DATA), a		; Three address bytes, $008000
		xor	a
		out0	(SPI_DATA), a
		ld	a, $80
		out0	(SPI_DATA), a
		xor	a
		out0	(SPI_DATA), a
		out0	(SPI_DATA), a		; One dummy byte for fast read
		out0	(SPI_DATA), a		; One dummy byte to begin reading data

		ld	hl, pagebuffer
		ld	bc, SPI_DATA		; b = 0, c = input port
		ld	d, 125			; 125x256 = 32000 bytes
readloop:	inir				; 256x reads into hl from (bc), b decrements each time
		dec	d
		jr	nz, readloop
		ld	b, 220			; read remaining 220 bytes
		inir

		xor	a
		out0	(SPI_CTRL), a

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

readreg:	ld	a, SPI_CTRL_FLASH_READ
		out0	(SPI_CTRL), a
		out0	(SPI_DATA), d

		in0	a, (SPI_DATA)
		in0	a, (SPI_DATA)

		call	bin_to_hex
		ld	(spistatusbyte), de

		xor	a
		out0	(SPI_CTRL), a

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

#include	"src/bin2hex.z80"
#include	"src/dump_hex.z80"
#include	"src/ymcrc.z80"

#data		DATA

		.org	TEXT_end
pagebuffer:	.ds	32220
