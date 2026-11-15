; Test 7: GTIA by eye, all on one screen.
;   item 1: something looks wrong:
;     eight luminance steps and sixteen hues, drawn by changing COLPF2 down
;     the screen with WSYNC (no interrupts);
;     the sprites: the word ATARI from the ROM font, players 0-3 as A T A R
;     and the four missiles side by side as the I (PRIOR bit 4: they take
;     COLPF3's color), all double width, scrolling across one color clock a
;     frame under the ramps, a new color on every scan line and the rainbow
;     moving a step each frame. On the cartridge (ROM) the word also bounces
;     up and down, 8 scan lines each way: the letters are written again at
;     a new height every frame.
; The video standard is shown. Without a picture there is nothing to judge:
; the test is skipped.
GL_ROW	= 5			; first text row of the luminance ramp (rows 5-11)
GH_ROW	= 13			; first text row of the hue ramp (rows 13-18)
GROW	= 19			; the letters' zone: rows 19-22 (they sit in 20-21,
				; or move through all four)
GPX	= TSCR+$00		; the word's left edge, color clocks
GBASE	= TSCR+$01		; the rainbow's first color, 0-15
GPH	= TSCR+$02		; ROM: the bounce, 0-63
GPM	= $04			; P/M block: missiles $0580, players $0600-$07FF
GY	= 16+GROW*4		; P/M byte of row GROW (double-line): the zone's top

t_gtia	lda #7
	sta TEST
	lda #<s_t7
	ldy #>s_t7
	jsr tpage
	lda DISPOK
	bne gt_go
	jmp tend
gt_go	PRINT 4, 0, s_glum
	PRINT 12, 0, s_ghue
	PRINT 23, 0, s_gq
	lda #<s_vntsc
	ldy #>s_vntsc
	ldx ISPAL
	beq gt_v
	lda #<s_vpal
	ldy #>s_vpal
gt_v	pha
	tya
	pha
	lda #3
	ldx #0
	jsr at
	pla
	tay
	pla
	jsr puts

	lda #0
	tay
gs_pm	sta GPM*$100+$100,y	; the P/M block clear
	sta GPM*$100+$200,y
	sta GPM*$100+$300,y
	iny
	bne gs_pm
	sta GPX
	sta GBASE
	sta GPH
	lda #4			; the letters, mid-zone
	jsr gletters
	ldx #3
gs_sz	lda #1			; players double width
	sta SIZEP0,x
	dex
	bpl gs_sz
	lda #$55		; missiles too
	sta SIZEM
	lda #$11		; players in front, missiles as a fifth player
	sta PRIOR
	lda #GPM
	sta PMBASE
	lda #$2E		; + player and missile DMA, double-line
	sta DMACTL
	lda #3
	sta GRACTL
	jsr waitrel

gt_lp	lda VCOUNT		; luminance: 8 steps of 7 lines, rows 5-11 (8 of 8
	cmp #[32+GL_ROW*8]/2-1	; ran into row 12's label). VCOUNT counts line
	bne gt_lp		; pairs: start a pair early, end inside row 11
	ldx #0
gt_l	txa
	asl
	sta WSYNC
	sta COLPF2
	ldy #6
gt_l1	sta WSYNC
	dey
	bne gt_l1
	inx
	cpx #8
	bne gt_l
	lda #C_TEXTBG		; (in the horizontal blank after the last WSYNC)
	sta COLPF2
gt_w	lda VCOUNT		; hue: 16 steps of 3 lines, rows 13-18
	cmp #[32+GH_ROW*8]/2-1
	bne gt_w
	ldx #0
gt_h	txa
	asl
	asl
	asl
	asl
	ora #8
	sta WSYNC
	sta COLPF2
	sta WSYNC
	sta WSYNC
	inx
	cpx #16
	bne gt_h
	lda #C_TEXTBG
	sta COLPF2
	ldx GBASE		; the letters' zone, rows 19-22: a color a line,
	ldy #32			; the hue the line number plus GBASE (worked out:
gt_r	txa			; hue in the high nibble, luminance 8)
	asl
	asl
	asl
	asl
	ora #8
	sta WSYNC
	sta COLPM0
	sta COLPM0+1
	sta COLPM0+2
	sta COLPM0+3
	sta COLPF3
	inx
	dey
	bne gt_r

	.ifdef ROM		; the bounce: the letters at the next height
	inc GPH			; (now: ANTIC is past them, below row 22)
	lda GPH
	and #63
	tax
	lda gsine,x
	jsr gletters
	.endif
	inc GPX			; each frame: one step across, one rainbow step
	lda GPX
	ldx #0
gs_hp	sta HPOSP0,x		; P0-P3, 20 color clocks apart
	clc
	adc #20
	inx
	cpx #4
	bne gs_hp
	sta HPOSP0+7		; the I: M3 (left) to M0, 4 apart
	clc
	adc #4
	sta HPOSP0+6
	adc #4
	sta HPOSP0+5
	adc #4
	sta HPOSP0+4
	lda GBASE
	clc
	adc #1
	and #15
	sta GBASE

	lda SKSTAT		; the answer, polled once a frame
	and #4
	bne gt_c
	lda KBCODE
	and #$3F
	cmp #$2B		; Y
	beq gt_yes
	cmp #$23		; N
	beq gt_no
gt_c	lda CONSOL
	lsr
	bcc gt_yes
	lsr
	bcc gt_no
	jmp gt_lp
gt_no	lda #1
	sta BADMASK+7
gt_yes	lda #0			; the sprites off again
	sta GRACTL
	sta PRIOR
	ldx #$11		; positions, sizes, graphics latches
gs_off	sta HPOSP0,x
	dex
	bpl gs_off
	lda #$22
	sta DMACTL
	jsr waitrel
	jmp tend

; gletters: the five letters, from the ROM font, A bytes into the zone
; (0-8: their top at row 19 to row 21), the rest of the zone clear.
gletters sta CNT
	ldx #4
gl_let	lda gdestl,x		; the zone's top in this player or the missiles
	sta SPTR
	lda gdesth,x
	sta SPTR+1
	ldy #15
	lda #0
gl_clr	sta (SPTR),y
	dey
	bpl gl_clr
	lda SPTR		; (no page crossing: the zone is within the 128)
	clc
	adc CNT
	sta SPTR
	lda #0
	sta PTR+1
	lda gcodes,x		; font + code*8
	asl
	rol PTR+1
	asl
	rol PTR+1
	asl
	rol PTR+1
	sta PTR
	lda PTR+1
	ora #$E0
	sta PTR+1
	ldy #7
gl_cp	lda (PTR),y
	sta (SPTR),y
	dey
	bpl gl_cp
	dex
	bpl gl_let
	rts

gcodes	.byte $21, $34, $21, $32, $29	; A T A R I (screen codes)
gdestl	.byte <[GPM*$100+$200+GY], <[GPM*$100+$280+GY], <[GPM*$100+$300+GY]
	.byte <[GPM*$100+$380+GY], <[GPM*$100+$180+GY]
gdesth	.byte >[GPM*$100+$200+GY], >[GPM*$100+$280+GY], >[GPM*$100+$300+GY]
	.byte >[GPM*$100+$380+GY], >[GPM*$100+$180+GY]
	.ifdef ROM
gsine	.byte 4, 4, 5, 5, 6, 6, 6, 7, 7, 7, 7, 8, 8, 8, 8, 8	; 4 + 4 sin
	.byte 8, 8, 8, 8, 8, 8, 7, 7, 7, 7, 6, 6, 6, 5, 5, 4
	.byte 4, 4, 3, 3, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 3, 3, 4
	.endif

s_glum	dta d'LUMINANCE: 8 EVEN STEPS, BLACK TO WHITE',$FF
s_ghue	dta d'HUES: 16 COLORS. BELOW: MOVING ATARI',$FF
s_gq	dta d'LOOKS RIGHT? Y/START=YES, N/SELECT=NO',$FF
s_vpal	dta d'VIDEO: PAL ',$FF
s_vntsc	dta d'VIDEO: NTSC',$FF
