; The other chips, dead-test style: the end of stage A's RAM code
; (ramcode.asm includes this, so it runs from the good page, RB, with no
; stack and no zero page). Each check sets a bit in R_ROMBAD when the chip
; fails (bit 1 ANTIC, 2 GTIA, 3 POKEY, 4 PIA: the show bank's verdict and
; code); then row 12's line (ANTIC OK  GTIA OK  POKEY OK  PIA OK, BAD where
; one failed), row 13's (the live input row: the show bank fills in its
; numbers while a fault waits) and row 14's (what the ANTIC and GTIA checks
; measured: VCOUNT's top, GTIA's PAL/NTSC flag, the tries).
R_VTOP	= RB+$424		; VCOUNT's highest
R_PREV	= RB+$425		; VCOUNT the read before
R_WRAP	= RB+$426		; times VCOUNT went back down (frames)
R_T	= RB+$427		; RANDOM's first read
R_SV1	= RB+$428		; DDRA (bank 1's result) while the PIA is checked
R_SV2	= RB+$429		; DDRB (bank 2's)
R_TRY	= RB+$42A		; ANTIC's tries (up to three: one glitch after a
				; quick power off and on isn't a bad chip)

; ANTIC: VCOUNT over about 3 frames: its top is 130 (NTSC, 262 lines) or 155
; (PAL, 312), and it wraps. Up to three tries.
chips	lda #0
	sta R_TRY
ch_try	inc R_TRY
	lda #0
	sta R_VTOP
	sta R_WRAP
	lda VCOUNT
	sta R_PREV
	ldy #0
	ldx #0
ch_v	lda VCOUNT
	cmp R_VTOP
	bcc ch_v1
	sta R_VTOP
ch_v1	cmp R_PREV
	bcs ch_v2
	inc R_WRAP
ch_v2	sta R_PREV
	inx
	bne ch_v
	iny
	cpy #12
	bne ch_v
	lda R_VTOP
	cmp #130
	beq ch_vt
	cmp #155
	bne ch_vb
ch_vt	lda R_WRAP
	bne ch_g
ch_vb	lda R_TRY		; again, up to three times
	cmp #3
	bcs ch_vx
	jmp ch_try
ch_vx	lda R_ROMBAD
	ora #2
	sta R_ROMBAD

; GTIA: its PAL flag agrees with the frame ANTIC makes (PAL: VCOUNT's top
; 155, NTSC 130), and player 0 over a text row sets its playfield
; collision, which HITCLR clears.
ch_g	lda PAL
	and #$0E
	beq ch_gp
	cmp #$0E
	bne ch_gx
	lda R_VTOP
	cmp #130
	beq ch_gc
ch_gx	jmp ch_gb
ch_gp	lda R_VTOP
	cmp #155
	bne ch_gx
ch_gc	lda #$70		; a screen: OS row 9's line, from RAM
	sta R_FRAG+$20
	sta R_FRAG+$21
	sta R_FRAG+$22
	lda #$42
	sta R_FRAG+$23
	lda #<R_LINES
	sta R_FRAG+$24
	lda #>R_LINES
	sta R_FRAG+$25
	lda #$41
	sta R_FRAG+$26
	lda #<[R_FRAG+$20]
	sta R_FRAG+$27
	sta DLISTL
	lda #>[R_FRAG+$20]
	sta R_FRAG+$28
	sta DLISTH
	lda #>FONTAT
	sta CHBASE
	lda #0
	sta GRACTL
	sta SIZEP0
	lda #100		; across the row's middle
	sta HPOSP0
	lda #$22
	sta DMACTL
	sta HITCLR
	lda #$FF
	sta GRAFP0
	FRAMES 2
	lda P0PF
	beq ch_gb
	lda #0
	sta GRAFP0
	sta HITCLR
	FRAMES 2
	lda P0PF
	beq ch_gk
ch_gb	lda R_ROMBAD
	ora #4
	sta R_ROMBAD
ch_gk	lda #0
	sta GRAFP0
	sta DMACTL

; POKEY: RANDOM gives more than one value in 16 reads, and timer 1 runs out
; (IRQST bit 0, polled: interrupts stay off).
	lda RANDOM
	sta R_T
	ldx #16
ch_r	lda RANDOM
	cmp R_T
	bne ch_t
	dex
	bne ch_r
	jmp ch_pb
ch_t	lda #0
	sta AUDCTL
	sta AUDC1
	sta IRQEN
	lda #10
	sta AUDF1
	lda #1
	sta IRQEN
	sta STIMER
	FRAMES 1
	lda IRQST
	and #1
	beq ch_pk
ch_pb	lda R_ROMBAD
	ora #8
	sta R_ROMBAD
ch_pk	lda #0
	sta IRQEN

; The PIA: both direction registers read back $55 and $AA (their results
; kept here meanwhile).
	lda DDRA
	sta R_SV1
	lda DDRB
	sta R_SV2
	lda #$55
	sta DDRA
	sta DDRB
	cmp DDRA
	bne ch_ib
	cmp DDRB
	bne ch_ib
	lda #$AA
	sta DDRA
	sta DDRB
	cmp DDRA
	bne ch_ib
	cmp DDRB
	beq ch_ik
ch_ib	lda R_ROMBAD
	ora #16
	sta R_ROMBAD
ch_ik	lda R_SV1
	sta DDRA
	lda R_SV2
	sta DDRB

; Rows 12, 13 and 14's lines (3, 4 and 5).
	ldx #39
ch_l	lda s_chips,x
	sta R_LINES+120,x
	lda s_live,x
	sta R_LINES+160,x
	lda s_vc,x
	sta R_LINES+200,x
	dex
	bpl ch_l
	lda R_VTOP		; VCOUNT's top, in decimal
	ldx #$10
ch_d1	cmp #100
	bcc ch_d2
	sbc #100
	inx
	bne ch_d1
ch_d2	stx R_LINES+200+11
	ldx #$10
ch_d3	cmp #10
	bcc ch_d4
	sbc #10
	inx
	bne ch_d3
ch_d4	stx R_LINES+200+12
	ora #$10
	sta R_LINES+200+13
	lda R_TRY		; the tries
	ora #$10
	sta R_LINES+200+38
	lda PAL			; GTIA's flag: NTSC, PAL or ?
	and #$0E
	beq ch_fp
	cmp #$0E
	beq ch_fx
	lda #$1F		; ('?')
	sta R_LINES+200+26
	lda #0
	sta R_LINES+200+27
	sta R_LINES+200+28
	sta R_LINES+200+29
	jmp ch_fx
ch_fp	ldx #3
ch_fq	lda s_pal,x
	sta R_LINES+200+26,x
	dex
	bpl ch_fq
ch_fx
	lda R_ROMBAD
	and #2
	beq ch_l1
	BADAT 6
ch_l1	lda R_ROMBAD
	and #4
	beq ch_l2
	BADAT 15
ch_l2	lda R_ROMBAD
	and #8
	beq ch_l3
	BADAT 25
ch_l3	lda R_ROMBAD
	and #16
	beq ch_l4
	BADAT 33
ch_l4	FRAG 3
	FRAG 4
	FRAG 5
	jmp sa_ret
