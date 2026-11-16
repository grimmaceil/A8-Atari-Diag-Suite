; undercart: the 8K of RAM the cartridge sits over, $A000-$BFFF. With the
; cartridge in, that RAM is switched off, so the machine looks 8K smaller
; (48K shows as 40K, as with a BASIC cartridge). An AtariMax can switch
; itself off ($D510) and on again (a bank select), so a loop in low RAM
; (ucsrc, copied to UCAT: the code in ROM is gone meanwhile) switches it
; off, tests the 8K and switches bank 0 back in. Only when the RAM reaches
; the cartridge (RAMTOP = $A000): a smaller machine has nothing there.
;
; ucsize, at every start (before S or the way back from the long memory
; test can skip the RAM test): only a look whether there is RAM, and if so
; RAMK gets the 8K, so the machine line shows the real size (48K, not 40K).
; undercart, the RAM test's part: the test: $00 and $55, each written
; everywhere, read back and inverted, read back again; then every byte gets
; (address low EOR address high), to catch address faults. Bad bits go to
; bank 3.
; Interrupts are off, so the XL OS never sees the cartridge go (TRIG3).
UCAT	= $0600			; low RAM (tested)
UCERR	= $8A			; bad bits found
UCPAT	= $8B			; the pattern

ucsize	ldx #0			; X 0: only the look
	jsr ucrun
	beq uc_x
	lda RAMK
	clc
	adc #8
	sta RAMK
	rts

; ucrun: X (0 look, 1 test) to the copy at UCAT, which runs with the
; cartridge off. Z set: no RAM there (or the RAM ends below the cartridge).
ucrun	lda RAMTOP
	cmp #$A0
	bne uc_n
	txa
	pha
	ldx #0
uc_cp	lda ucsrc,x
	sta UCAT,x
	inx
	cpx #uc_len
	bne uc_cp
	pla
	tax
	jsr UCAT
	txa			; X = 0: no RAM there
	rts
uc_n	lda #0
	rts

undercart ldx #1
	jsr ucrun
	beq uc_x
	lda UCERR
	beq uc_x
	ora BADMASK+3
	sta BADMASK+3
	lda UCERR
	ora MBAD+3
	sta MBAD+3
	lda ECNTLO+3
	ora ECNTHI+3
	bne uc_cnt
	sta EADRLO+3		; (0) the first one: the area, as the detail
	sta EWROTE+3
	lda #$A0
	sta EADRHI+3
	lda UCERR
	sta EREAD+3
uc_cnt	inc ECNTLO+3
	bne uc_x
	inc ECNTHI+3
uc_x	rts

; ucsrc: runs at UCAT (branches, and jumps by their UCAT address). X 0:
; only the look, 1: the test too. Returns X = 1 if there is RAM (UCERR =
; its bad bits), 0 if not.
ucsrc	sta $D510		; the cartridge off
	ldy #0
	sty UCERR
	sty PTR
	lda #$A0
	sta PTR+1
	lda #$A5		; RAM at all? (An empty bus reads the same for
	sta (PTR),y		; both; RAM, even with bad bits, doesn't.)
	lda (PTR),y
	sta UCPAT
	lda #$5A
	sta (PTR),y
	lda (PTR),y
	eor UCPAT
	bne uc_ram
	jmp UCAT+uc_none-ucsrc
uc_ram	txa			; only the look: there is RAM
	bne uc_go
	jmp UCAT+uc_yes-ucsrc
uc_go	tya			; (0: the first pattern)
uc_p	sta UCPAT
	lda #$A0
	sta PTR+1
uc_f	lda UCPAT		; write the pattern
	sta (PTR),y
	iny
	bne uc_f
	inc PTR+1
	lda PTR+1
	cmp #$C0
	bne uc_f
	lda #$A0
	sta PTR+1
uc_c	lda (PTR),y		; read it, write its inverse
	eor UCPAT
	ora UCERR
	sta UCERR
	lda UCPAT
	eor #$FF
	sta (PTR),y
	iny
	bne uc_c
	inc PTR+1
	lda PTR+1
	cmp #$C0
	bne uc_c
	lda #$A0
	sta PTR+1
uc_d	lda (PTR),y		; read the inverse
	eor UCPAT
	eor #$FF
	ora UCERR
	sta UCERR
	iny
	bne uc_d
	inc PTR+1
	lda PTR+1
	cmp #$C0
	bne uc_d
	lda UCPAT
	bne uc_adr
	lda #$55
	jmp UCAT+uc_p-ucsrc	; (too far for a branch: by its address at UCAT)
uc_adr	lda #$A0		; the address in every byte
	sta PTR+1
uc_w	tya
	eor PTR+1
	sta (PTR),y
	iny
	bne uc_w
	inc PTR+1
	lda PTR+1
	cmp #$C0
	bne uc_w
	lda #$A0
	sta PTR+1
uc_v	tya
	eor PTR+1
	eor (PTR),y
	ora UCERR
	sta UCERR
	iny
	bne uc_v
	inc PTR+1
	lda PTR+1
	cmp #$C0
	bne uc_v
uc_yes	ldx #1
	bne uc_on
uc_none	ldx #0
uc_on	sta $D500		; bank 0 back in
	rts
uc_len	= *-ucsrc
