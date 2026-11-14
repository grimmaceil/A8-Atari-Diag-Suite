; Abstract reporter: border flashes paired with beeps.
; Uses no stack and no zero page, so it can report a low-RAM failure. Calls go
; through NCALL, which keeps the return address in a BSS vector; each call
; level has its own vector, so levels nest but don't recurse.

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


C_FLASH	= C_RED+4	; fail flash: brighter than the steady fail color
C_GFLASH = C_GREEN+4

; Tone table: frequency, flash color, length.
T_ALONG	= 0		; group A: long, red
T_BSHORT = 1		; group B: short, red
T_END	= 2		; end of list: low, long, red
T_J1	= 3		; pass jingle, green
T_J2	= 4
T_J3	= 5
T_GLONG	= 6		; pass: one long green flash per bank
T_RLONG	= 7		; SYSCODES: the ROM test's group A and B, lower than
T_RSHORT = 8		; the RAM's, so the two can be told apart by ear
tt_frq	.byte F_LONG, F_SHORT, F_END, F_J1, F_J2, F_J3, F_LONG
	.ifdef SYSCODES
	.byte F_RLONG, F_RSHORT
	.endif
tt_col	.byte C_FLASH, C_FLASH, C_FLASH, C_GFLASH, C_GFLASH, C_GFLASH, C_GFLASH
	.ifdef SYSCODES
	.byte C_FLASH, C_FLASH
	.endif
tt_lx	.byte <[600*157/10], <[200*157/10], <[600*157/10], <[100*157/10], <[100*157/10], <[300*157/10], <[600*157/10]
	.ifdef SYSCODES
	.byte <[600*157/10], <[200*157/10]
	.endif
tt_ly	.byte >[600*157/10+255], >[200*157/10+255], >[600*157/10+255], >[100*157/10+255], >[100*157/10+255], >[300*157/10+255], >[600*157/10+255]
	.ifdef SYSCODES
	.byte >[600*157/10+255], >[200*157/10+255]
	.endif

; ---------------------------------------------------------------------------
; delay: X + 256*(Y-1) scanlines, timed by WSYNC. While SPKMASK=$08 it also
; drives the console speaker at ~980 Hz, so a beep is still heard if POKEY is
; dead. (The OS keyclick drives CONSOL the same way.) Returns via RET2.
delay
dl_lp	sta WSYNC
	txa
	and #7
	bne dl_nt
	lda SPKPH
	eor SPKMASK
	sta SPKPH
	sta CONSOL
dl_nt	dex
	bne dl_lp
	dey
	bne dl_lp
	jmp (RET2)

; tone: flash and beep tone X of the table, then 200 ms black and silent.
; Returns via RET1.
; QUIET (the picture confirmed and the text on): the result is on the
; screen, so the border keeps its steady color and only the sound plays.
; After the tone it looks at the controls (once low RAM has passed: rpkey
; uses the stack), so a press doesn't have to wait for the end of a code.
tone	lda QUIET
	bne tn_nf
	lda tt_col,x
	sta COLBK
tn_nf	lda tt_frq,x
	sta AUDF1
	lda #AUD_ON
	sta AUDC1
	lda #$08
	sta SPKMASK
	ldy tt_ly,x
	lda tt_lx,x
	tax
	NCALL RET2, delay
	lda #AUD_OFF
	sta AUDC1
	lda #0
	sta SPKMASK
	lda #$08
	sta SPKPH
	sta CONSOL
	lda QUIET
	bne tn_nb
	lda #C_BLACK
	sta COLBK
tn_nb	WAITMS 200
	lda STACKOK
	beq tn_x
	jsr rpkey
tn_x	jmp (RET1)

; ---------------------------------------------------------------------------
; report: the failure code, until a press continues to CONTVEC (when set;
; never before low RAM passes). Without CONTVEC it never returns.
; Not quiet (see tone): the code repeats, flashing the border. Quiet: it
; plays once, then the border stays steady red and silent; SELECT plays it
; again. A press counts between the tones too, not only in the pause.
;   for each bad bank (1-4 main, 5-8 130XE): A = bank number (long), then
;   for each bad bit,
;   B = bit number 1-8 (short), then the low end-of-list tone.
;   Between repeats the border holds steady red for 3 s.
; A bad image checksum reports as A = 1 then the end tone, with no B groups:
; the RAM the loader landed in is suspect but no bit is known.
report	lda #AUD_OFF
	sta AUDC1
	lda #0
	sta HARMED
	lda #C_RED
	sta COLBK
	WAITMS 1000

rp_top	lda LOADERR
	beq rp_banks
	BEEP T_ALONG
	WAITMS 800
	BEEP T_END
	jmp rp_wait

rp_banks lda #1
	sta RBANK
rp_bank	ldx RBANK
	.ifdef SYSCODES		; the system tests: a code only for the ROMs (1)
	cpx #2			; and the RAM (8); the other tests' results are
	bcc rp_sy		; on the screen
	cpx #8
	bcs rp_sy
	jmp rp_next
rp_sy
	.endif
	lda BADMASK,x
	.if .def LDRFOLD
	cpx #1			; the loader area is part of bank 1
	bne rp_fold
	ora BADMASK+LDRIDX
rp_fold	cmp #0			; the CPX changed Z
	.endif
	bne rp_have
	jmp rp_next
rp_have	sta RMASK
	.ifdef SYSCODES		; one long tone, in the ROM's pitch or the RAM's
	lda #1
	sta RCNT
	lda #T_ALONG
	ldx RBANK
	cpx #1
	bne rp_tn
	lda #T_RLONG
rp_tn	sta RTONE
	.else
	lda RBANK
	sta RCNT
	lda #T_ALONG
	sta RTONE
	.endif
rp_along ldx RTONE
	NCALL RET1, tone
	dec RCNT
	bne rp_along
	WAITMS 800		; +200 after the last tone = 1 s between groups

	lda #0
	sta RBIT
rp_bit	lsr RMASK		; D0 first, reported as 1
	bcc rp_nobit
	ldx RBIT
	inx
	stx RCNT
rp_bshort ldx RTONE		; (the short tone follows its long one)
	inx
	NCALL RET1, tone
	dec RCNT
	bne rp_bshort
	WAITMS 800
rp_nobit inc RBIT
	lda RBIT
	cmp #8
	bne rp_bit

	BEEP T_END
	WAITMS 800
rp_next	inc RBANK
	lda RBANK
	cmp #9			; banks 1-8
	beq rp_wait
	jmp rp_bank

rp_wait	lda #30
	sta RCNT
	lda #0
	sta HSEL
	.if .def RPCOLVAR
	lda RPCOL		; the stage picks the steady color (burn-in: yellow
	.else			; when every error was intermittent)
	lda #C_RED
	.endif
	sta HOLDC
	NCALL RET1, hold
	lda HSEL		; SELECT: the code again
	bne rp_rep
	lda QUIET		; quiet: once was enough, wait on
	bne rp_wait
rp_rep	jmp rp_top

; rpkey: the controls, after a tone (JSR: only once STACKOK is set). A
; press of START, a key or fire, after all were seen released, goes on to
; CONTVEC (if one is set) and doesn't come back. (hold clears HARMED, so
; after a pause the controls must be seen released again.)
rpkey	jsr inputs
	bne rq_in
	lda #1
	sta HARMED
	rts
rq_in	ldx HARMED
	beq rq_x
	lsr
	bcc rq_x
	ldx CONTVEC+1
	beq rq_x
	pla
	pla
	jsr waitrel
	jmp (CONTVEC)
rq_x	rts

; ---------------------------------------------------------------------------
; pass: rising jingle. With a continue vector: hold green ~2 s, then go on.
; Without (the end of the tape): every ~5 s one long green flash per bank
; tested, steady green between, forever; quiet (see tone): steady green and
; silent.
pass	lda #C_GREEN
	sta COLBK
	lda #0			; (tone's look at the controls: a key still down
	sta HARMED		; from the test doesn't count)
	lda #T_J1
	sta RCNT
pa_jin	ldx RCNT
	NCALL RET1, tone
	inc RCNT
	lda RCNT
	cmp #T_J3+1
	bne pa_jin
	lda #20
	sta RCNT
	lda #C_GREEN
	sta HOLDC
	NCALL RET1, hold
	lda CONTVEC+1
	beq pa_top
	.ifdef RESTART
	lda ENDING		; the system tapes' end: START goes on (again),
	bne pa_top		; nothing goes on by itself
	.endif
	jmp (CONTVEC)
pa_top	lda QUIET
	bne pa_hold
	lda NBANKS
	sta RCNT
pa_long	BEEP T_GLONG
	dec RCNT
	bne pa_long
pa_hold	lda #50
	sta RCNT
	lda #C_GREEN
	sta HOLDC
	NCALL RET1, hold
	jmp pa_top

; hold: border = HOLDC for RCNT tenths of a second (set HOLDC before the
; NCALL: NCALL itself clobbers A). Once low RAM has passed (STACKOK) it
; also reads the controls; a press only counts after all of them have been
; seen released, so a stuck key does nothing:
;   START, any key, fire   go on to CONTVEC (if one is set)
;   SELECT                 end the pause: replay the code now
;   OPTION                 text <-> full-screen flashes (if the display
;                          checks passed); holding it holds the result
; Before low RAM passes STACKOK is 0 and no JSR runs. Returns via RET1.
hold	lda #0
	sta HARMED
ho_lp	lda HOLDC
	sta COLBK
	WAITMS 100
	lda STACKOK
	beq ho_n
	jsr inputs
	bne ho_in
	lda #1			; all released
	sta HARMED
	bne ho_n
ho_in	ldx HARMED
	beq ho_n
	lsr			; bit 0: go on
	bcc ho_sel
	ldx CONTVEC+1
	beq ho_n
	jsr waitrel
	jmp (CONTVEC)
ho_sel	lsr			; bit 1: SELECT
	bcc ho_opt
	jsr waitrel
	lda #1
	sta HSEL
	jmp (RET1)
ho_opt	lda DISPOK		; bit 2: OPTION
	beq ho_n
	jsr scrtoggle
ho_n	dec RCNT
	bne ho_lp
	jmp (RET1)

; inputs: A = bit 0 go on (START, a key, fire 0/1), bit 1 SELECT,
; bit 2 OPTION. Zero (Z set) when nothing is pressed.
inputs	lda CONSOL		; 0 = pressed
	eor #7
	and #7
	sta INB
	lda SKSTAT		; bit 2 = 0 while a key is held
	and #4
	beq in_go
	lda TRIG0
	and TRIG1
	and #1
	bne in_x
in_go	lda INB
	ora #1
	sta INB
in_x	lda INB
	rts

; waitrel: wait until every control is released.
waitrel	jsr inputs
	bne waitrel
	rts

; scrtoggle: text results <-> full-screen flashes (ANTIC off, easier to
; read when the picture is garbled). redraw is the stage's results screen.
scrtoggle lda SCRON
	beq tg_on
	jsr scr_off
	jmp waitrel
tg_on	jsr redraw
	jmp waitrel
