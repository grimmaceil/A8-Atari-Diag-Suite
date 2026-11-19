; The short check: a joystick line already active at power-on (port 1 or 2:
; a direction or the button) is stuck. A switch closes its line to ground,
; so a stuck switch, a pinched cable or a bad port pin all read as a press
; that never ends; nobody holds a stick while the machine starts. The
; programs only take a new press from a stick (report.asm's joyc), so it
; holds nothing up; this shows it, as a signal, not an alarm: three
; shots, each a beep falling fast in pitch ("pew") with the whole screen
; bright orange (ANTIC must be off: all of it is the border), near black
; and quiet after it. Each shot and its gap is one count of Y: $10-$7F the
; beep (AUDF1 = Y: 1.9 kHz down to 250 Hz), $80-$FF the gap, a step every
; S scan lines. S is 16, then 12, then 8, so each shot is a little quicker
; than the one before and the two gaps between them differ (0.13 s, then
; 0.1 s): about half a second in all.
; Registers only (common/boot.asm: no RAM tested yet), so the step is kept
; in S, the stack pointer: the includer pushes nothing until it sets S
; again. Needs the interrupts off, POKEY running (AUDCTL 0, SKCTL 3) and
; voice 1 free; leaves voice 1 off and the border near black. 62 bytes:
; the 8k input tape has 2 to spare (at 0.12).
SC_ORANGE = $28			; bright deep orange (#C06A22 on the MiSTer)
SC_TONE	= $AA			; pure tone, volume 10
SC_F0	= $10			; the beep's first pitch
	lda TRIG0
	and TRIG1		; bit 0: 0 if a button is down
	ora #$FE
	and PORTA		; $FF: nothing down
	cmp #$FF
	beq sc_x
	ldx #16			; S: the step, in scan lines
	txs
sc_shot	lda #SC_ORANGE
	sta COLBK
	lda #SC_TONE
	ldy #SC_F0
sc_gp	sta AUDC1
sc_sw	sty AUDF1		; (in the gap too: silent)
	tsx
sc_w	sta WSYNC
	dex
	bne sc_w
	iny
	beq sc_nx		; Y round to 0: the shot and its gap done
	bpl sc_sw		; below $80: the beep
	lda #AUD_OFF		; $80-$FF: the gap, quiet, and near black
	sta COLBK		; ($A0 as a color; each step: no harm)
	bmi sc_gp		; (always)
sc_nx	tsx			; the next shot: a shorter step
	dex
	dex
	dex
	dex
	txs
	cpx #4
	bne sc_shot
sc_x
