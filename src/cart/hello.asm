; hello: sampled sound. POKEY has no sample player: a voice set to "volume
; only" (AUDC bit 4) puts its 4-bit volume straight on the output, so
; writing a new volume at a steady rate plays a recording, 16 levels. Two
; voices played together add up: 31 levels, clearer. The console speaker
; (GTIA) is one bit. The word plays seven times:
;   1-4  on voice 1, 2, 3, 4: 4 bits (the sample halved)
;   5    on the console speaker: 1 bit (rougher)
;   6-7  on voices 1+2, then 3+4: 5 bits (clearer)
; One byte a sample, 0-30 (tools/mkhello.py), a sample every scan line
; (15.7 kHz). The cartridge (ROM): from a bank of its own (HELLOBK), so the
; player runs from low RAM while that bank is in. In RAM (the disk file,
; the 16k hello tape): the same recording, in the image.
;
; Then the question; no answer in about 3 s plays them all again. Not
; heard: POKEY item 7. An answer counts while it plays too (looked at after
; each word): Y or N through POKEY's keyboard latch, START through SLATCH
; (report.asm's delay notes it during the pauses), SELECT if still held.
;
; The screen is off while it plays (DMACTL 0): ANTIC takes CPU time on every
; line it draws, which would make the samples come late and unevenly. With
; it off, each sample is written just after a WSYNC, exactly HLINES scan
; lines after the one before.
HPLAY	= $0600			; the player, copied to low RAM
HPN	= $8A			; pages left
HSPK	= $8B			; the speaker's state
HMODE	= $8C			; 0 one voice, 1 the speaker, 2 two voices
HWHO	= TSCR+$08		; which play, 0-6
HLINES	= 1
	.ifdef ROM
HDATA	= $A000			; (bank HELLOBK, HELLOPG pages: build.py)
HPAGES	= HELLOPG
	.elseif .def DISK
HDATA	= HELLOAT		; (the boot disk: a piece of its own, HELLOPG
HPAGES	= HELLOPG		; pages, loaded here by dfetch)
	.else
HDATA	= hl_data
HPAGES	= >[hl_end-hl_data]
	.endif

hello
	.ifdef DISK		; the recording, from the disk: 16K and up (on
	lda RAMTOP		; 8K, item 7 is left out, as on the 8k sound
	cmp #$40		; tape)
	bcs hl_ld
	rts
hl_ld	ldx #P_HELLO
	jsr dfetch
	.endif
	lda DISPOK
	beq hl_cp
	lda #7
	jsr clrrow
	PRINT 7, 0, s_hl1
	lda #8
	jsr clrrow
	PRINT 8, 0, s_hl2
	PRINT 9, 0, s_hl3
hl_cp	ldx #hp_len-1		; the player into low RAM
hl_cl	lda hp_src,x
	sta HPLAY,x
	dex
	bpl hl_cl
	lda #$40		; the keyboard latch (the CPU masks the IRQ)
	sta IRQEN
hl_all	jsr waitrel
	jsr joyc		; (a stick held now doesn't answer)
	lda #0
	sta DMACTL
	sta HWHO
hl_who	ldx HWHO
	lda hl_md,x
	sta HMODE
	lda hl_lo,x		; which voice (or pair)
	sta HPLAY+h1_a-hp_src+1
	sta HPLAY+h2_a-hp_src+1
	clc
	adc #2
	sta HPLAY+h2_b-hp_src+1
	jsr HPLAY
	lda #AUD_OFF		; all quiet, 0.3 s, then the next one
	ldx #6
hl_off	sta AUDC1,x
	dex
	dex
	bpl hl_off
	lda #8
	sta CONSOL
	WAITMS 300
	jsr hl_ans		; answered already?
	bne hl_got
	inc HWHO
	lda HWHO
	cmp #7
	bne hl_who
	lda SCRON		; the screen back ($22 if the text is on)
	sta DMACTL
	ldx #180		; the answer: about 3 s, then all of it again
hl_key	jsr vsync
	jsr hl_ans
	bne hl_got
	dex
	bne hl_key
	jmp hl_all
hl_got	tax
	lda SCRON
	sta DMACTL
	lda #0
	sta IRQEN
	cpx #2
	bne hl_yes
	lda #64			; no: item 7
	ora BADMASK+6
	sta BADMASK+6
hl_yes	jmp waitrel

; hl_ans: A = 1 yes (Y, START, fire), 2 no (N, SELECT, stick down), 0 none
; (Z set). Keeps X.
hl_ans	lda SLATCH		; START during a pause
	bne an_y
	jsr joyc		; a joystick (system/common.asm)
	lsr
	bcs an_y
	lsr
	bcs an_n
	lda CONSOL
	lsr
	bcc an_y		; START
	lsr
	bcc an_n		; SELECT
	lda SKSTAT
	and #4
	beq an_k		; a key held now
	lda IRQST
	and #$40
	bne an_0		; none since the last look
	lda #0			; (the latch: off and on again clears it)
	sta IRQEN
	lda #$40
	sta IRQEN
an_k	lda KBCODE
	and #$3F
	cmp #$2B		; Y
	beq an_y
	cmp #$23		; N
	beq an_n
an_0	lda #0
	rts
an_y	lda #1
	rts
an_n	lda #2
	rts

; The plays: mode (0 one voice, 1 the speaker, 2 two voices) and the AUDC.
hl_md	.byte 0, 0, 0, 0, 1, 2, 2
hl_lo	.byte <AUDC1, <[AUDC1+2], <[AUDC1+4], <[AUDC1+6], 0, <AUDC1, <[AUDC1+4]

; hp_src: copied to HPLAY. Branches only, so it runs there; hello patches
; the voice addresses in the copy.
hp_src
	.ifdef ROM
	sta $D500+HELLOBK	; the recording's bank in
	.endif
	lda #<HDATA
	sta PTR
	lda #>HDATA
	sta PTR+1
	lda #HPAGES
	sta HPN
	ldy #0
	sty HSPK
	lda HMODE
	beq h1_lp
	lsr
	bcc h2_lp
hs_lp	lda (PTR),y		; the speaker: on at 16 and up, off at 14 and
	cmp #16			; down, 15 keeps it as it was (silence stays
	bcs hs_on		; silent)
	cmp #15
	beq hs_k
	lda #0
	.byte $2C		; (bit abs: skips the lda #8)
hs_on	lda #8
	sta HSPK
hs_k	lda HSPK
	sta WSYNC
	sta CONSOL
	.if HLINES>1
	sta WSYNC
	.endif
	iny
	bne hs_lp
	inc PTR+1
	dec HPN
	bne hs_lp
	beq hp_end
h1_lp	lda (PTR),y		; one voice: half the level, 0-15
	lsr
	ora #$10		; volume only
	sta WSYNC
h1_a	sta AUDC1		; (patched: the voice)
	.if HLINES>1
	sta WSYNC
	.endif
	iny
	bne h1_lp
	inc PTR+1
	dec HPN
	bne h1_lp
	beq hp_end
h2_lp	lda (PTR),y		; two voices: the halves, the odd one to the
	lsr			; second
	ora #$10
	tax
	adc #0			; (ORA and TAX keep the carry: the low bit)
	sta WSYNC
h2_a	stx AUDC1		; (patched: the pair)
h2_b	sta AUDC1+2
	.if HLINES>1
	sta WSYNC
	.endif
	iny
	bne h2_lp
	inc PTR+1
	dec HPN
	bne h2_lp
hp_end
	.ifdef ROM
	ldx #3-OTHER		; this bank back in
	sta $D500,x
	.endif
	rts
hp_len	= *-hp_src
	.if hp_len>255
	.error "the hello player is too long for its copy loop"
	.endif

s_hl1	dta d'HELLO 7 TIMES: VOICES 1-4, SPEAKER,',$FF
s_hl2	dta d'VOICES 1+2 AND 3+4. SCREEN OFF MEANWHILE',$FF
s_hl3	dta d'HEARD ALL 7? Y/START=YES, N/SELECT=NO',$FF
	.ifdef ROM
	.elseif .def DISK
	.else
hl_data	ins '../cart/audio/hello-15k.bin'	; (whole pages)
hl_end
	.endif
