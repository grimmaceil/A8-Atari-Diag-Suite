; Text screen: 40x24 GRAPHICS 0 in one 1K block starting at page SCRPG.
; Screen memory is $000-$3BF of the block and the display list sits at $3C0,
; so the block holds both and nothing crosses a 1K or 4K boundary. The font
; is the OS ROM's ($E000). Needs the stack and zero page.

; (C_TEXTBG, C_TEXTLUM, SCRDL and the PRINT macro: defs.asm.)

; scr_on: clear the block, build the display list, start ANTIC. Also used
; to clear the screen.
scr_on	lda #0
	sta DMACTL
	sta CUR
	lda SCRPG
	sta CUR+1
	ldx #4
	ldy #0
	tya
so_clr	sta (CUR),y
	iny
	bne so_clr
	inc CUR+1
	dex
	bne so_clr

	lda #<SCRDL		; CUR = display list
	sta CUR
	lda SCRPG
	clc
	adc #>SCRDL
	sta CUR+1
	ldy #0
	lda #$70		; 24 blank lines
	sta (CUR),y
	iny
	sta (CUR),y
	iny
	sta (CUR),y
	iny
	lda #$42		; mode 2 + LMS
	sta (CUR),y
	iny
	lda #0
	sta (CUR),y
	iny
	lda SCRPG
	sta (CUR),y
	iny
	lda #$02		; 23 more mode 2 lines
	ldx #23
so_dl	sta (CUR),y
	iny
	dex
	bne so_dl
	lda #$41		; JVB back to the start
	sta (CUR),y
	iny
	lda CUR
	sta (CUR),y
	iny
	lda CUR+1
	sta (CUR),y

	lda CUR
	sta DLISTL
	lda CUR+1
	sta DLISTH
	lda #$E0
	sta CHBASE
	lda #2
	sta CHACTL
	lda #C_TEXTBG
	sta COLPF2
	lda #C_TEXTLUM
	sta COLPF1
	lda #$22		; normal playfield, display list DMA
	sta DMACTL
	sta SCRON
	lda VIDEOOK		; (report.asm)
	sta QUIET
	rts

; scr_off: back to abstract mode (border color only).
scr_off	lda #0
	sta DMACTL
	sta SCRON
	sta QUIET
	rts

; at: cursor to row A, column X: SCRPG*256 + A*40 + X, the row times 40
; worked out (A*5, then *8), not looked up. Keeps X; Y = 0.
at	sta CUR+1
	asl
	asl
	adc CUR+1		; A*5 (the ASLs left C clear: A < 24)
	ldy #0
	sty CUR+1
	asl
	rol CUR+1
	asl
	rol CUR+1
	asl
	rol CUR+1		; CUR+1, A = A*40
	sta CUR
	txa
	clc
	adc CUR
	sta CUR
	lda CUR+1
	adc SCRPG
	sta CUR+1
	rts

; puts: print the $FF-terminated screen-code string at A (lo) / Y (hi).
puts	sta SPTR
	sty SPTR+1
	ldy #0
ps_lp	lda (SPTR),y
	cmp #$FF
	beq ps_x
	jsr putc
	iny
	bne ps_lp
ps_x	rts

; putc: screen code A at the cursor, advance. Keeps X and Y. Without a
; screen block (SCRPG = 0) it writes nothing: the cursor would be in page 0.
putc	ora INV
	sty PCY
	ldy SCRPG
	beq pc2_ns
	ldy #0
	sta (CUR),y
pc2_ns	ldy PCY
	inc CUR
	bne pc2_x
	inc CUR+1
pc2_x	rts

; puthex: A as two hex digits. Keeps X and Y.
puthex	pha
	lsr
	lsr
	lsr
	lsr
	jsr ph_dig
	pla
	and #$0F
ph_dig	cmp #10
	bcc ph_num
	adc #6			; carry is set: +7, so 10 -> 'A'
ph_num	adc #$10		; screen code of '0'
	jmp putc

; putdec: DVAL as decimal, no leading zeros.
putdec	lda #1
	sta LEAD
	ldx #0
pd_pow	ldy #0			; digit = how many times the power fits
pd_sub	lda DVAL
	sec
	sbc pow10lo,x
	pha
	lda DVAL+1
	sbc pow10hi,x
	bcc pd_dig
	sta DVAL+1
	pla
	sta DVAL
	iny
	bne pd_sub
pd_dig	pla
	tya
	bne pd_out
	cpx #4			; the last digit prints even if 0
	beq pd_out
	lda LEAD
	bne pd_next
	tya
pd_out	clc
	adc #$10
	jsr putc
	lda #0
	sta LEAD
pd_next	inx
	cpx #5
	bne pd_pow
	rts

pow10lo	.byte <10000,<1000,<100,<10,<1
pow10hi	.byte >10000,>1000,>100,>10,>1


; header: the inverse title bar on row 0: s_hpre (the tape's prefix), the
; title at A/Y, inverse spaces to the end of the row, where the version
; goes (build.py's VMAJ.VMIN, as in the file's name) if there is room.
header	pha
	tya
	pha
	lda #$80
	sta INV
	lda #0
	tax
	jsr at
	lda #<s_hpre
	ldy #>s_hpre
	jsr puts
	pla
	tay
	pla
	jsr puts
hd_pad	lda CUR			; the block is page aligned: CUR lo = column on row 0
	cmp #40-VERLEN
	beq hd_ver
	bcs hd_fill
	lda #0
	jsr putc
	jmp hd_pad
hd_ver	lda #<s_ver
	ldy #>s_ver
	jsr puts
hd_fill	lda CUR
	cmp #40
	bcs hd_x
	lda #0
	jsr putc
	jmp hd_fill
hd_x	lda #0
	sta INV
	rts
	.if VMAJ>9 .or VMIN>9
	.error 'the version is one digit, a point, one digit'
	.endif
s_ver	dta d'V',[VMAJ+$10],d'.',[VMIN+$10],d' ',$FF
VERLEN	= 5

; clrrow: blank row A.
clrrow	ldx #0
	jsr at
	ldx #40
	lda #0
cr_lp	jsr putc
	dex
	bne cr_lp
	rts

	icl '../common/name.asm'	; s_hpre: the program's name
