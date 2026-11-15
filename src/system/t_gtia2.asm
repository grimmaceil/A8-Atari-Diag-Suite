; Test 7, page 2 (item 2): the display modes. Included by t_gtia.asm, or
; on the 8K sound and video tape the tape's part two (gpart2.asm), which
; uses part one's library and its gwave and gans (common.asm).
; ---------------------------------------------------------------------------
; Page 2, item 2: the display modes, a band of each on one screen, with its
; own display list in the screen block:
;   ANTIC 6, 7: big color text (6 white, 7 green)
;   ANTIC 8, A, B, D, F: bitmaps, each with the sine wave drawn in it a byte
;     wide (gwaves), so a mode that fetches or shows its bytes wrong breaks
;     the wave
;   GTIA 9, 10, 11: one line of 16 values (5 pixels each) shown 8 times in
;     each, PRIOR set as the beam reaches the band: 16 luminances, 9 colors,
;     16 hues
;   ANTIC fine scroll: a text line moved sideways by HSCROL, and the question
;     moved up and down by VSCROL, both along the wave
GM8	= $078			; the bands' bytes in the screen block (rows 0-2
GMA	= GM8+2*10		; are text at their usual place)
GMB	= GMA+2*20
GMD	= GMB+4*20
GMF	= GMD+4*40
GMG	= GMF+8*40		; the GTIA line
GMH	= GMG+40		; the HSCROL line: 48 bytes (a wide fetch)
GMV	= GMH+48		; the VSCROL region: the question, a blank line
GMDL	= GMV+80		; the display list (107 bytes)
GLINE	= 120			; the scan line of the first GTIA band
GM_C	= TSCR+$03		; gwaves: the column
GM_P	= TSCR+$04		; gwaves: the wave's phase
GM_X	= TSCR+$05		; gwaves: the band

gmodes	jsr scr_on		; a clean block, then ANTIC off while it fills
	lda #0
	sta DMACTL
	lda #<s_t7m
	ldy #>s_t7m
	jsr header
	PRINT 1, 0, s_gml
	PRINT 2, 0, s_gm6	; ANTIC 6's 20 bytes, then ANTIC 7's
	PRINT 2, 20, s_gm7
	lda #<$050		; their colors: bits 6-7 of each character
	sta PTR
	lda SCRPG
	sta PTR+1
	ldy #39
gm_col	lda (PTR),y
	ora #$40		; 6: COLPF1
	cpy #20
	bcc gm_c6
	ora #$80		; 7: COLPF3
gm_c6	sta (PTR),y
	dey
	bpl gm_col
	jsr gwaves		; the bitmaps' waves
	lda #<GMG		; the GTIA line
	sta PTR
	lda SCRPG
	clc
	adc #>GMG
	sta PTR+1
	ldy #39
gm_g	lda gmramp,y
	sta (PTR),y
	dey
	bpl gm_g
	lda #<[GMH+6]		; the HSCROL line's text, and the question
	ldx #>[GMH+6]
	jsr gat
	lda #<s_ghs
	ldy #>s_ghs
	jsr puts
	lda #<GMV
	ldx #>GMV
	jsr gat
	lda #<s_gq
	ldy #>s_gq
	jsr puts
	ldx #7			; the colors: COLPM0-3 (GTIA 10), COLPF0-3
gm_cl	lda gmcols,x
	sta COLPM0,x
	dex
	bpl gm_cl
	lda #$86		; COLBK: GTIA 9's hue, GTIA 11's luminance
	sta COLBK
	jsr gdlist		; the display list, and ANTIC on
	lda #0
	sta GPX
	jsr waitrel
gm_lp	lda VCOUNT		; GTIA 9, 10, 11: PRIOR as the beam reaches each
	cmp #GLINE/2-1		; band, 8 lines each (VCOUNT counts line pairs:
	bne gm_lp		; from the pair before the band, one WSYNC more)
	sta WSYNC
	ldx #0
gm_pr	lda gmprior,x
	sta WSYNC
	sta PRIOR
	ldy #7
gm_pw	sta WSYNC
	dey
	bne gm_pw
	inx
	cpx #4
	bne gm_pr
gm_w	lda VCOUNT		; past the VSCROL region: the scroll registers
	cmp #82			; for the next frame, along the wave
	bcc gm_w
	inc GPX
	lda GPX
	jsr gwave
	sta HSCROL		; sideways, 0-8 color clocks
	lda GPX
	clc
	adc #16
	jsr gwave
	and #7
	sta VSCROL		; up and down, 0-7 lines
	jsr gans
	beq gm_lp
	cmp #2
	bne gm_end
	lda #2			; no: item 2
	ora BADMASK+7
	sta BADMASK+7
gm_end	lda #0
	sta PRIOR
	sta HSCROL
	sta VSCROL
	jsr waitrel
	lda #<s_t7
	ldy #>s_t7
	jsr tpage		; the test's page again, for the result
	jmp tend

; gat: CUR = the screen block + X:A, for puts.
gat	sta CUR
	txa
	clc
	adc SCRPG
	sta CUR+1
	rts

; gwaves: in each bitmap band the wave, a byte (gm_pat) a column, in the
; line the wave reaches there (gwave, shifted to the band's height).
gwaves	ldx #4
gw_bd	stx GM_X
	lda #0
	sta GM_C
	sta GM_P
gw_col	ldx GM_X
	lda GM_P
	jsr gwave		; 0-8
	ldy gm_s,x
	beq gw_ns
gw_sh	lsr
	dey
	bne gw_sh
gw_ns	cmp gm_h,x		; at most the band's last line
	bcc gw_ok
	lda gm_h,x
	sbc #1
gw_ok	tay			; Y = the line
	lda gm_lo,x		; PTR = the band + the column
	clc
	adc GM_C
	sta PTR
	lda gm_hi,x
	adc SCRPG
	sta PTR+1
gw_ln	dey			; + a line's bytes, Y times
	bmi gw_put
	lda PTR
	clc
	adc gm_bpl,x
	sta PTR
	bcc gw_ln
	inc PTR+1
	bcs gw_ln
gw_put	ldy #0
	lda gm_pat,x
	sta (PTR),y
	lda GM_P
	clc
	adc gm_k,x
	sta GM_P
	inc GM_C
	lda GM_C
	cmp gm_bpl,x
	bne gw_col
	ldx GM_X
	dex
	bpl gw_bd
	rts

; gdlist: the display list at GMDL, then ANTIC on it.
gdlist	lda #<GMDL
	sta PTR
	lda SCRPG
	clc
	adc #>GMDL
	sta PTR+1
	ldy #0
gd_t	lda gdl_t,y
	sta (PTR),y
	iny
	cpy #GDLT_N
	bne gd_t
	ldx #24			; the GTIA bands: the GTIA line, 24 times
gd_g	lda #$4F		; (mode F, LMS)
	jsr gdput
	lda #<GMG
	jsr gdput
	lda SCRPG
	clc
	adc #>GMG
	jsr gdput
	dex
	bne gd_g
	lda #$12		; the HSCROL line (mode 2, bit 4)
	jsr gdput
	lda #$22		; the VSCROL region (bit 5): the question, and
	jsr gdput
	lda #$02		; the region's last line
	jsr gdput
	lda #$41		; back to the top
	jsr gdput
	lda PTR
	jsr gdput
	lda PTR+1
	jsr gdput
	ldy #5			; the header's LMS: the block
	lda SCRPG
	sta (PTR),y
	lda PTR
	sta DLISTL
	lda PTR+1
	sta DLISTH
	lda #$22
	sta DMACTL
	rts
gdput	sta (PTR),y
	iny
	rts

gdl_t	.byte $70, $70, $70, $42, 0, 0	; 24 blank lines; the header (LMS)
	.byte $02, $06, $07, $08, $08, $0A, $0A	; the legend; 6; 7; 8 x2; A x2
	.byte $0B, $0B, $0B, $0B, $0D, $0D, $0D, $0D	; B x4; D x4
	.byte $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F	; F x8
GDLT_N	= *-gdl_t
	.if GMDL+GDLT_N+72+9>$400
	.error "the modes page's display list runs out of the screen block"
	.endif
gm_lo	.byte <GM8, <GMA, <GMB, <GMD, <GMF
gm_hi	.byte >GM8, >GMA, >GMB, >GMD, >GMF
gm_bpl	.byte 10, 20, 20, 40, 40		; bytes a line
gm_s	.byte 2, 2, 1, 1, 0			; the wave (0-8) shifted right
gm_h	.byte 2, 2, 4, 4, 8			; to the band's lines
gm_k	.byte 6, 3, 3, 2, 2			; the phase a byte: a wave across
gm_pat	.byte $55, $AA, $FF, $55, $FF		; 8, A, D: color 1/2; B, F: 1 bit
gmcols	.byte $28, $58, $88, $B8, $36, C_TEXTLUM, C_TEXTBG, $C8
gmprior	.byte $40, $80, $C0, $00		; GTIA 9, 10, 11, then off
gmramp	.rept 40				; 16 values, 5 pixels each
	.byte [[[#*2]/5]<<4]|[[#*2+1]/5]
	.endr
s_t7m	dta d'7 GTIA: MODES',$FF
s_gml	dta d'ANTIC 6 7 8 A B D F  GTIA 9 10 11',$FF
s_gm6	dta d' ANTIC 6',$FF
s_gm7	dta d' ANTIC 7',$FF
s_ghs	dta d'ANTIC HSCROL: THIS LINE MOVES',$FF
