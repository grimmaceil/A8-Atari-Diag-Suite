; hello: sampled sound, on the cartridge and the disk file (they have the
; room). POKEY has no sample player: a voice set to "volume only" (AUDC bit
; 4) puts its 4-bit volume straight on the output, so writing a new volume
; every few scan lines plays a recording, 16 levels. Two voices played
; together add up, so two volumes give 31 levels: clearer. The console
; speaker (GTIA) is one bit: on or off.
;
; The word "hello" plays seven times:
;   1-4  on voice 1, 2, 3, 4: 4 bits (the sample halved)
;   5    on the console speaker: 1 bit (rougher)
;   6-7  on voices 1+2, then 3+4: 5 bits (clearer)
; Then the question; no answer in about 2 s plays them all again. Not
; heard: POKEY item 7.
;
; The recording: tools/mkhello.py made audio/hello.bin from a
; public-domain recording (Wikimedia Commons, En-us-hello.ogg, by
; Dvortygirl): the number of samples (2 bytes), then the samples, 0-30,
; 5 bits each, packed high bit first; HLINES scan lines to a sample.
HLINES	= 3			; scan lines to a sample (as mkhello.py's LINES)
HWHO	= TSCR+$08		; which of the seven, 0-6
HBUF	= TSCR+$09		; the byte being unpacked
HBITS	= TSCR+$0A		; its bits left
HS	= TSCR+$0B		; the sample, 0-30
HCNT	= TSCR+$0C		; 2: samples left

hello	lda DISPOK
	beq hl_all
	lda #7
	jsr clrrow
	PRINT 7, 0, s_hl1
	lda #8
	jsr clrrow
	PRINT 8, 0, s_hl2
	PRINT 9, 0, s_hl3
hl_all	jsr waitrel
	lda #0
	sta HWHO
hl_who	lda #<[hl_data+2]
	sta PTR
	lda #>[hl_data+2]
	sta PTR+1
	lda hl_data
	sta HCNT
	lda hl_data+1
	sta HCNT+1
	lda #0
	sta HBITS
hl_smp	lda #0			; the next sample: 5 bits
	sta HS
	ldx #5
hl_bit	lda HBITS
	bne hl_have
	tay
	lda (PTR),y
	sta HBUF
	inc PTR
	bne hl_np
	inc PTR+1
hl_np	lda #8
	sta HBITS
hl_have	dec HBITS
	asl HBUF
	rol HS
	dex
	bne hl_bit
	lda HS
	lsr			; A = half of it, 0-15
	ldx HWHO
	cpx #4
	bcc hl_one
	beq hl_spk
	pha			; two voices: the halves, the odd one to the second
	ora #$10
	ldy hl_pair-5,x
	sta AUDC1,y
	pla
	adc #0			; (the carry: the sample's low bit)
	ora #$10
	sta AUDC1+2,y
	bne hl_wt		; (always)
hl_spk	and #8			; the speaker: the sample's top bit
	sta CONSOL
	bpl hl_wt		; (always)
hl_one	ora #$10		; one voice: volume only
	pha
	txa
	asl
	tax
	pla
	sta AUDC1,x
hl_wt	ldx #HLINES
hl_ln	sta WSYNC
	dex
	bne hl_ln
	lda HCNT		; the end?
	bne hl_dc
	dec HCNT+1
hl_dc	dec HCNT
	lda HCNT
	ora HCNT+1
	beq hl_done
	jmp hl_smp
hl_done	lda #AUD_OFF		; quiet, 0.3 s, then the next one
	ldx #6
hl_off	sta AUDC1,x
	dex
	dex
	bpl hl_off
	lda #8
	sta CONSOL
	WAITMS 300
	inc HWHO
	lda HWHO
	cmp #7
	beq hl_ask
	jmp hl_who
hl_ask	ldx #120		; the answer: about 2 s, then all of it again
hl_key	jsr vsync
	lda SKSTAT
	and #4
	bne hl_con
	lda KBCODE
	and #$3F
	cmp #$2B		; Y
	beq hl_yes
	cmp #$23		; N
	beq hl_no
hl_con	lda CONSOL
	lsr
	bcc hl_yes		; START
	lsr
	bcc hl_no		; SELECT
	dex
	bne hl_key
	jmp hl_all
hl_no	lda #64			; item 7
	ora BADMASK+6
	sta BADMASK+6
hl_yes	jmp waitrel

hl_pair	.byte 0, 4		; AUDC offsets of the pairs: voices 1+2, 3+4
s_hl1	dta d'HELLO, 7 TIMES: VOICE 1, 2, 3, 4, THE',$FF
s_hl2	dta d'SPEAKER, THEN CLEARER: VOICES 1+2, 3+4',$FF
s_hl3	dta d'HEARD ALL 7? Y/START=YES, N/SELECT=NO',$FF
hl_data	ins '../cart/audio/hello.bin'
