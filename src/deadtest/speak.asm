; A word bank (the 8 Mbit cartridge's spoken results): one word
; (tools/mkwords.py: 4-bit samples, two to a byte, high first, WORDPG pages
; at WDATA), played with no RAM: POKEY voice 1 in volume-only mode (AUDC1 bit
; 4) puts each sample's level straight out, one every two scan lines
; (WSYNC, 7.85 kHz), the screen off (ANTIC's DMA would make the samples
; come unevenly). Without a pointer every page needs its own loop. The show
; bank sends Y (the phrase's next node) and gets it back. START or fire
; stops the word at once: PBCTL bit 1 says so, and the phrase ends (Y = 1),
; so a press while the fault is spoken still goes on.
WDATA	= $A800			; the word: up to $BC00 (20 pages)

	.if WDATA+WORDPG*$100>FONTAT
	.error "the word runs into the font"
	.endif

play	lda #0
	sta DMACTL
	sta AUDCTL
	lda #$18		; the middle: silence
	sta AUDC1
	.rept WORDPG
	ldx #0
@	lda WDATA+$100*.r,x
	lsr
	lsr
	lsr
	lsr
	ora #$10
	sta WSYNC
	sta WSYNC
	sta AUDC1
	lda WDATA+$100*.r,x
	and #$0F
	ora #$10
	sta WSYNC
	sta WSYNC
	sta AUDC1
	lda CONSOL
	and #1
	bne *+5
	jmp sp_key
	lda TRIG0
	bne *+5
	jmp sp_key
	inx
	bne @-
	.endr
sp_back	lda #0
	sta AUDC1
	ldx #DEADBK+1		; back to the show bank, Y as it came
	jmp XBANK
sp_key	lda PBCTL		; START or fire: stop, say so, end the phrase
	ora #2
	sta PBCTL
	ldy #1
	jmp sp_back

	.if *>WDATA
	.error "the player runs into the word"
	.endif
	org WDATA
	ins '../../build/word.bin'
