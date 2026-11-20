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
GRAFP0	= $D00D
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
; good, bank 2 or 3 neither good nor empty. Uses A and X.
.macro ISFAULT
	lda DDRA
	bne @+1
	lda DDRB
	beq @+
	cmp #$FF
	bne @+1
@	tsx
	txa
	beq @+1
	cmp #$FF
	beq @+1
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
sk_frq	dta F_LONG, F_SHORT, F_END, F_J0, F_J1, F_J2, F_J3, F_LONG, F_D1, F_D1, F_D2, 0
sk_col	dta C_RED+4, C_RED+4, C_RED+4, C_GREEN+4, C_GREEN+4, C_GREEN+4, C_GREEN+4
	dta C_GREEN+4, C_RED+4, C_RED+4, C_RED+4, C_RED
sk_lnl	dta <[37*1042-1], <[12*1042-1], <[37*1042-1], <[7*1042-1], <[7*1042-1]
	dta <[7*1042-1], <[20*1042-1], <[37*1042-1], <[15*1042-1], <[15*1042-1]
	dta <[55*1042-1], <[61*1042-1]
sk_lnh	dta >[37*1042-1], >[12*1042-1], >[37*1042-1], >[7*1042-1], >[7*1042-1]
	dta >[7*1042-1], >[20*1042-1], >[37*1042-1], >[15*1042-1], >[15*1042-1]
	dta >[55*1042-1], >[61*1042-1]
sk_gpl	dta <[12*1042-1], <[12*1042-1], <[12*1042-1], <[2*1042-1], <[2*1042-1]
	dta <[2*1042-1], <[12*1042-1], <[12*1042-1], <[6*1042-1], <[6*1042-1]
	dta <[25*1042-1], 0
sk_gph	dta >[12*1042-1], >[12*1042-1], >[12*1042-1], >[2*1042-1], >[2*1042-1]
	dta >[2*1042-1], >[12*1042-1], >[12*1042-1], >[6*1042-1], >[6*1042-1]
	dta >[25*1042-1], 0

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
tk_o	lda PACTL		; the sticks (port A): up = OPTION, down = SELECT
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
	bne snd
tk_s	tya
	and #$80
	ora #$40
	tay
	jmp skind

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
skf3	tsx			; bank 3
	txa
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
; sk_k: A = the position after the long beeps, X = the short beeps' count.
sk_k	cmp #0
	beq sk_sh		; still in the short beeps
	sec
	sbc #1
	dex
	bne sk_k
	cmp #0			; X ran out: A = past the short beeps
	beq sk_en
	cmp #4
	bcc sk_pa
	jmp sdone
sk_sh	ldx #T_BSHORT
	jmp skret
sk_en	ldx #T_END
	jmp skret
sk_pa	ldx #T_PAUSE
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

; rdisp: after a frame, to where Y says: the sound's ticks (bit 6).
rdisp	jmp tick

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
	PLAIN 8,DT_BLANK
	PLAIN 9,DT_BLANK
	PLAIN 10,DT_BLANK
	PLAIN 11,DT_BLANK
	PLAIN 12,DT_BLANK
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
