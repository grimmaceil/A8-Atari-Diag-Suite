; Abstract reporter: border flashes paired with beeps.
; Uses no stack and no zero page, so it can report a low-RAM failure. Calls go
; through NCALL, which keeps the return address in a BSS vector; each call
; level has its own vector, so levels nest but don't recurse.

; (The macros NCALL, WAITMS, BEEP and the tone numbers T_*: defs.asm.)

; SHLIB (lib.asm): one copy of this file serves every part of the image, so
; what the parts do differently is decided at run time: SYSMODE (the system
; tests: a code only for the ROMs and the RAM), REDRAWV (the screen OPTION
; brings back). Otherwise the part's own defines decide.
	.ifdef SHLIB
RPSYS	= 1
RPFOLD	= 1
RPEND	= 1
RPRAM	= 1
	.ifdef ONE32		; AUTON: the RAM summary goes on by itself where
RPAUTO	= 1			; the ROM test follows (the 32k+ image and the
	.elseif .def ROM	; cartridge, the boot disk; not the 16k RAM tape)
RPAUTO	= 1
	.elseif .def DISK
RPAUTO	= 1
	.endif
	.else
	.ifdef SYSCODES		; the system tests (system/main.asm)
RPSYS	= 1
	.else
RPRAM	= 1
	.endif
	.ifdef LDRFOLD		; stage 2, the memory test
RPFOLD	= 1
	.endif
	.ifdef RESTART		; the end waits for START
RPEND	= 1
	.endif
	.ifdef RAMPC		; the boot disk's RAM8: its results go on by
RPAUTO	= 1			; themselves (AUTON)
	.endif
	.endif

; Tone table: frequency, flash color, length and the pause after it, both
; in units of 256 scan lines (16 ms). The numbers: defs.asm.
;	A long  B short  END    the charge: G4 C5 E5 G5        GLONG   doom: C4 C4 F#3
tt_frq	.byte F_LONG, F_SHORT, F_END, F_J0, F_J1, F_J2, F_J3, F_LONG, F_D1, F_D1, F_D2
	.ifdef RPSYS
	.byte F_RLONG, F_RSHORT
	.endif
tt_col	.byte C_FLASH, C_FLASH, C_FLASH, C_GFLASH, C_GFLASH, C_GFLASH, C_GFLASH
	.byte C_GFLASH, C_FLASH, C_FLASH, C_FLASH
	.ifdef RPSYS
	.byte C_FLASH, C_FLASH
	.endif
tt_len	.byte 37, 12, 37, 7, 7, 7, 20, 37, 15, 15, 55	; (600 ms = 37)
	.ifdef RPSYS
	.byte 37, 12
	.endif
tt_gap	.byte 12, 12, 12, 2, 2, 2, 12, 12, 6, 6, 25	; (200 ms = 12)
	.ifdef RPSYS
	.byte 12, 12
	.endif

; ---------------------------------------------------------------------------
; delay: X + 256*(Y-1) scanlines, timed by WSYNC. While SPKMASK=$08 it also
; drives the console speaker at ~980 Hz, so a beep is still heard if POKEY is
; dead. (The OS keyclick drives CONSOL the same way.) It also notes START
; held down (SLATCH), so a short tap during a tone isn't lost: hold and
; rpkey take it as a press. Returns via RET2.
delay
dl_lp	sta WSYNC
	txa
	and #7
	bne dl_nt
	lda CONSOL
	lsr
	bcs dl_ns
	lda #1
	sta SLATCH
dl_ns	lda SPKPH
	eor SPKMASK
	sta SPKPH
	sta CONSOL
dl_nt	dex
	bne dl_lp
	dey
	bne dl_lp
	jmp (RET2)

; tone: flash and beep tone X of the table, then its pause, black and
; silent (200 ms; the charge's notes run on). Returns via RET1.
; QUIET (the picture confirmed and the text on): the result is on the
; screen, so the border keeps its steady color and only the sound plays.
; After the tone it looks at the controls (once low RAM has passed: rpkey
; uses the stack), so a press doesn't have to wait for the end of a code.
tone	stx TCUR
	lda QUIET
	bne tn_nf
	lda tt_col,x
	sta COLBK
tn_nf	lda tt_frq,x
	sta AUDF1
	lda #AUD_ON
	sta AUDC1
	lda #$08
	sta SPKMASK
	ldy tt_len,x
	ldx #0			; (delay: 256 lines a step)
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
tn_nb	ldx TCUR
	ldy tt_gap,x
	ldx #0
	NCALL RET2, delay
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
	lda STACKOK		; (before low RAM passed: BSS was just cleared,
	beq rp_na		; and there is no stack for arm)
	jsr arm
rp_na
	lda #C_RED
	sta COLBK
	WAITMS 1000

rp_top	lda #T_DM1		; impending doom (C4 C4 F#3), then the code
	sta RCNT
rp_dm	ldx RCNT
	NCALL RET1, tone
	inc RCNT
	lda RCNT
	cmp #T_DM3+1
	bne rp_dm
	lda LOADERR
	beq rp_banks
	BEEP T_ALONG
	WAITMS 800
	BEEP T_END
	jmp rp_wait

rp_banks lda #1
	sta RBANK
rp_bank	ldx RBANK
	.ifdef RPSYS		; the system tests: a code only for the ROMs (1)
	.ifdef SHLIB		; and the RAM (8); the other tests' results are
	lda SYSMODE		; on the screen
	beq rp_sy
	.endif
	cpx #2
	bcc rp_sy
	cpx #8
	bcs rp_sy
	jmp rp_next
rp_sy
	.endif
	lda BADMASK,x
	.ifdef RPFOLD
	cpx #1			; the loader area is part of bank 1
	bne rp_fold
	ora BADMASK+LDRIDX
rp_fold	cmp #0			; the CPX changed Z
	.endif
	bne rp_have
	jmp rp_next
rp_have	sta RMASK
	.ifdef RPSYS		; the system tests: one long tone, in the ROM's
	.ifdef SHLIB		; pitch or the RAM's
	lda SYSMODE
	beq rp_ram
	.endif
	lda #1
	sta RCNT
	lda #T_ALONG
	ldx RBANK
	cpx #1
	bne rp_tn
	lda #T_RLONG
rp_tn	sta RTONE
	.ifdef RPRAM
	jmp rp_along
	.endif
	.endif
	.ifdef RPRAM		; the RAM: the bank number in long tones
rp_ram	lda RBANK
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
	.ifdef RPAUTO
	lda AUTON		; counting (the RAM summary, the ROM test next):
	beq rp_q		; the third round goes on by itself
	dec AUTON
	bne rp_q
	jmp (CONTVEC)
rp_q
	.endif
	lda QUIET		; quiet: once was enough, wait on
	bne rp_wait
rp_rep	jmp rp_top

; rpkey: the controls, after a tone (JSR: only once STACKOK is set). A
; press of START, a key or fire, after all were seen released, goes on to
; CONTVEC (if one is set) and doesn't come back. The others wait in SLATCH
; for the next pause (hold): a stick's press is only seen once.
rpkey	jsr inputs
	ldx HARMED
	bne rq_in
	ldx #0			; not seen released yet: nothing counts
	stx SLATCH
	cmp #0
	bne rq_x
	inc HARMED
	rts
rq_in	ora SLATCH
	sta SLATCH
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
; pass: the charge (G4 C5 E5 G5); twice at the end (no continue vector, or
; ENDING 2: the final results). Then it waits, with no time limit, so the
; screen can be read: every ~5 s one long green flash per bank tested,
; steady green between; quiet (see tone): steady green and silent. A key
; goes on (the continue vector; at the end of a tape: the tones again).
; AUTON set (the RAM summary where the ROM test follows): after that many
; rounds it goes on by itself, as report does; a press first stops the count.
pass	lda #C_GREEN
	sta COLBK
	jsr arm
	ldx #1			; once, or twice at the end
	lda CONTVEC+1
	beq pa_2
	lda ENDING
	cmp #2
	bne pa_n
pa_2	inx
pa_n	stx RBIT		; (repeats left: RBIT is free here)
pa_rep	lda #T_J1
	sta RCNT
pa_jin	ldx RCNT
	NCALL RET1, tone
	inc RCNT
	lda RCNT
	cmp #T_J4+1
	bne pa_jin
	dec RBIT
	bne pa_rep
	lda #20
	sta RCNT
	lda #C_GREEN
	sta HOLDC
	NCALL RET1, hold
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
	lda HSEL		; T, SELECT (or a key at the end): the charge
	.ifdef RPAUTO		; again
	bne pa_ch
	lda AUTON		; counting (the RAM summary, the ROM test next):
	beq pa_top		; the third round goes on by itself
	dec AUTON
	bne pa_top
	jmp (CONTVEC)
pa_ch
	.else
	beq pa_top
	.endif
	jmp pass

; hold: border = HOLDC for RCNT tenths of a second (set HOLDC before the
; NCALL: NCALL itself clobbers A). Once low RAM has passed (STACKOK) it
; also reads the controls; a press only counts after all of them have been
; seen released, so a stuck key does nothing:
;   START, any key, fire   go on to CONTVEC (if one is set)
;   SELECT                 end the pause: replay the code now
;   OPTION                 text <-> full-screen flashes (if the display
;                          checks passed); holding it holds the result
;   (each with a key too, for a dead console key: T = SELECT, F = OPTION)
;   R                      the test again (RETESTV, if one is set)
; With no CONTVEC (the end of a tape) a key plays the tones again, as
; SELECT does.
; (HARMED, "seen released", is cleared by whoever starts a result: pass,
; report. Not here: a pause is entered over and over, and a tap
; that began just then was lost.)
; Before low RAM passes STACKOK is 0 and no JSR runs. Returns via RET1.
hold
ho_lp	lda HOLDC
	sta COLBK
	WAITMS 100
	lda STACKOK
	beq ho_n
	jsr inputs
	ldx HARMED
	bne ho_in
	ldx #0			; not seen released yet: nothing counts
	stx SLATCH
	cmp #0
	bne ho_n
	inc HARMED		; all released
	bne ho_n
ho_in	ora SLATCH
	beq ho_n
	lsr			; bit 0: go on
	bcc ho_sel
	ldx CONTVEC+1		; (none: the end: the tones again)
	beq ho_tn
	jsr waitrel
	jmp (CONTVEC)
ho_sel	lsr			; bit 1: SELECT or T: the tones again
	bcc ho_opt
ho_tn	jsr waitrel
	lda #1
	sta HSEL
	jmp (RET1)
ho_opt	lsr			; bit 2: OPTION or F: the flashes
	bcc ho_rt
	ldx DISPOK
	beq ho_n
	jsr scrtoggle		; (returns with Z set)
	beq ho_n
ho_rt	ldx RETESTV+1		; bit 3: R: the test again
	beq ho_n
	jsr waitrel
	jmp (RETESTV)
ho_n	dec RCNT
	bne ho_lp
	jmp (RET1)

; arm: a fresh result. Controls held now don't count (a key still down from
; the test), but if none is, the next press does, even one in the first
; tone.
arm	lda #0
	sta HARMED
	sta SLATCH
	sta HSEL
	jsr inputs
	bne am_x
	inc HARMED
am_x	rts

; inputs: A = bit 0 go on (START, a key, fire), bit 1 SELECT, T or stick
; down, bit 2 OPTION, F or stick up, bit 3 R. Zero (Z set) when nothing is
; pressed. The console keys and the keyboard count while held, a joystick
; only as a new press (joyc): a stuck one (a short) holds nothing up.
; Uses A, X, Y. FIREONLY (the 8K memtest: no room for joyc): fire only,
; also only as a new press.
	.ifdef FIREONLY
inputs	lda TRIG0
	and TRIG1
	and #1			; 1: no fire now
	tay
	eor #1			; down now,
	and JPREV		; and up at the last look
	sty JPREV
	.else
inputs	jsr joyc
	.endif
	sta INB
	lda CONSOL		; 0 = pressed
	eor #7
	and #7
	ora INB
	sta INB
	lda SKSTAT		; bit 2 = 0 while a key is held
	and #4
	bne in_x
	lda KBCODE
	and #$3F
	ldx #3
in_k	cmp in_kc-1,x		; T, F, R
	beq in_kx
	dex
	bne in_k
in_kx	lda in_kb,x		; (X = 0: another key: go on)
	ora INB
	sta INB
in_x	lda INB
	rts
in_kc	.byte $2D, $38, $28	; T, F, R (KBCODE)
in_kb	.byte 1, 2, 4, 8

; joyc: a joystick in port 1 or 2 as the console keys, on every screen,
; for a machine with no keyboard (or a dead one): fire = START, down =
; SELECT, up = OPTION. A = the ones pressed since the last look, as
; CONSOL's bits but 1 = pressed (Z set: none), so one held down, or stuck
; (boot.asm's short check), counts once; a caller primes it (one call)
; where a held stick must not count. Left and right are left out: they are
; the paddles' triggers. Keeps X.
	.ifndef FIREONLY
joyc	lda PORTA		; stick 1: bits 0-3, stick 2: 4-7 (0 = pressed)
	lsr
	lsr
	lsr
	lsr
	and PORTA		; either stick
	and #3			; up, down
	tay
	lda TRIG0
	and TRIG1
	lsr			; C clear: fire
	lda jc_map,y
	bcs jc_nf
	ora #1
jc_nf	tay			; now
	eor JPREV
	sty JPREV
	and JPREV		; changed, and pressed now
	rts
jc_map	.byte 6, 2, 4, 0	; down+up, down, up, neither (0 = pressed)
	.endif

; waitrel: wait until every control is released. (RPAUTO: whatever was
; pressed, someone is there: a count to going on by itself stops.)
waitrel	jsr inputs
	bne waitrel
	sta SLATCH		; (0)
	.ifdef RPAUTO
	sta AUTON
	.endif
	rts

; scrtoggle: text results <-> full-screen flashes (ANTIC off, easier to
; read when the picture is garbled). redraw is the stage's results screen.
scrtoggle lda SCRON
	beq tg_on
	jsr scr_off
	jmp waitrel
tg_on
	.ifdef SHLIB
	jsr rdvec
	.else
	jsr redraw
	.endif
	jmp waitrel
	.ifdef SHLIB
rdvec	jmp (REDRAWV)		; (each part sets it: its results screen)
	.endif
