; The cartridge's menu and loader: the same in every 8K bank of an AtariMax
; 128K cartridge (.car type 41), at STUB-$BFFF, so it runs whichever bank
; the cartridge starts in and goes on running while it switches banks.
; Below STUB each bank holds DATAPG pages of the two program images
; (tools/mkcar.py): the 32k diag image from bank DIAGBK on (DIAGPG pages),
; the memory test's from bank MEMBK on (MEMPG pages).
;
; START or SELECT picks one. If the RAM is there, the image is copied to
; $0800, the cartridge switches itself off (all the RAM is the test's) and
; the image starts at $0806, as from tape or disk. Too little RAM: one
; line, red border, the low tone on and off, as the tapes do.
;
; Banks: an access to $D500+n selects bank n (0-15), one to $D510-$D51F
; switches the cartridge off until the power goes off.

	opt h-
	icl '../common/hw.asm'
C_TEXTLUM = $0C		; as screen.asm
C_TEXTBG = $00
C_MENUBK = $94		; the menu's border: blue
TRIG3	= $D013		; 1 = a cartridge is in (XL/XE)
RAMTOP	= $6A		; the OS's: RAM below the cartridge, in pages
COLDST	= $0244		; nonzero: RESET starts the machine from cold
GINTLK	= $03FA		; XL/XE OS: TRIG3 as at power-on
SRC	= $80		; zero page: free, the OS hasn't started anything
DST	= $82
NPG	= $84		; pages left to copy
BANK	= $85
PIB	= $86		; pages left in this bank
NEED	= $87		; RAM needed, in pages
LINE	= $0600		; the message line (low RAM: every Atari has it)
TRAMPAT	= $0680		; the last few instructions, from RAM

	org STUB

init	rts			; (the OS calls it at power-on; nothing to do)

menu	sei			; the screen: the OS's VBI is off, so write
	cld			; the chips directly
	lda #0
	sta NMIEN
	sta IRQEN
	sta DMACTL
	sta AUDC1
	ldx #$FF
	txs
	inx
	txa
mn_cl	sta LINE,x		; (internal code 0 = space)
	inx
	cpx #40
	bne mn_cl
	lda #<dlist
	sta DLISTL
	lda #>dlist
	sta DLISTL+1
	lda #$E0
	sta CHBASE
	lda #2
	sta CHACTL
	lda #C_TEXTLUM
	sta COLPF1
	lda #C_TEXTBG
	sta COLPF2
	lda #C_MENUBK
	sta COLBK
	lda #$22
	sta DMACTL
	jsr release		; a key still held from power-on doesn't count
mn_key	lda CONSOL		; waits for good (no timeout)
	lsr
	bcc k_diag		; bit 0: START
	lsr
	bcc k_mem		; bit 1: SELECT
	bcs mn_key
k_diag	lda #$80
	ldx #DIAGBK
	ldy #DIAGPG
	bne go
k_mem	lda #$40
	ldx #MEMBK
	ldy #MEMPG
go	sta NEED
	stx BANK
	sty NPG
	lda RAMTOP
	cmp NEED
	bcs go_ok
	jmp short
go_ok	jsr release
	lda #0
	sta DMACTL
	sta SRC
	sta DST
	lda #$08
	sta DST+1
cp_bank	ldx BANK		; (this code is in every bank, so it goes on)
	sta $D500,x
	lda #$A0
	sta SRC+1
	lda #DATAPG
	sta PIB
	ldy #0
cp_by	lda (SRC),y
	sta (DST),y
	iny
	bne cp_by
	inc SRC+1
	inc DST+1
	dec NPG
	beq cp_done
	dec PIB
	bne cp_by
	inc BANK
	bne cp_bank		; (always)
cp_done	lda #1			; RESET: a cold start (the menu is gone)
	sta COLDST
	ldx #tr_len-1
cp_tr	lda tramp,x
	sta TRAMPAT,x
	dex
	bpl cp_tr
	jmp TRAMPAT

; Copied to TRAMPAT: once the cartridge is off, $A000-$BFFF is RAM.
tramp	sta $D510		; the cartridge off
	lda TRIG3		; (the XL OS halts if TRIG3 changes from this)
	sta GINTLK
	jmp $0806		; the image's entry, as the cassette boot's
tr_len	= *-tramp

; release: wait until START, SELECT and OPTION are all up.
release	lda CONSOL
	and #7
	cmp #7
	bne release
	rts

; short: "NEEDS nnK RAM. THIS MACHINE HAS nnK." and halt.
short	ldy #0
	ldx #0
sh_a	lda s_need,x
	sta LINE,y
	iny
	inx
	cpx #s_need_l
	bne sh_a
	lda NEED
	jsr putk
	ldx #0
sh_b	lda s_has,x
	sta LINE,y
	iny
	inx
	cpx #s_has_l
	bne sh_b
	lda RAMTOP
	jsr putk
	lda #'.'-$20
	sta LINE,y
	lda #C_RED
	sta COLBK
	lda #F_END
	sta AUDF1
	lda #AUD_ON		; 0.6 s on, 0.6 s off, for good (as boot.asm)
sh_tone	sta AUDC1
	ldy #37
sh_wy	ldx #0
sh_wx	sta WSYNC
	dex
	bne sh_wx
	dey
	bne sh_wy
	eor #AUD_ON^AUD_OFF
	jmp sh_tone

; putk: A pages as "nnK" at LINE,Y (no leading zero); Y moves on.
putk	lsr
	lsr
	ldx #$10-1		; tens digit (internal code '0' = $10)
pk_ten	inx
	sec
	sbc #10
	bcs pk_ten
	adc #10+$10		; ones digit
	cpx #$10
	beq pk_one		; no leading zero
	pha
	txa
	sta LINE,y
	iny
	pla
pk_one	sta LINE,y
	iny
	lda #'K'-$20
	sta LINE,y
	iny
	rts

s_need	dta d'  NEEDS '
s_need_l = *-s_need
s_has	dta d' RAM. THIS MACHINE HAS '
s_has_l	= *-s_has

dlist	:4 dta $70		; 32 blank lines
	dta $42, a(text)
	:NLINES-1 dta $02
	dta $70, $70
	dta $42, a(LINE)
	dta $41, a(dlist)

; 40 columns each (one mode 2 line). ANTIC reads them from the cartridge.
text
	dta d'                                        '
	dta d'        A8 DIAGNOSTICS CARTRIDGE        '
	dta d'                                        '
	dta d'                                        '
	dta d'  START   THE DIAGNOSTIC TESTS:         '
	dta d'          RAM, ROMS, KEYBOARD, CONSOLE  '
	dta d'          KEYS, JOYSTICKS, PADDLES,     '
	dta d'          SOUND AND VIDEO. NEEDS 32K.   '
	dta d'                                        '
	dta d'  SELECT  THE LONG MEMORY TEST: PASS    '
	dta d'          AFTER PASS UNTIL A KEY IS     '
	dta d'          PRESSED. NEEDS 16K.           '
	dta d'                                        '
	dta d'                                        '
	dta d'   POWER OFF AND ON TO COME BACK HERE   '
NLINES	= [*-text]/40

	.if *>$BFFA
	.error 'the menu runs into the cartridge header'
	.endif
	.if [>text]&$F0<>[>[*-1]]&$F0
	.error 'the menu text crosses a 4K boundary (ANTIC)'
	.endif

; The header the OS looks for: run address, "a cartridge is in", flags
; ($04: start it, no disk boot), init address.
	:[$BFFA-*] dta $FF
	dta a(menu)
	dta 0, $04
	dta a(init)
