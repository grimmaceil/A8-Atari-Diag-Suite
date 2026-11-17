; A stand-in piece for the disk plumbing's test (tools/disktest.py): loaded
; by the boot as a RAM piece, it turns the border green and stays.
	icl '../../src/common/hw.asm'
	opt h-
	org $0900
	.byte 0, NREC
	.word $0900, 0
	lda #C_GREEN
	sta COLBK
	lda #0
	sta NMIEN
st_lp	jmp st_lp
	:[128-[*-$0900]] .byte 0
NREC	= [*-$0900]/128
