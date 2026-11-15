; Definitions every program and part shares: the macros and constants of
; the reporter (report.asm) and the text screen (screen.asm). No code. Every
; assembly includes it after hw.asm, vars.asm and faults.asm, so a part that
; takes the library's code from another part of its image (SHLIB, lib.asm)
; has them too.

; No-stack call: NCALL vector, target. The callee returns with JMP (vector).
; Clobbers A.
.macro NCALL
	lda #<ret
	sta :1
	lda #>ret
	sta :1+1
	jmp :2
ret
.endm

; WAITMS ms: busy-wait about that many milliseconds. Clobbers A/X/Y.
; delay counts X + 256*(Y-1) scanlines, so Y is the scanline count
; rounded up to whole pages.
.macro WAITMS
	ldx #<[:1*157/10]
	ldy #>[:1*157/10+255]
	NCALL RET2, delay
.endm

; BEEP n: one flash+beep from the tone table (T_* below), then 200 ms
; dark and silent.
.macro BEEP
	ldx #:1
	NCALL RET1, tone
.endm

; PRINT row, col, string
.macro PRINT
	lda #:1
	ldx #:2
	jsr at
	lda #<:3
	ldy #>:3
	jsr puts
.endm

C_FLASH	= C_RED+4	; fail flash: brighter than the steady fail color
C_GFLASH = C_GREEN+4

; Tone table (report.asm): frequency, flash color, length, the pause after.
T_ALONG	= 0		; group A: long, red
T_BSHORT = 1		; group B: short, red
T_END	= 2		; end of list: low, long, red
T_J1	= 3		; pass: the charge, G4 C5 E5 G5, green
T_J4	= 6
T_GLONG	= 7		; pass: one long green flash per bank
T_TR1	= 8		; fail: the sad trombone, two long notes falling
T_TR2	= 9
T_RLONG	= 10		; the ROM test's group A and B, lower than the RAM's,
T_RSHORT = 11		; so the two can be told apart by ear

C_TEXTBG = $00		; text area background (COLPF2); the border keeps the status color
C_TEXTLUM = $0C		; text luminance (COLPF1)
SCRDL	= $3C0		; display list offset in the 1K screen block
