; Test 7, page 2 (item 2): the display modes (included by t_gtia.asm).
; ---------------------------------------------------------------------------
; Page 2, item 2: the display modes, one screen, each with a line of text
; above it saying what it is:
;   ANTIC 6, 7: big color text (6 wide and white, 7 tall and green)
;   ANTIC 8, A, B, D, F: bitmaps, each filled with even bars of its colors
;     (4-color modes: black, red, white, blue; 2-color: two-pixel stripes),
;     so each shows its pixel size and colors, coarse to fine
;   GTIA 9, 10, 11: one line of 16 values (5 pixels each), 8 times in each
;     band: 16 shades of blue, 9 colors, 16 hues. PRIOR and COLBK are set as
;     the beam reaches the blank line before each band.
;   ANTIC fine scroll: a text line sliding sideways (HSCROL) and one moving
;     up and down (VSCROL, in the middle of a 3-line region, so it is never
;     cut off), along the wave. The question stays still at the bottom.
; The text and bitmaps are in the screen block; the display list (gdlist,
; from gdl_t) is at GMDL, in the P/M block's unused bytes (sprites are off).
GM6	= $028			; ANTIC 6's 20 bytes, then ANTIC 7's
GL8	= $050			; each bitmap: its label line, then one row of its
GD8	= GL8+40		; bytes (the display list shows that row again for
GLA	= GD8+10		; each of the band's rows)
GDA	= GLA+40
GLB	= GDA+20
GDB	= GLB+40
GLD	= GDB+20
GDD	= GLD+40
GLF	= GDD+40
GDF	= GLF+40
GMC	= GDF+40		; the GTIA caption
GMG	= GMC+40		; the GTIA line
GMH	= GMG+40		; the HSCROL line: 48 bytes (a wide fetch)
GMV0	= GMH+48		; a blank line (the VSCROL region's first and last)
GMV	= GMV0+40		; the VSCROL line
GMQ	= GMV+40		; the question
	.if GMQ+40>SCRDL
	.error "the modes page runs into the screen block's display list"
	.endif
GMDL	= $0480			; the display list (P/M block $0400: $0480-$057F)
GLINE	= 160			; the scan line of the blank line before GTIA 9
GLAST	= 222			; the scan line after the question
GM_C	= TSCR+$03		; gdlist: the last LMS line (op, address)
GM_P	= TSCR+$04
GM_X	= TSCR+$05
GM_N	= TSCR+$06		; gdlist: repeats left; gmodes: the text index

gmodes	jsr scr_on		; a clean block, then ANTIC off while it fills
	lda #0
	sta DMACTL
	lda #<s_t7m
	ldy #>s_t7m
	jsr header
	ldx #0			; the text: each line at its place
gm_tx	stx GM_N
	lda gm_txt,x
	ldy gm_txt+1,x
	jsr gat
	ldx GM_N
	lda gm_txt+2,x
	ldy gm_txt+3,x
	jsr puts
	ldx GM_N
	inx
	inx
	inx
	inx
	cpx #GMTXT_N
	bne gm_tx
	lda #<GM6		; ANTIC 6 and 7's colors: bits 6-7 of each
	sta PTR			; character
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
	ldx #4			; the bitmaps' rows
gm_fb	lda gm_bl,x
	sta PTR
	lda gm_bh,x
	clc
	adc SCRPG
	sta PTR+1
	ldy gm_bn,x
	dey
	lda gm_bp,x
gm_fl	sta (PTR),y
	dey
	bpl gm_fl
	dex
	bpl gm_fb
	lda #<GMG		; the GTIA line
	ldy #>GMG
	jsr gat
	ldy #39
gm_g	lda gmramp,y
	sta (CUR),y
	dey
	bpl gm_g
	ldx #7			; the colors: COLPM0-3 (GTIA 10), COLPF0-3
gm_cl	lda gmcols,x
	sta COLPM0,x
	dex
	bpl gm_cl
	lda #0
	sta COLBK
	jsr gdlist		; the display list, and ANTIC on
	lda #0
	sta GPX
	jsr waitrel
gm_lp	lda VCOUNT		; GTIA 9, 10, 11: PRIOR and COLBK on the blank
	cmp #GLINE/2-1		; line before each band, then off on the one
	bne gm_lp		; after (VCOUNT counts line pairs: from the pair
	sta WSYNC		; before, one WSYNC more)
	ldx #0
gm_pr	lda gmprior,x
	ldy gmbk,x
	sta WSYNC
	sta PRIOR
	sty COLBK
	ldy #8
gm_pw	sta WSYNC
	dey
	bne gm_pw
	inx
	cpx #4
	bne gm_pr
gm_w	lda VCOUNT		; past the question: the scroll registers for the
	cmp #GLAST/2		; next frame, along the wave
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

; gat: CUR = the screen block + Y:A, for puts.
gat	sta CUR
	tya
	clc
	adc SCRPG
	sta CUR+1
	rts

; gdlist: the display list at GMDL from gdl_t, then ANTIC on it. In gdl_t a
; mode line with LMS ($40 set, mode not 0) is followed by its address in the
; screen block (the block's page is added here); $80+n is the last LMS line
; n times more.
gdlist	lda #<GMDL
	sta PTR
	lda #>GMDL
	sta PTR+1
	ldx #0
	ldy #0
gd_lp	lda gdl_t,x
	inx
	cmp #$80
	bcs gd_rep
	jsr gdput
	sta GM_C
	and #$0F		; a blank line ($x0, $70 too: its bit 6 is part
	beq gd_nx		; of the count, not an LMS) has no address
	lda GM_C
	and #$40
	beq gd_nx
	lda gdl_t,x
	sta GM_P
	jsr gdput
	lda gdl_t+1,x
	clc
	adc SCRPG
	sta GM_X
	jsr gdput
	inx
	inx
gd_nx	cpx #GDLT_N
	bne gd_lp
	lda #$41		; back to the top
	jsr gdput
	lda #<GMDL
	jsr gdput
	lda #>GMDL
	jsr gdput
	lda #<GMDL
	sta DLISTL
	lda #>GMDL
	sta DLISTH
	lda #$22
	sta DMACTL
	rts
gd_rep	and #$3F
	sta GM_N
gd_r1	lda GM_C
	jsr gdput
	lda GM_P
	jsr gdput
	lda GM_X
	jsr gdput
	dec GM_N
	bne gd_r1
	beq gd_nx
gdput	sta (PTR),y
	iny
	rts

gdl_t	.byte $70, $70, $70
	.byte $42, <0, >0		; the title
	.byte $06, $07			; ANTIC 6, 7 (the bytes after the title)
	.byte $02, $08, $48, <GD8, >GD8	; 8: its label, 2 rows
	.byte $02, $0A, $4A, <GDA, >GDA	; A: 2 rows
	.byte $02, $0B, $4B, <GDB, >GDB, $82	; B: 4 rows
	.byte $02, $0D, $4D, <GDD, >GDD, $82	; D: 4 rows
	.byte $02, $0F, $4F, <GDF, >GDF, $86	; F: 8 rows
	.byte $02			; the GTIA caption
	.byte $00, $4F, <GMG, >GMG, $87	; GTIA 9: a blank line, 8 rows
	.byte $00, $4F, <GMG, >GMG, $87	; GTIA 10
	.byte $00, $4F, <GMG, >GMG, $87	; GTIA 11
	.byte $00, $12			; the HSCROL line
	.byte $62, <GMV0, >GMV0, $22	; the VSCROL region: blank, the line,
	.byte $42, <GMV0, >GMV0		; blank (the last: no VSCROL bit)
	.byte $42, <GMQ, >GMQ		; the question
GDLT_N	= *-gdl_t			; (it makes 166 bytes: $0480-$0525)
gm_txt	.word GM6, s_gm6, GM6+20, s_gm7, GL8+1, s_gl8, GLA+1, s_gla
	.word GLB+1, s_glb, GLD+1, s_gld, GLF+1, s_glf, GMC+2, s_gmc
	.word GMH+8, s_ghs, GMV+2, s_gvs, GMQ+1, s_gq
GMTXT_N	= *-gm_txt
gm_bl	.byte <GD8, <GDA, <GDB, <GDD, <GDF
gm_bh	.byte >GD8, >GDA, >GDB, >GDD, >GDF
gm_bn	.byte 10, 20, 20, 40, 40		; bytes a row
gm_bp	.byte $1B, $1B, $33, $1B, $33		; 4 colors: 0 1 2 3; 2 colors: stripes
gmcols	.byte $28, $58, $88, $B8, $36, C_TEXTLUM, $84, $C8
gmprior	.byte $40, $80, $C0, $00		; GTIA 9, 10, 11, then off
gmbk	.byte $80, $00, $06, $00		; COLBK: 9's hue, 10's color 8, 11's
gmramp	.rept 40				; luminance; 16 values, 5 pixels each
	.byte [[[#*2]/5]<<4]|[[#*2+1]/5]
	.endr
s_t7m	dta d'7 VIDEO MODES',$FF
s_gm6	dta d' ANTIC 6: WIDE TEXT',$FF
s_gm7	dta d' ANTIC 7: TALL TEXT',$FF
s_gl8	dta d'ANTIC 8: 40 WIDE, 4 COLORS',$FF
s_gla	dta d'ANTIC A: 80 WIDE, 4 COLORS',$FF
s_glb	dta d'ANTIC B: 160 WIDE, 2 COLORS',$FF
s_gld	dta d'ANTIC D: 160 WIDE, 4 COLORS',$FF
s_glf	dta d'ANTIC F: 320 WIDE, 1 COLOR',$FF
s_gmc	dta d'GTIA 9: SHADES  10: COLORS  11: HUES',$FF
s_ghs	dta d'THIS LINE SLIDES SIDEWAYS: HSCROL',$FF
s_gvs	dta d'THIS LINE MOVES UP AND DOWN: VSCROL',$FF
