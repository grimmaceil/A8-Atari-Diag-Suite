; Test 6: POKEY.
;   item 1: timer 1's interrupt doesn't come (read in IRQST; the CPU masks it)
;   item 2: RANDOM doesn't change
;   items 3-6: voice 1-4 not heard: a rising scale of pure tones, then
;              noise (a hiss: the 17-bit polynomial counter, which the pure
;              tones don't use), over and over (common.asm's ynnote)
VOICE	= TSCR+$00		; voice being played (0-3)

t_pok	lda #6
	sta TEST
	lda #<s_tpok
	ldy #>s_tpok
	jsr tpage
	lda #0			; timer 1: 64 kHz / 256, about 4 ms
	sta AUDCTL
	sta IRQEN
	lda #$FF
	sta AUDF1
	lda #AUD_OFF
	sta AUDC1
	lda #1
	sta IRQEN
	sta STIMER
	ldx #0			; give it ~32 ms
	ldy #1
pk_irq	lda IRQST
	lsr
	bcc pk_ok
	sta WSYNC
	dex
	bne pk_irq
	dey
	bpl pk_irq
	lda #1
	sta BADMASK+6
pk_ok	lda #0
	sta IRQEN

	lda RANDOM		; RANDOM: at least 8 changes in 16 reads
	ldx #16
	ldy #0
pk_rnd	sta WSYNC
	cmp RANDOM
	beq pk_rs
	iny
	lda RANDOM
pk_rs	dex
	bne pk_rnd
	cpy #8
	bcs pk_v
	lda #2
	ora BADMASK+6
	sta BADMASK+6

pk_v	lda DISPOK
	beq pk_v0
	PRINT 5, 0, s_pk1	; the voices, one at a time, by ear
pk_v0	lda #0
	sta VOICE
pk_vl	lda DISPOK
	beq pk_play
	lda #7
	jsr clrrow
	PRINT 7, 0, s_voice
	lda VOICE
	clc
	adc #$11
	jsr putc
	lda #<s_voic2
	ldy #>s_voic2
	jsr puts
	PRINT 8, 0, s_heard
pk_play	lda VOICE		; the voice, over and over, until the answer
	asl
	sta YNV
	lda #1
	sta YNSND
	jsr yesno
	bcs pk_heard
	ldx VOICE		; items 3-6
	lda pkbit,x
	ora BADMASK+6
	sta BADMASK+6
pk_heard inc VOICE
	lda VOICE
	cmp #4
	beq pk_end
	jmp pk_vl
pk_end
	.ifdef SAMPLED		; and sampled sound (cart/hello.asm)
	jsr hello
	.endif
	jmp tend
pkbit	.byte 4, 8, 16, 32

s_pk1	dta d'TIMER AND RANDOM CHECKED. NOW BY EAR:',$FF
s_voice	dta d'VOICE ',$FF
s_voic2	dta d': A SCALE, THEN A HISS',$FF
