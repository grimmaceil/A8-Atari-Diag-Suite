; hello: sampled sound, on the cartridge only (it has the room). POKEY has
; no sample player: a voice set to "volume only" (AUDC bit 4) puts its
; 4-bit volume straight on the output, so writing a new volume every few
; scan lines plays a recording, 4 bits a sample. The console speaker
; (GTIA) is one bit: on or off.
;
; The word "hello" plays five times: on voice 1, 2, 3 and 4 (the 4-bit
; volume of each), then on the console speaker (1 bit: rougher). Then the
; question; no answer in about 2 s plays them all again. Not heard:
; POKEY item 7.
;
; The recording: tools/mkhello.py made audio/hello.bin (HLINES scan lines
; a sample, two samples a byte, high nibble first) from a public-domain
; recording (Wikimedia Commons, En-us-hello.ogg, by Dvortygirl).
HLINES	= 3			; scan lines to a sample (as mkhello.py's LINES)
HWHO	= TSCR+$08		; 0-3: the POKEY voice, 4: the console speaker
HNIB	= TSCR+$09		; 0: the byte's high nibble is next, 1: its low

hello	lda DISPOK
	beq hl_go
	lda #7
	jsr clrrow
	PRINT 7, 0, s_hl1
	lda #8
	jsr clrrow
	PRINT 8, 0, s_hl2
hl_go	jsr waitrel
hl_all	lda #0
	sta HWHO
hl_who	lda #<hl_data
	sta PTR
	lda #>hl_data
	sta PTR+1
	lda #0
	sta HNIB
hl_smp	ldy #0			; the next sample, 0-15
	lda (PTR),y
	ldx HNIB
	bne hl_lo
	lsr
	lsr
	lsr
	lsr
	inc HNIB
	bne hl_out		; (always)
hl_lo	and #$0F
	dec HNIB
	inc PTR
	bne hl_out
	inc PTR+1
hl_out	ldx HWHO
	cpx #4
	beq hl_spk
	ora #$10		; volume only
	pha
	txa
	asl
	tax
	pla
	sta AUDC1,x
	jmp hl_wt
hl_spk	and #8			; the speaker: the sample's top bit
	sta CONSOL
hl_wt	ldx #HLINES
hl_ln	sta WSYNC
	dex
	bne hl_ln
	lda PTR+1		; the end?
	cmp #>hl_end
	bne hl_more
	lda PTR
	cmp #<hl_end
	beq hl_done
hl_more	jmp hl_smp
hl_done
	lda #AUD_OFF		; quiet, 0.3 s, then the next one
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
	cmp #5
	beq hl_ask
	jmp hl_who
hl_ask
	ldx #120		; the answer: about 2 s, then all of it again
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

s_hl1	dta d'HELLO, 5 TIMES: VOICE 1-4, THE SPEAKER',$FF
s_hl2	dta d'HEARD ALL 5? Y/START=YES, N/SELECT=NO',$FF
hl_data	ins '../cart/audio/hello.bin'
hl_end
