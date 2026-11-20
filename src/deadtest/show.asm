; The show bank (DEADBK+1; in the standalone, the same bank): the results
; on screen, with no RAM. Every line is ready-made in ROM (text.txt,
; tools/mkdtext.py), and the frame kernel picks each row's line by pointing
; ANTIC at its display-list fragment while the row before is drawn: the
; display list itself is never in RAM. The kernel also sets each row's
; background (COLPF2: green OK, red BAD, C_NONE for no RAM) and, on a bank's
; row, player 0 straight from the bank's mask (GRAFP0, no P/M DMA): a red
; box behind each bad bit's digit (quadruple width: one bit a column).
;
; The kernel uses A and X; Y says where it returns to (rdisp): no stack.
; Rows: 0 title, 2 zero page, 3 stack, 5-7 banks 1-3, 20 the verdict, 22
; the keys on a fault; the rest blank.
C_NONE	= $04			; a bank with no RAM (not a fault above bank 1)
PMCOL	= 30			; the bit digits' first column (76543210)

; WAITROW r: to the start of row r's first scan line: VCOUNT 15+4r is the
; row before's last two lines; then two line syncs.
.macro WAITROW
	lda #15+4*:1
	cmp VCOUNT
	bne *-3
	sta WSYNC
	sta WSYNC
.endm

; SETDL frag: ANTIC's next row from this fragment.
.macro SETDL
	lda #<:1
	sta DLISTL
	lda #>:1
	sta DLISTH
.endm

; PLAIN r, next: row r black, no box; row r+1 from fragment next.
.macro PLAIN
	WAITROW :1
	lda #0
	sta COLPF2
	sta GRAFP0
	sta WSYNC
	SETDL :2
.endm

; FLAG r, ctl, next0, next1: row r black; row r+1 by bit 0 of ctl
; (PACTL: zero page, PBCTL: stack).
.macro FLAG
	WAITROW :1
	lda #0
	sta COLPF2
	sta GRAFP0
	sta WSYNC
	lda :2
	and #1
	bne @+
	SETDL :3
	jmp @+1
@	SETDL :4
@
.endm

; FLAGROW r, ctl, next...: row r green or red by bit 0 of ctl.
.macro FLAGCOL
	ldx #C_GREEN
	lda :1
	and #1
	beq @+
	ldx #C_RED
@
.endm

; MASKCOL: X = the row's colour from the mask in A: 0 green, $FF :1 (red
; for bank 1, C_NONE above it), else red.
.macro MASKCOL
	ldx #C_GREEN
	cmp #0
	beq @+1
	ldx #:1
	cmp #$FF
	beq @+1
@	ldx #C_RED
@
.endm

; PICK3: row's fragment from the mask in A: OK, BAD, NONE.
.macro PICK3
	cmp #0
	bne @+
	SETDL :1
	jmp @+2
@	cmp #$FF
	bne @+
	SETDL :3
	jmp @+1
@	SETDL :2
@
.endm

; ISFAULT target: to target (a jmp away) on any fault: bank 1 not all
; good, bank 2 or 3 neither good nor empty, or (stage A's R_ROMBAD) an OS
; chip unknown or not there. Uses A and X.
.macro ISFAULT
	lda DDRA
	bne @+2
	lda DDRB
	beq @+
	cmp #$FF
	bne @+2
@	tsx
	txa
	beq @+
	cmp #$FF
	bne @+1
@
	.ifdef STANDALONE
	jmp @+1
	.else
	lda $0400+$413		; the RAM passed, so stage A ran from $0400: an
	beq @+1			; OS chip unknown or not there (R_ROMBAD)
	.endif
@	jmp :1
@
.endm

; The tones (report.asm's tt_* tables, copied: kinds T_ALONG 0 to T_DM3
; 10) and a silent one (T_PAUSE, ~1 s); lengths in POKEY timer counts at
; 64 kHz with voices 3 and 4 joined: report.asm's units (256 scan lines,
; 16.3 ms) x 1042.
T_ALONG	= 0			; (defs.asm's numbers: the table's order)
T_BSHORT = 1
T_END	= 2
T_J1	= 3
T_DM1	= 8
T_PAUSE	= 11
T_RLONG	= 12			; the ROM test's code (test 1, item 3): lower
T_RSHORT = 13			; tones, as report.asm's
sk_frq	dta F_LONG, F_SHORT, F_END, F_J0, F_J1, F_J2, F_J3, F_LONG, F_D1, F_D1, F_D2, 0
	dta F_RLONG, F_RSHORT
sk_col	dta C_RED+4, C_RED+4, C_RED+4, C_GREEN+4, C_GREEN+4, C_GREEN+4, C_GREEN+4
	dta C_GREEN+4, C_RED+4, C_RED+4, C_RED+4, C_RED, C_RED+4, C_RED+4
sk_lnl	dta <[37*1042-1], <[12*1042-1], <[37*1042-1], <[7*1042-1], <[7*1042-1]
	dta <[7*1042-1], <[20*1042-1], <[37*1042-1], <[15*1042-1], <[15*1042-1]
	dta <[55*1042-1], <[61*1042-1], <[37*1042-1], <[12*1042-1]
sk_lnh	dta >[37*1042-1], >[12*1042-1], >[37*1042-1], >[7*1042-1], >[7*1042-1]
	dta >[7*1042-1], >[20*1042-1], >[37*1042-1], >[15*1042-1], >[15*1042-1]
	dta >[55*1042-1], >[61*1042-1], >[37*1042-1], >[12*1042-1]
sk_gpl	dta <[12*1042-1], <[12*1042-1], <[12*1042-1], <[2*1042-1], <[2*1042-1]
	dta <[2*1042-1], <[12*1042-1], <[12*1042-1], <[6*1042-1], <[6*1042-1]
	dta <[25*1042-1], 0, <[12*1042-1], <[12*1042-1]
sk_gph	dta >[12*1042-1], >[12*1042-1], >[12*1042-1], >[2*1042-1], >[2*1042-1]
	dta >[2*1042-1], >[12*1042-1], >[12*1042-1], >[6*1042-1], >[6*1042-1]
	dta >[25*1042-1], 0, >[12*1042-1], >[12*1042-1]

; TIMERX tlo, thi: POKEY's voices 3 and 4 joined, 64 kHz, counting table
; entry X (tlo,x and thi,x): IRQST bit 2 goes to 0 when it runs out (polled;
; interrupts stay off).
.macro TIMERX
	lda #$08
	sta AUDCTL
	lda :1,x
	sta AUDF1+4
	lda :2,x
	sta AUDF1+6
	lda #0
	sta AUDC1+4
	sta AUDC1+6
	sta IRQEN
	lda #4
	sta IRQEN
	sta STIMER
.endm

; DIGIT: A (0-15) as a hex digit's screen code ('0' $10, 'A' $21).
.macro DIGIT
	cmp #10
	bcc *+4
	adc #6
	adc #$10
.endm

; HEX2 addr: A as two digits at addr (the second's byte holds A meanwhile).
.macro HEX2
	sta :1+1
	lsr
	lsr
	lsr
	lsr
	DIGIT
	sta :1
	lda :1+1
	and #$0F
	DIGIT
	sta :1+1
.endm

; LIVEB base: the live input row's numbers in the work page at base (stage
; A left the row's text at base+160): KBCODE (the last key), the console
; keys (0 = pressed, bits 0-2), the sticks (PORTA: 0 = pressed).
.macro LIVEB
	lda KBCODE
	HEX2 :1+160+12
	lda CONSOL
	and #7
	ora #$10
	sta :1+160+23
	lda PACTL
	ora #4
	sta PACTL
	ldx PORTA
	lda PACTL
	and #$FB
	sta PACTL
	txa
	HEX2 :1+160+34
.endm

; LIVE: LIVEB for the first good bank's page; with none, nothing.
.macro LIVE
	lda DDRA
	bne @+
	LIVEB $0400
	jmp @+2
@	lda DDRB
	bne @+
	LIVEB $4000
	jmp @+1
@	tsx
	txa
	bne @+
	LIVEB $8000
@
.endm

; show (phase 0): stage B's results, from the PIA and S, with their sound:
; a pass plays the charge and hands over; a fault plays its code (the
; suite's tones: doom, a long beep per the first bad bank's number, short
; beeps for its lowest bad bit's number + 1, the end tone, 3 s quiet)
; round after round, until START or fire (after a release) goes on.
; SELECT or down plays the code again from the start; OPTION or up turns
; the screen off while held, so the whole screen is the border's flashes.
;
; Y carries the state from frame to frame: bit 6 set (rdisp: a sound
; tick), bit 7 START released since the fault began, bits 1-5 the position
; in the tune, bit 0 the note (0) or the gap after it (1).
show	lda #>FONTAT
	sta CHBASE
	lda #0
	sta GRACTL		; players written directly, no DMA
	sta GRAFP0
	lda #3			; quadruple width: a bit to a column
	sta SIZEP0
	lda #48+PMCOL*4		; the digits' first column (a column = 4 clocks)
	sta HPOSP0
	lda #C_RED
	sta COLPM0
	lda #1			; players in front: the digit keeps PF1's
	sta PRIOR		; brightness over the box's red
	lda #$22
	sta DMACTL
	ldy #$40		; the tune from the start
	jmp skind

; tick: after each frame.
tick	ISFAULT tk_f
	jmp snd			; (a pass: no keys)
tk_f	lda CONSOL		; START or fire: on, once released
	and #1
	beq tk_sd
	lda TRIG0
	beq tk_sd
	tya
	ora #$80
	tay
	jmp tk_o
tk_sd	tya
	bpl tk_o
	.ifndef STANDALONE
	jmp handover
	.endif
tk_o
	.ifndef STANDALONE
	LIVE			; the live input row, with a good page
	.endif
	lda PACTL		; the sticks (port A): up = OPTION, down = SELECT
	ora #4
	sta PACTL
	ldx PORTA
	lda PACTL
	and #$FB
	sta PACTL
	txa
	and #1			; OPTION or up: the screen off while held
	beq tk_oo
	lda CONSOL
	and #4
	beq tk_oo
	lda #$22
	bne tk_od
tk_oo	lda #0
tk_od	sta DMACTL
	txa			; SELECT or down: the code again from the start
	and #2
	beq tk_s
	lda CONSOL
	and #2
	bne tk_c
tk_s	tya
	and #$80
	ora #$40
	tay
	jmp skind
tk_c
	.ifndef STANDALONE
	tya			; on: the tune, or the ROM phase (bit 6 clear)
	and #$40
	bne tk_t
	jmp rsnd
	.endif
tk_t	jmp snd

; snd: the note or the gap still running: another frame; else on.
snd	lda IRQST
	and #4
	beq sn_t
	jmp frame
sn_t	tya
	and #1
	bne sn_g
	lda #0			; the note is over: silence, the border back
	sta AUDF1		; (0 between notes: each note's frequency is a
	lda #AUD_OFF		; new write)
	sta AUDC1
	ISFAULT sn_rf
	lda #C_GREEN
	bne sn_c
sn_rf	lda #C_RED
sn_c	sta COLBK
	iny			; the gap after it
	jmp skind
sn_g	iny			; the gap is over: the next note
	jmp skind

; skind: X = the kind at Y's position; then the note (Y bit 0 clear) or
; its gap (set) starts. Past the tune's end: sdone. A pass: the charge
; (T_J1-T_J4). A fault: doom (T_DM1-T_DM3), a long beep per the first bad
; bank's number, short beeps for its lowest bad bit's number + 1, the end
; tone, three silent pauses.
skind	ISFAULT skf
	tya
	lsr
	and #$1F
	cmp #4
	bcc sk_pj
	jmp sdone
sk_pj	adc #T_J1		; (C clear)
	tax
	jmp skret
skf	lda DDRA		; the first bad bank, its mask in A
	beq skf2
	ldx #1			; bank 1: X = the lowest bad bit + 1
sk1b	lsr
	bcs sk1c
	inx
	bne sk1b
sk1c	tya
	lsr
	and #$1F
	cmp #3
	bcc sk_dm
	sbc #3
	cmp #1
	bcc sk_lg
	sbc #1
	jmp sk_k
skf2	lda DDRB
	beq skf3
	cmp #$FF
	beq skf3
	ldx #1			; bank 2
sk2b	lsr
	bcs sk2c
	inx
	bne sk2b
sk2c	tya
	lsr
	and #$1F
	cmp #3
	bcc sk_dm
	sbc #3
	cmp #2
	bcc sk_lg
	sbc #2
	jmp sk_k
skf3	tsx			; bank 3 (when it is the fault)
	txa
	beq skr
	cmp #$FF
	beq skr
	ldx #1
sk3b	lsr
	bcs sk3c
	inx
	bne sk3b
sk3c	tya
	lsr
	and #$1F
	cmp #3
	bcc sk_dm
	sbc #3
	cmp #3
	bcc sk_lg
	sbc #3
	jmp sk_k
sk_dm	adc #T_DM1		; doom (C clear)
	tax
	jmp skret
sk_lg	ldx #T_ALONG
	jmp skret
; skr: the RAM is fine: stage A's fault (R_ROMBAD, in $0400's page: the
; RAM passed): bit 0 an OS chip: test 1's code (one long), item 3 (three
; short); bits 1-2 ANTIC or GTIA: test 7; bit 3 POKEY: test 6; bit 4 the
; PIA: test 4 (its ports); one short beep each; the ROM test's tones.
.macro SXPOS
	tya
	lsr
	and #$1F
	cmp #3
	bcs @+
	jmp sk_dm
@	sbc #3
.endm

; SXLONG n: past n long beeps on to the short ones (sk_kr), or a long one.
.macro SXLONG
	cmp #:1
	bcs @+
	jmp sk_rl
@	sbc #:1
	jmp sk_kr
.endm
skr	lda $0400+$413
	lsr
	bcs sx_rom
	lsr
	bcs sx_7
	lsr
	bcs sx_7
	lsr
	bcs sx_6
	ldx #1			; the PIA
	SXPOS
	SXLONG 4
sx_rom	ldx #3
	SXPOS
	SXLONG 1
sx_7	ldx #1
	SXPOS
	SXLONG 7
sx_6	ldx #1
	SXPOS
	SXLONG 6
sk_kr	cmp #0
	beq sk_rs
	sec
	sbc #1
	dex
	bne sk_kr
	jmp sk_kx
sk_rl	ldx #T_RLONG
	jmp skret
sk_rs	ldx #T_RSHORT
	jmp skret
; sk_k: A = the position after the long beeps, X = the short beeps' count.
sk_k	cmp #0
	beq sk_sh		; still in the short beeps
	sec
	sbc #1
	dex
	bne sk_k
sk_kx	cmp #0			; X ran out: A = past the short beeps
	beq sk_en
	cmp #4
	bcc sk_pa
	jmp sdone
sk_sh	ldx #T_BSHORT
	jmp skret
sk_en	ldx #T_END
	jmp skret
sk_pa
	.ifndef STANDALONE
	lda DDRA		; a pause: with no RAM anywhere the OS chips
	beq sk_p2		; are shown in its place (rphase)
	lda DDRB
	beq sk_p2
	tsx
	txa
	beq sk_p2
	jmp rphase
	.endif
sk_p2	ldx #T_PAUSE
skret	tya
	and #1
	bne sk_gap
	lda sk_frq,x		; the note: tone, the border's flash colour
	sta AUDF1
	lda #AUD_ON
	cpx #T_PAUSE
	bne skr1
	lda #AUD_OFF
skr1	sta AUDC1
	lda sk_col,x
	cpx #T_PAUSE
	beq skr2		; (a pause: the border as it is)
	sta COLBK
skr2	TIMERX sk_lnl,sk_lnh
	jmp frame
sk_gap	TIMERX sk_gpl,sk_gph
	jmp frame

; sdone: past the tune's end. A pass goes on to the suite (the standalone
; stays, quiet); a fault plays its code again.
sdone	ISFAULT sd_f
	.ifdef STANDALONE
	ldy #$7E		; (a position past the end: quiet frames)
	lda #0
	sta IRQEN		; (the timer never fires again)
	jmp frame
	.else
	jmp handover
	.endif
sd_f	tya
	and #$80
	ora #$40
	tay
	jmp skind

; rdisp: after a frame: the sound's ticks or the ROM phase's (tick sorts
; them by Y bit 6 after the keys).
rdisp	jmp tick

	.ifndef STANDALONE	; (the standalone has no room for it)
; rphase: with no RAM anywhere, in the fault round's pause: each OS chip in
; turn, ~1.5 s each, in row 9 by its CRC-8 (romcrc8.asm: known, unknown, or
; a floating bus: not there). While Y holds a CRC-8, the START-released bit
; waits in PACTL bit 1; then Y = that bit, bit 6 clear, the chip (bits
; 2-3: 0 $D800, 1 $E000, 2 $F000, 3 the XL/XE image) and its result (bits
; 0-1: 0 known, 1 unknown, 2 not there), which row 9's fragment comes from.
rphase	lda PACTL
	and #$FD
	sta PACTL
	tya
	bpl rp_m
	lda PACTL
	ora #2
	sta PACTL
rp_m	ldy #0			; the machine: page $C0 floating = a 400/800
	ldx #0
rp_c0	tya
	eor.w $C000,x
	tay
	lda crc8t,y
	tay
	inx
	bne rp_c0
	cpy #C8FL_C0
	beq rpch0
	jmp rpchx

; C8PAGES lo, hi: byte X of pages lo to hi-1 into the CRC-8 in Y.
.macro C8PAGES
	.rept :2-:1
	tya
	eor.w $100*[:1+.r],x
	tay
	lda crc8t,y
	tay
	.endr
.endm

; C8RES list, floating, chip: A = the result for the CRC-8 in Y (0 known,
; 1 unknown, 2 not there), with the chip number, to rp_show.
.macro C8RES
	ldx :1
@	tya
	cmp :1,x
	beq @+1
	dex
	bne @-
	cpy #:2
	bne @+
	lda #2
	jmp @+2
@	lda #1
	jmp @+1
@	lda #0
@	ora #4*:3
	jmp rp_show
.endm

rpch0	ldy #0
	ldx #0
rp0	C8PAGES $D8,$E0
	inx
	beq *+5
	jmp rp0
	C8RES c8_d8,C8FL_D8,0
rpch1	ldy #0
	ldx #0
rp1	C8PAGES $E0,$F0
	inx
	beq *+5
	jmp rp1
	C8RES c8_e0,C8FL_E0,1
rpch2	ldy #0
	ldx #0
rp2	C8PAGES $F0,$100
	inx
	beq *+5
	jmp rp2
	C8RES c8_f0,C8FL_F0,2
rpchx	ldy #0
	ldx #0
rpx	C8PAGES $C0,$D0
	C8PAGES $D8,$100
	inx
	beq *+5
	jmp rpx
	C8RES c8_xl,C8FL_XL,3

; rp_show: A = the chip and result: into Y with the START-released bit,
; then ~1.5 s of frames (POKEY's 15 kHz clock: voices 3 and 4 joined).
rp_show	tay
	lda PACTL
	and #2
	beq rs_t
	tya
	ora #$80
	tay
rs_t	lda #$09
	sta AUDCTL
	lda #<23549
	sta AUDF1+4
	lda #>23549
	sta AUDF1+6
	lda #0
	sta AUDC1+4
	sta AUDC1+6
	sta IRQEN
	lda #4
	sta IRQEN
	sta STIMER
	jmp frame

; rsnd: the ROM phase after a frame (and the keys): the next chip when the
; time is up; after the last, the code from the start.
rsnd	lda IRQST
	and #4
	beq rn_n
	jmp frame
rn_n	lda PACTL		; the START-released bit to PACTL bit 1 again
	and #$FD
	sta PACTL
	tya
	bpl rn_c
	lda PACTL
	ora #2
	sta PACTL
rn_c	tya
	and #$0C
	bne rn_1
	jmp rpch1
rn_1	cmp #4
	bne rn_e
	jmp rpch2
rn_e	tya			; done: the code again
	and #$80
	ora #$40
	tay
	jmp skind

; rpfrag: row 9's fragment in the ROM phase, by Y bits 0-3.
rpfl	dta <DT_OSD8_OK,<DT_OSD8_UNK,<DT_OSD8_NONE,<DT_BLANK
	dta <DT_OSE0_OK,<DT_OSE0_UNK,<DT_OSE0_NONE,<DT_BLANK
	dta <DT_OSF0_OK,<DT_OSF0_UNK,<DT_OSF0_NONE,<DT_BLANK
	dta <DT_OSXL_OK,<DT_OSXL_UNK,<DT_OSXL_NONE,<DT_BLANK
rpfh	dta >DT_OSD8_OK,>DT_OSD8_UNK,>DT_OSD8_NONE,>DT_BLANK
	dta >DT_OSE0_OK,>DT_OSE0_UNK,>DT_OSE0_NONE,>DT_BLANK
	dta >DT_OSF0_OK,>DT_OSF0_UNK,>DT_OSF0_NONE,>DT_BLANK
	dta >DT_OSXL_OK,>DT_OSXL_UNK,>DT_OSXL_NONE,>DT_BLANK

	.endif

; OSROW off, done: rows 9-11 with a good page: the line stage A left at
; B+off (B: the first good bank's); with none, on past it.
.macro OSROW
	lda DDRA
	bne @+
	SETDL [$0400+:1]
	jmp :2
@	lda DDRB
	bne @+
	SETDL [$4000+:1]
	jmp :2
@	tsx
	txa
	bne @+
	SETDL [$8000+:1]
	jmp :2
@
.endm

; frame: one frame of the results screen. From the vertical blank: the
; top fragment (blank lines and the title), then each row.
frame	lda #124
	cmp VCOUNT
	bne *-3
	SETDL dtop
	PLAIN 0,DT_BLANK
	FLAG 1,PACTL,DT_ZP_OK,DT_ZP_BAD
	FLAGCOL PACTL		; row 2: zero page
	WAITROW 2
	stx COLPF2
	sta WSYNC
	lda PBCTL
	and #1
	bne @+
	SETDL DT_STACK_OK
	jmp @+1
@	SETDL DT_STACK_BAD
@	FLAGCOL PBCTL		; row 3: the stack page
	WAITROW 3
	stx COLPF2
	sta WSYNC
	SETDL DT_BLANK
	WAITROW 4		; row 4, then bank 1's line
	lda #0
	sta COLPF2
	sta WSYNC
	lda DDRA
	PICK3 DT_B1_OK,DT_B1_BAD,DT_B1_NONE
	lda DDRA		; row 5: bank 1
	MASKCOL C_RED
	WAITROW 5
	stx COLPF2
	lda DDRA
	cmp #$FF
	bne @+
	lda #0
@	sta GRAFP0
	sta WSYNC
	lda DDRB
	PICK3 DT_B2_OK,DT_B2_BAD,DT_B2_NONE
	lda DDRB		; row 6: bank 2
	MASKCOL C_NONE
	WAITROW 6
	stx COLPF2
	lda DDRB
	cmp #$FF
	bne @+
	lda #0
@	sta GRAFP0
	sta WSYNC
	tsx
	txa
	PICK3 DT_B3_OK,DT_B3_BAD,DT_B3_NONE
	tsx			; row 7: bank 3
	txa
	MASKCOL C_NONE
	WAITROW 7
	stx COLPF2
	tsx
	txa
	cmp #$FF
	bne @+
	lda #0
@	sta GRAFP0
	sta WSYNC
	SETDL DT_BLANK
	WAITROW 8		; row 8, then the first OS row
	lda #0
	sta COLPF2
	sta GRAFP0
	sta WSYNC
	.ifndef STANDALONE
	OSROW $3C0,fr_o9
	tya			; no RAM: the ROM phase's line, or blank
	and #$40
	bne fr_n9
	tya
	and #$0F
	tax
	lda rpfl,x
	sta DLISTL
	lda rpfh,x
	sta DLISTH
	jmp fr_o9
	.endif
fr_n9	SETDL DT_BLANK
fr_o9	WAITROW 9		; row 9, then the second
	lda #0
	sta COLPF2
	sta WSYNC
	.ifndef STANDALONE
	OSROW $3C4,fr_o10
	.endif
	SETDL DT_BLANK
fr_o10	WAITROW 10		; row 10, then the third
	lda #0
	sta COLPF2
	sta WSYNC
	.ifndef STANDALONE
	OSROW $3C8,fr_o11
	.endif
	SETDL DT_BLANK
fr_o11	WAITROW 11		; row 11, then the other chips' line (row 12)
	lda #0
	sta COLPF2
	sta WSYNC
	.ifndef STANDALONE
	OSROW $3CC,fr_o12
	SETDL DT_NEEDRAM	; (no RAM: they need it)
	.else
	SETDL DT_BLANK
	.endif
fr_o12	WAITROW 12		; row 12, then the live input row (13)
	lda #0
	sta COLPF2
	sta WSYNC
	.ifndef STANDALONE
	OSROW $3D0,fr_o13
	.endif
	SETDL DT_BLANK
fr_o13
	PLAIN 13,DT_BLANK
	PLAIN 14,DT_BLANK
	PLAIN 15,DT_BLANK
	PLAIN 16,DT_BLANK
	PLAIN 17,DT_BLANK
	PLAIN 18,DT_BLANK
	WAITROW 19		; row 19, then the verdict's line
	lda #0
	sta COLPF2
	sta GRAFP0
	sta WSYNC
	ISFAULT fr_vf
	SETDL DT_VERDICT_PASS
	ldx #C_GREEN
	jmp fr_v
fr_vf	SETDL DT_VERDICT_FAULT
	ldx #C_RED
fr_v	WAITROW 20		; row 20: the verdict
	stx COLPF2
	sta WSYNC
	SETDL DT_BLANK
	WAITROW 21		; row 21, then the keys on a fault
	lda #0
	sta COLPF2
	sta WSYNC
	ISFAULT fr_kf
	SETDL DT_BLANK
	jmp fr_k
fr_kf	SETDL DT_KEYS
fr_k	PLAIN 22,DT_BLANK
	PLAIN 23,djvb		; then the jump back to the top
	jmp rdisp

dtop	dta $70,$70,$70,$42,a(scr)	; blank lines and the title
djvb	dta $41,a(dtop)
