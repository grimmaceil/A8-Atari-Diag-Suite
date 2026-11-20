; Stage A (phase 1): from stage B when some bank passed. The first good
; bank gives a work page B (bank 1 $0400, bank 2 $4000, bank 3 $8000), and
; stage B goes to the dead bank built for it (DEADBK+2, +3, +4: SABASE):
; neither zero page nor the stack is needed, so the work runs there even
; when zero page is bad. ramcode.asm, assembled for B, is copied to B+$500
; and run: each OS chip's CRC32, named from test 1's
; table (romtab.asm), and the OS rows' lines and display-list fragments
; left in B for the show bank (rows 9-11). Then on to the show bank.
; ramcode.asm's macros and strings are here; its labels are local (ra).

; CALL target: a call with no stack: the return address to R_RET, A, X
; and Y kept (A through R_A); the target ends with jmp (R_RET).
.macro CALL
	sta R_A
	lda #<[*+16]
	sta R_RET
	lda #>[*+11]
	sta R_RET+1
	lda R_A
	jmp :1
.endm

; DEST addr: puts writes there. HEXDEST addr: hex writes there.
.macro DEST
	lda #<[:1]
	sta ps_d+1
	lda #>[:1]
	sta ps_d+2
.endm
.macro HEXDEST
	lda #<[:1]
	sta hx_d+1
	sta hx_e+1
	lda #>[:1]
	sta hx_d+2
	sta hx_e+2
.endm

; DIGIT: A (0-15) as a hex digit's screen code ('0' $10, 'A' $21).
.macro DIGIT
	cmp #10
	bcc *+4
	adc #6
	adc #$10
.endm

; FRAG k: row k's fragment: mode 2 from line k.
.macro FRAG
	lda #$42
	sta R_FRAG+4*:1
	lda #<[R_LINES+40*:1]
	sta R_FRAG+4*:1+1
	lda #>[R_LINES+40*:1]
	sta R_FRAG+4*:1+2
.endm

; BLANKLINE k: line k blank (its fragment too).
.macro BLANKLINE
	ldx #39
	lda #0
	sta R_LINES+40*:1,x
	dex
	bpl *-4
	FRAG :1
.endm

; LINE k, label: line k as test 1 shows an OS chip: the label, the name at
; column 11 (REV and the name, UNKNOWN inverse, or NOT THERE), the CRC32
; at column 29 ($ then 8 digits; none when the chip isn't there).
.macro LINE
	BLANKLINE :1
	DEST R_LINES+40*:1
	lda #<:2
	ldy #>:2
	CALL puts
	DEST R_LINES+40*:1+11
	lda R_IDS+:1
	cmp #$FE
	bne @+
	lda #<s_nt
	ldy #>s_nt
	CALL puts
	jmp @+3
@	cmp #$FF
	bne @+
	lda #<s_unk
	ldy #>s_unk
	CALL puts
	jmp @+1
@	sta R_N
	lda #<s_rev
	ldy #>s_rev
	CALL puts
	DEST R_LINES+40*:1+15
	lda R_N
	asl
	tax
	lda romnames,x
	ldy romnames+1,x
	CALL puts
@	lda #4
	sta R_LINES+40*:1+29
	HEXDEST R_LINES+40*:1+30
	lda #4*:1
	sta R_SLOT
	CALL hex
@
.endm

; COPYRUN from, to, length: the RAM code to the work page, run there.
.macro COPYRUN
	.rept [[:3]+255]/256
	ldx #0
	lda :1+$100*.r,x
	sta :2+$100*.r,x
	inx
	bne *-7
	.endr
	jmp :2
.endm

stagea	lda #0			; (no display list for ANTIC in this bank: the
	sta DMACTL		; screen off for the half second this takes)
	COPYRUN ra.tmpl,SABASE+$500,ra.rend-ra.rstart

; sa_ret: the RAM code's end: on to the show bank.
sa_ret	ldx #DEADBK+1
	ldy #0
	jmp XBANK

lbl_d8	dta d'OS $D800',$FF
lbl_e0	dta d'OS $E000',$FF
lbl_f0	dta d'OS $F000',$FF
lbl_c0	dta d'OS $C000',$FF
lbl_xl	dta d'OS XL/XE',$FF
s_rev	dta d'REV ',$FF
s_unk	dta d'UNKNOWN'*,$FF
s_nt	dta d'NOT THERE',$FF

	.local ra
RB	= SABASE
	icl 'ramcode.asm'
	.endl

	icl '../common/romtab.asm'
	icl 'crc32tab.asm'
