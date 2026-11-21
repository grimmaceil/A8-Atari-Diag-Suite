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
XBANK	= $BFF0			; the tail's bank switch: bank X, then its $A003
C_LUM	= $0C			; text luminance, as the suite's C_TEXTLUM
DDRA	= $D300			; PIA direction registers (PACTL/PBCTL bit 2 = 0):
DDRB	= $D301			; stage B's results (stageb.asm)
GRAFP0	= $D00D			; player 0, written directly (no P/M DMA)
HITCLR	= $D01E			; clears the collision registers
P0PF	= $D004			; player 0's playfield collisions

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
	.if DTBANK=DEADBK
	jmp stageb		; the RAM test (stageb.asm), then sbdone
	.else
	jmp *			; (only the first dead bank is entered cold)
	.endif

; sbdone: stage B's results are in the PIA and S: on to the show bank
; (phase 0), or in the standalone straight on.
	.if DTBANK=DEADBK
; Bank 1 good with its upper 8K left out (nothing answered there, and
; $3F00 doesn't keep what's written): an 8K machine when nothing answers
; above it either (DDRB and S $FF); RAM above an empty $2000-$3FFF is a
; fault, bank 1 NO RAM. (The show bank's row 5 makes the same test.)
sbdone	lda DDRA
	bne sb_8x
	lda #$55
	sta $3F00
	cmp $3F00
	bne sb_8h
	lda #$AA
	sta $3F00
	cmp $3F00
	beq sb_8x
sb_8h	lda DDRB
	cmp #$FF
	bne sb_8f
	tsx
	inx
	beq sb_8x
sb_8f	lda #$FF
	sta DDRA
sb_8x
	.ifdef STANDALONE
	ldy #0
	jmp phase
	.else
	ldy #1			; a bank passed: stage A uses it, from the bank
	ldx #DEADBK+2		; built for that page (DEADBK+2: bank 1's $0400,
	lda DDRA		; +3: bank 2's $4000, +4: bank 3's $8000)
	beq sb_a
	inx
	lda DDRB
	beq sb_a
	tsx
	txa
	bne sb_n
	ldx #DEADBK+4
sb_a	jmp XBANK
sb_n	ldx #DEADBK+1		; none: straight to the results
	ldy #0
	jmp XBANK
	.endif
	icl 'stageb.asm'
	.endif
	.if DTBANK=DEADBK+1
	icl 'show.asm'
	icl '../../build/dtext.asm'
	icl 'romcrc8.asm'
	.ifdef SPEECH
	icl '../../build/speech.asm'
	.endif
	.endif
	.ifdef STANDALONE
	icl 'show.asm'
	icl '../../build/dtextstd.asm'
	.endif
	.if DTBANK>=DEADBK+2 .and DTBANK<=DEADBK+4
SABASE	= [DTBANK-DEADBK-2]*$4000+[DTBANK=DEADBK+2]*$0400
	icl 'stagea.asm'
	.endif

; phase: Y says which: 0 the results (the show bank), 1 stage A.
phase
	.if DTBANK=DEADBK+1 .or .def STANDALONE
	cpy #0
	bne *+5
	jmp show
	.ifdef SPEECH
	jmp spk_n		; (a spoken phrase's next node, from a word bank)
	.endif
	.endif
	.ifdef WORDPG
	jmp play		; a word bank: its word
	.endif
	.if DTBANK>=DEADBK+2 .and DTBANK<=DEADBK+4
	cpy #1
	bne *+5
	jmp stagea
	.endif
	jmp *			; (no other phase)

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

	.ifndef STANDALONE
	icl 'screen0.asm'
	.endif

	.ifdef WORDPG
	icl 'speak.asm'
	.endif
	.if *>FONTAT
	.error "the dead test's code runs into its font"
	.endif
	org FONTAT
	ins '../../build/dtfont.bin'
	.ifdef STANDALONE	; (no room before the font)
	icl 'screen0.asm'
	.if *>$BFE0
	.error "the standalone's start-up screen runs into its header"
	.endif
	.endif
