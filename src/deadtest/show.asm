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

; TIMER: POKEY's voices 3 and 4 joined, 64 kHz: IRQST bit 2 goes to 0
; about 1 s from now (polled; interrupts stay off).
.macro TIMER
	lda #$08
	sta AUDCTL
	lda #$FF
	sta AUDF1+4		; AUDF3
	sta AUDF1+6		; AUDF4
	lda #0
	sta AUDC1+4
	sta AUDC1+6
	sta IRQEN		; (clears a pending one)
	lda #4
	sta IRQEN
	sta STIMER
.endm

; show (phase 0): stage B's results, from the PIA and S.
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
	ISFAULT sh_f
	lda #C_GREEN		; a pass: about 2 s, then the suite
	sta COLBK
	TIMER
sh_p1	ldy #0
	jmp frame
ret0	lda IRQST
	and #4
	bne sh_p1
	TIMER
sh_p2	ldy #1
	jmp frame
ret1	lda IRQST
	and #4
	bne sh_p2
	.ifdef STANDALONE
sh_p3	ldy #4			; no suite: the pass stays
	jmp frame
ret4	jmp sh_p3
	.else
	jmp handover
	.endif

sh_f	lda #C_RED		; a fault: until START (or fire), after a release
	sta COLBK
sh_f1	ldy #2
	jmp frame
ret2	lda CONSOL
	and #1
	beq sh_f1
	lda TRIG0
	beq sh_f1
sh_f2	ldy #3
	jmp frame
ret3	lda CONSOL
	and #1
	beq sh_go
	lda TRIG0
	bne sh_f2
sh_go
	.ifdef STANDALONE
	jmp sh_f1		; (no suite to go on to)
	.else
	jmp handover
	.endif

; rdisp: back to the caller Y names.
rdisp	cpy #0
	bne @+
	jmp ret0
@	cpy #1
	bne @+
	jmp ret1
@	cpy #2
	bne @+
	jmp ret2
@	cpy #3
	bne @+
	jmp ret3
@
	.ifdef STANDALONE
	jmp ret4
	.else
	jmp *
	.endif

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
