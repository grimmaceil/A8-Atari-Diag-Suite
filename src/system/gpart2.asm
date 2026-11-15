; The 8K sound and video tape (diag-8k-05-av), part two: test 7's page 2,
; the display modes (t_gtia2.asm), with no room for it in part one. Part one
; reads it from the tape (common/loader.asm, as tape 1 reads its stage 2)
; over the tests it has run, at P2AT, and enters it at P2AT+6. It uses part
; one's library, test 7's gwave and gans, and its end (tend): their
; addresses are in build/part1.asm (build.py, from part one's labels).

	icl '../common/hw.asm'
	icl '../common/vars.asm'
	icl '../common/faults.asm'
	icl '../common/defs.asm'
	icl '../../build/part1.asm'

	opt h-
	org P2AT

; Same header layout as a boot file: part one checks the record count and
; the load address.
	.byte 0
	.byte NREC
	.word P2AT
	.word 0
	jmp gmodes

	icl 't_gtia2.asm'

; Whole pages; the last two bytes hold the sum (mkcas.py).
PADTO	= [[*+2+$FF]/$100]*$100
	.if PADTO-*-2>0
	:[PADTO-*-2] .byte 0
	.endif
P2SUM	.word 0
P2END
NREC	= [P2END-P2AT]/128
	.if P2END>TESTEND
	.error "part two runs past part one's tests into its library"
	.endif
