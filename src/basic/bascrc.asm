; BASCRC as a disk file (diag-bascrc.xex): the BASIC ROM at $A000-$BFFF by
; CRC32, named revision A, B or C (MAME's hash/a800.xml), as bascrc.bas does
; in BASIC. For a 400/800 or 1200XL with a BASIC cartridge (load it from
; DOS with the cartridge in: DOS, then L), or an XL/XE's built-in BASIC
; (switched in here if it is off). Uses the OS: it prints through the
; screen editor (IOCB 0), and returns to DOS after a key. Loads at $2000.
;
; While it reads, the screen is off: on an XL/XE with BASIC off, the screen
; can sit under $A000-$BFFF, where BASIC comes in.

	opt h+
PTR	= $CB			; (free for programs under BASIC and DOS)
CRC	= $CD			; 4: CRC32 being built
PGL	= $D1
CIOV	= $E456
ICCOM	= $0342
ICBAL	= $0344
ICBLL	= $0348
SDMCTL	= $022F
RTCLOK	= $14
CH	= $02FC
PORTB	= $D301

	org $2000
start	lda #<s_title
	ldy #>s_title
	jsr print
	lda SDMCTL		; the screen off for the read
	sta dmasv
	lda #0
	sta SDMCTL
	jsr frame
	jsr frame
	lda PORTB
	sta pbsv
	jsr isrom		; a ROM there already: a cartridge, or BASIC on
	bcs have
	lda pbsv		; no: the XL/XE's built-in BASIC in (on a 400/800
	and #$FD		; PORTB is the joystick port, set to input: the
	sta PORTB		; write does nothing)
	jsr isrom
	bcs have
	jsr back
	lda #<s_none
	ldy #>s_none
	jsr print
	jmp done

have	lda #$FF		; CRC32 of 32 pages: reflected, $EDB88320, a bit
	ldx #3			; at a time (as the ROM test, t_rom.asm)
cn	sta CRC,x
	dex
	bpl cn
	lda #$A0
	sta PTR+1
	lda #0
	sta PTR
	tay
	lda #32
	sta PGL
cp	lda (PTR),y
	eor CRC
	sta CRC
	ldx #8
cb	lsr CRC+3
	ror CRC+2
	ror CRC+1
	ror CRC
	bcc cz
	lda CRC+3
	eor #$ED
	sta CRC+3
	lda CRC+2
	eor #$B8
	sta CRC+2
	lda CRC+1
	eor #$83
	sta CRC+1
	lda CRC
	eor #$20
	sta CRC
cz	dex
	bne cb
	iny
	bne cp
	inc PTR+1
	dec PGL
	bne cp
	lda $A8E2		; the byte that names the revision
	sta revb
	jsr back
	ldx #3			; the CRC, inverted (as CRC32 ends), high byte
	ldy #HXAT		; first, and the byte, in hex
hx	lda CRC,x
	eor #$FF
	sta CRC,x
	jsr hex2
	dex
	bpl hx
	ldy #HXAT2
	lda revb
	jsr hex2
	lda #<s_crc
	ldy #>s_crc
	jsr print
	lda #2			; which revision?
	sta rk
ce	lda rk
	asl
	asl
	tax
	ldy #0
cm	lda CRC,y
	cmp tab,x
	bne cx
	inx
	iny
	cpy #4
	bne cm
	ldx rk			; this one
	lda mlo,x
	ldy mhi,x
	jsr print
	jmp done
cx	dec rk
	bpl ce
	lda #<s_nom
	ldy #>s_nom
	jsr print

done	lda #<s_key
	ldy #>s_key
	jsr print
	lda #$FF
	sta CH
wk	lda CH
	cmp #$FF
	beq wk
	lda #$FF
	sta CH
	rts			; back to DOS

; isrom: C set if $A000 holds a ROM: a write there doesn't change it.
isrom	lda $A000
	tax
	eor #$FF
	sta $A000
	cmp $A000
	bne ir_r
	stx $A000		; RAM: put it back
	clc
	rts
ir_r	sec
	rts

; back: PORTB as it was, the screen on again.
back	lda pbsv
	sta PORTB
	lda dmasv
	sta SDMCTL

; frame: wait for the next frame.
frame	lda RTCLOK
fw	cmp RTCLOK
	beq fw
	rts

; print: the line at A/Y (ends with EOL) through the screen editor.
print	sta ICBAL
	sty ICBAL+1
	lda #9			; put record
	sta ICCOM
	lda #$FF
	sta ICBLL
	lda #0
	sta ICBLL+1
	ldx #0
	jmp CIOV

; hex2: A as two hex digits at s_crc+Y.
hex2	pha
	lsr
	lsr
	lsr
	lsr
	jsr hex1
	pla
	and #$0F
hex1	cmp #10
	bcc h1
	adc #6			; (C set: +7, past the digits to A)
h1	adc #'0'
	sta s_crc,y
	iny
	rts

tab	.dword $4BEC4DE2, $F0202FB3, $7D684184	; A, B, C
mlo	.byte <s_ra, <s_rb, <s_rc
mhi	.byte >s_ra, >s_rb, >s_rc
dmasv	.byte 0
pbsv	.byte 0
revb	.byte 0
rk	.byte 0
s_title	dta c'BASCRC: THE BASIC ROM BY CRC32',$9B
s_crc	dta c'CRC32 XXXXXXXX  BYTE $A8E2 = $XX',$9B
HXAT	= 6
HXAT2	= 30
s_ra	dta c'REV A: GOOD',$9B
s_rb	dta c'REV B: GOOD',$9B
s_rc	dta c'REV C: GOOD',$9B
s_nom	dta c'NO MATCH: NOT A GOOD BASIC A, B OR C',$9B
s_none	dta c'NO ROM AT $A000: NO BASIC TO CHECK',$9B
s_key	dta c'PRESS A KEY',$9B

	run start
