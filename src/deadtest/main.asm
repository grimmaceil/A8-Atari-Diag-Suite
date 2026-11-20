; The dead test (docs/superpowers/specs/2026-11-20-dead-test-design.md):
; the cartridge starts in diag mode, the OS jumps here before it touches
; RAM, and this tests and tells what it can with no RAM, then hands over
; to the suite.
;
; One source, assembled once per dead bank (build.py's build_dead):
;   DTBANK      this bank's number (DEADBK on; the standalone: 0)
;   DEADBK      the first dead bank (the tail's stub selects it)
;   STANDALONE  the plain 8K cartridge: one bank, no bank switching, no
;               suite to hand over to
; Every dead bank starts with the same three entries:
;   $A000  cold start (the tail's stub, from whichever bank the cartridge
;          powered up in)
;   $A003  a phase, Y saying which (from another dead bank, by XBANK)
;   $A006  rts: the dead banks' init address (the OS's cold start calls it
;          after the hand-over)
; The font (tools/mkfont.py: characters 0-63, our own) sits at FONTAT in
; every bank that shows text; code and data stay below $BF00 (the code
; banks' CRC32 covers $A000-$BEFF) and below the font.
	icl '../common/hw.asm'

FONTAT	= $BC00			; 1K-aligned for CHBASE; chars 0-63 = 512 bytes
C_LUM	= $0C			; text luminance, as the suite's C_TEXTLUM

	opt h-f+
	org $A000
dtcold	jmp cold
dtphase	jmp phase
dtrts	rts

; cold: from the OS's diag jump: interrupts off, every chip set here (the
; OS hasn't cleared any register yet), the screen from ROM.
cold	sei
	cld
	lda #0
	sta NMIEN
	sta DMACTL
	ldx #$1F		; GTIA: every register 0
c_gt	sta $D000,x
	dex
	bpl c_gt
	ldx #$0F		; POKEY: every voice off, AUDCTL 0
c_pk	sta $D200,x
	dex
	bpl c_pk
	lda #3			; keyboard on, serial idle
	sta SKCTL
	lda #$3C		; PIA: the port registers; motor off, command high
	sta PACTL
	sta PBCTL
	lda #<dl
	sta DLISTL
	lda #>dl
	sta DLISTH
	lda #>FONTAT
	sta CHBASE
	lda #2			; inverse characters shown
	sta CHACTL
	lda #C_LUM
	sta COLPF1
	lda #0
	sta COLPF2
	sta COLBK
	lda #$22		; normal playfield, display list DMA
	sta DMACTL
	ldy #60			; about a second: 60 frames, VCOUNT's wrap
c_fr	lda VCOUNT
	bne c_fr
c_fr2	lda VCOUNT
	beq c_fr2
	dey
	bne c_fr
	.ifdef STANDALONE
	jmp *			; no suite to hand over to
	.else
	jmp handover
	.endif

phase	jmp cold		; (the phases come with their tasks)

; handover: the suite starts as it does without the dead test: this dead
; bank (an ordinary header) stays in, the OS's cold start runs it. $033D-
; $033F first: the XL/XE OS takes them for its warm-start magic.
	.ifndef STANDALONE
handover lda #0
	sta $033D
	sta $033E
	sta $033F
	jmp ($FFFC)
	.endif

; The screen: three blank-line groups, then the rows (mode 2, 40 columns).
dl	dta $70,$70,$70
	dta $42,a(scr)
	dta $02,$02
	dta $41,a(dl)

scr	dta d' DEAD TEST'*	; row 0: the title bar, the version at the right
	.if VMIN>9
	:25 dta $80
	dta d'V'*,[VMAJ+$90],d'.'*,[VMIN/10+$90],[VMIN-VMIN/10*10+$90]
	.else
	:26 dta $80
	dta d'V'*,[VMAJ+$90],d'.'*,[VMIN+$90]
	.endif
	:40 dta 0		; row 1
	dta d'TESTING'		; row 2
	:33 dta 0

	.if *>FONTAT
	.error "the dead test's code runs into its font"
	.endif
	org FONTAT
	ins '../../build/dtfont.bin'
