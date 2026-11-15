; A8 DIAG tape 1, stage 1: boot and RAM, abstract (beep/flash) reporting.
;
;   green + chirp       alive: the CPU is running the loaded code
;   yellow              testing (a hang shows yellow)
;   red + beep code     fail; see report.asm for the code
;   green + jingle      pass; then one long flash per 16K bank tested
;
; Once low RAM passes it checks the display (VCOUNT, a 1K screen block) and
; runs the RAM test with text progress and results; if the display checks
; fail it stays beeps-only. The result screen is the picture check: the
; code flashes and repeats until START, which says someone can see it.
; OPTION switches between the text and full-screen flashes.
;
; Build flags (mads -d:NAME=value):
;   FAULT_BANK=0..4, FAULT_BIT=1..8   inject a stuck bit; bank 0 = low RAM
;   FAST=1                            skip the $55/$AA march pass
;   ONE16=1                           the 16k tape, one boot file: stage 2
;                                     is in the image (PAYAT), no loader;
;                                     it page-tests this stage's RAM
;   ONE32=1 (with ONE16)              the 32k+ tape: the same, with the
;                                     system tests in the image too
;   ROM=1 (with ONE16)                the cartridge's bank 0: runs from ROM
;                                     at $A000 (cart/romsum.asm), BSS at
;                                     $0800; START at the summary goes to
;                                     the menu's bank

	icl '../common/hw.asm'
	icl '../common/vars.asm'
	icl '../common/faults.asm'
	icl '../common/defs.asm'
	.ifdef ONE16		; a one-load image: its later parts use this
SHLIB	= 1			; part's library (lib.asm)
	.endif

KEEP	= BSS+$EB		; (system/common.asm)
	.ifdef ROM		; S skips the RAM test, on the cartridge
SKIPKEY	= 1			; (ramtest.asm looks at it every page)
	.endif
	opt h-
	.ifdef ROM
LOAD	= $A000
	org LOAD
	jmp entry		; power-on
	jmp again		; from the menu: the RAM test again
	.else
LOAD	= $0800
	org LOAD

; Cassette boot header. The OS reads NREC records to LOAD, then JSRs LOAD+6.
; We never return, so CASINI and DOSVEC are never used.
	.byte 0
	.byte NREC
	.word LOAD
	.word init_rts
	.endif

	icl '../common/boot.asm'
	jsr dprereq
	.ifdef SKIPKEY		; (the keyboard latch is on: boot.asm)
	lda $07FE		; back from the long memory test (tape2's
	cmp #$5A		; backcart): no RAM test, the menu
	bne rt_nb
	lda $07FF
	cmp #$A5
	bne rt_nb
	sta $07FE		; (once)
	inc SKIPRAM
	inc KEEP		; (the menu, not the ROM test: system/common.asm)
	jmp PAYAT+6
rt_nb	inc INRT		; (not before: the screen block's march, in
	jsr skipchk		; dprereq, must run to the end)
	.endif
	.ifdef ROM
	jsr undercart		; the 8K under the cartridge (cart/undercart.asm)
	.endif
	lda DISPOK		; no display: beeps only (ANTIC stays off)
	beq rt_go
	jsr ramscreen
rt_go	jsr ramtest
	.ifdef ONE16
	jmp PAYAT+6		; no results here: stage 2's summary has them all
	.else
	lda RAMTOP		; 16K and up: a press (or a pass) goes on to
	cmp #$40		; stage 2. 8K: the end, nothing to press; the
	bcc rt_8k		; results' stage 2 line says what to load next
	lda #<load2
	sta CONTVEC
	lda #>load2
	sta CONTVEC+1
	bne rt_res
rt_8k	lda #<s_l2_8k
	sta L2MSG
	lda #>s_l2_8k
	sta L2MSG+1
rt_res	lda DISPOK
	beq final
	jsr results
final	ldx #4
res_lp	lda BADMASK,x
	bne res_bad
	dex
	bne res_lp
	jmp pass
res_bad	jmp report
	.endif

	.ifndef ONE16		; (ONE16: no results here, stage 2's summary
redraw	= results		; has them; scrtoggle's text screen)
	.endif

	.if .not .def ONE16
	icl '../common/loader.asm'
	.endif

	.ifdef ONE16
; again: the whole RAM test once more, from the low RAM test on (stage 2's
; START at the end). The image is intact (the page test put every page
; back), so no reload and no image checksum: fresh results, then as at boot.
again	sei
	.ifdef SKIPKEY		; the keyboard latch: S counts from now
	lda #$40
	sta IRQEN
	.endif
	lda #0
	sta NMIEN
	sta DMACTL
	tax
ag_cl	cpx #$E0		; (not $E0-$F3: the system tests' state and their
	bcc ag_c		; results, which wait there while this runs)
	cpx #$F4
	bcc ag_n
ag_c	sta BSS,x
ag_n	inx
	bne ag_cl
	lda #$08
	sta SPKPH
	lda #C_GREEN
	sta COLBK
	jmp lowram
	.endif
	icl '../common/display.asm'

; ---------------------------------------------------------------------------
; RAM test, bank by bank (16K each) from TSTART to RAMTOP, minus the screen
; block (tested in findscr). Below TSTART is low RAM (tested) and this stage.
ramtest	lda #1
	sta CURBANK
rt_bank	jsr bankrange
	bcs rt_next
	inc NBANKS
	jsr showbank
	jsr split
	lda RNGN
	beq rt_next
	jsr setfmask
	jsr march2
rt_next	inc CURBANK
	lda CURBANK
	cmp #4
	bne rt_bank

; Address-in-address over everything at once, so a bank that mirrors
; another (an address-line or decoder fault) shows up too.
	lda #TSTART
	sta RBS
	lda RAMTOP
	sta RBE
	jsr split
	inc INAIA
	lda #0
	sta AIAMODE
	jsr aia
	inc AIAMODE
	jsr aia
	dec INAIA
	rts

; bankrange: RBS/RBE = the pages of bank CURBANK to test. C set if none.
bankrange lda CURBANK
	sec
	sbc #1
	asl
	asl
	asl
	asl
	asl
	asl
	cmp #TSTART
	bcs br_s
	lda #TSTART
br_s	sta RBS
	lda CURBANK
	asl
	asl
	asl
	asl
	asl
	asl
	cmp RAMTOP
	bcc br_e
	lda RAMTOP
br_e	sta RBE
	lda RBS
	cmp RBE
	rts


; ---------------------------------------------------------------------------
; Text screens for the RAM test.
	.ifdef SKIPKEY
; skipchk: S pressed: no RAM test (or no more of it). Stage 2 sees SKIPRAM
; and goes straight on (at power on: the ROM test; from the menu: the menu),
; and the menu shows the RAM as SKIPPED.
; A key held now, or pressed since the last look (the latch). Only A is used.
skipchk	lda INRT
	beq sk_x
	lda SKSTAT
	and #4
	beq sk_key
	lda IRQST
	and #$40
	bne sk_x
	lda #0			; (the latch: off and on again clears it)
	sta IRQEN
	lda #$40
	sta IRQEN
sk_key	lda KBCODE
	and #$3F		; (with or without SHIFT, CONTROL)
	cmp #$3E		; S
	bne sk_x
	inc SKIPRAM
	jmp PAYAT+6		; (stage 2 sets the stack up again)
sk_x	rts
	.endif

ramscreen jsr scr_on
	lda #C_YELLOW
	sta COLBK
	lda #<s_hram
	ldy #>s_hram
	jsr header
	lda #2
	jsr machinfo
	.ifdef SKIPKEY
	PRINT 23, 0, s_skip
	.endif
	lda #3
	jmp chinfo

showbank lda DISPOK
	beq sb_x
	PRINT 5, 0, s_testing
	lda CURBANK
	clc
	adc #$10
	jmp putc
sb_x	rts

	.ifndef ONE16
; results: one line per bank (plus the bad bits for a failed one), then the
; overall result. The full detail (first error, hint) is on stage 2's summary.
;   BANK 2 $4000-$7FFF  FAIL
;    FIRST $4000 W $00 R $10 X $10 HI
;    ERRORS 65535  BITS D4
;    ONE BIT: ONE RAM CHIP
results	jsr ramscreen
	PRINT 4, 0, s_legend
	lda #6
	sta RROW
	lda #1
	sta CURBANK
rs_bank	lda RROW
	ldx #0
	jsr at
	lda #<s_bank
	ldy #>s_bank
	jsr puts
	lda CURBANK
	clc
	adc #$10
	jsr putc
	lda #<s_dol
	ldy #>s_dol
	jsr puts
	lda CURBANK		; $(b-1)*40 00 - $(b*40-1) FF
	sec
	sbc #1
	asl
	asl
	asl
	asl
	asl
	asl
	jsr puthex
	lda #<s_00dash
	ldy #>s_00dash
	jsr puts
	lda CURBANK
	asl
	asl
	asl
	asl
	asl
	asl
	sec
	sbc #1
	jsr puthex
	lda #<s_ff
	ldy #>s_ff
	jsr puts
	jsr bankrange
	bcc rs_found
	lda #<s_none
	ldy #>s_none
	jsr puts
	jmp rs_next
rs_found ldx CURBANK
	lda BADMASK,x
	bne rs_fail
	lda #<s_pass
	ldy #>s_pass
	jsr puts
	jmp rs_next
rs_fail	lda #<s_fail
	ldy #>s_fail
	jsr puts
	jsr bitsline
rs_next	inc RROW
	inc CURBANK
	lda CURBANK
	cmp #4
	beq rs_end
	jmp rs_bank

rs_end	lda MACHINE
	beq rs_tot
	lda RROW
	ldx #0
	jsr at
	lda #<s_bank4
	ldy #>s_bank4
	jsr puts
rs_tot	lda CONTVEC+1
	beq rs_end2
	PRINT 23, 0, s_toggle
	jmp rs_l2
rs_end2	PRINT 23, 0, s_toggle2
rs_l2	lda L2MSG+1		; why stage 2 didn't run
	beq rs_res
	PRINT 22, 0, s_l2pre
	lda L2MSG
	ldy L2MSG+1
	jsr puts
	lda L2STAT
	beq rs_res
	jsr puthex
rs_res
	PRINT 20, 0, s_result
	ldx #4
rs_any	lda BADMASK,x
	bne rs_bad
	dex
	bne rs_any
	lda #<s_allpass
	ldy #>s_allpass
	jmp puts
rs_bad	lda #<s_somefail
	ldy #>s_somefail
	jmp puts

	.endif

; ---------------------------------------------------------------------------
; Strings, in screen codes ($FF ends).
s_hram	dta d'RAM TEST',$FF
	.ifdef SKIPKEY
s_skip	dta d'S = SKIP',$FF
	.endif
s_testing dta d'TESTING BANK ',$FF
	.ifndef ONE16
s_legend dta d'CODE: LONG=BANK, SHORT=BIT (D0=1)',$FF
s_bank	dta d'BANK ',$FF
s_dol	dta d' $',$FF
s_00dash dta d'00-$',$FF
s_ff	dta d'FF  ',$FF
s_none	dta d'NOT FOUND',$FF
s_pass	dta d'PASS',$FF
s_fail	dta d'FAIL'*,$FF
s_bank4	dta d'BANK 4 $C000-$FFFF  IN STAGE 2',$FF
s_result dta d'RESULT: ',$FF
s_toggle dta d'START=GO ON SELECT=RE-BEEP OPTION=FLASH',$FF
s_toggle2 dta d'SELECT=RE-BEEP  OPTION=FLASH',$FF
s_l2load dta d'LOADING STAGE 2...',$FF
s_l2pre	dta d'STAGE 2: ',$FF
s_l2_8k	dta d'16K ONLY. NEXT: DIAG-8K-02-ROM',$FF
s_l2_bad dta d'NOT LOADED, BANK 1 FAILED',$FF
s_l2_big dta d'TOO BIG',$FF
s_l2_sio dta d'ERROR $',$FF
s_l2_hdr dta d'NOT ON TAPE',$FF
s_l2_sum dta d'BAD CHECKSUM',$FF
s_allpass dta d'ALL RAM PASSED',$FF
s_somefail dta d'FAIL: SEE THE CODE'*,$FF
	.endif

init_rts rts

; Low-RAM patterns: solid, checkerboard, walking 1, walking 0.
pats	.byte $00,$FF,$55,$AA
	.byte $01,$02,$04,$08,$10,$20,$40,$80
	.byte $FE,$FD,$FB,$F7,$EF,$DF,$BF,$7F
NPAT	= *-pats

	icl '../common/lib.asm'
	.ifndef ONE16
	icl '../common/bits.asm'
	.endif
	.ifdef ROM
	icl '../cart/romsum.asm'
	icl '../cart/undercart.asm'
	.endif


	.ifdef ONE32
; The BSS page, in the image: below $4000, so stage 2 can use it while a
; 130XE bank is in at $4000-$7FFF, and stage 2 and the system tests share it
; with this part and its library. Zeros in the image; boot.asm's checksum
; skips it (it is in use by then); stage 2 page-tests it with the rest.
BSSPAD	= [[*+$FF]/$100]*$100
	.if BSSPAD-*>0
	:[BSSPAD-*] .byte 0
	.endif
BSS
	:256 .byte 0
	.if BSS>=$4000
	.error "the BSS page must be below $4000 (130XE banks)"
	.endif
	.endif

	.ifdef ONE16
; Stage 2, as built to run here (build.py's build_one16).
	.ifndef ROM		; (in ROM every byte counts: no page alignment)
PAYPAD	= [[*+$FF]/$100]*$100
	.if PAYPAD-*>0
	:[PAYPAD-*] .byte 0
	.endif
	.endif
PAYAT	ins '../../build/payload16.bin'
	.endif

	.ifdef ROM
	.if *>$BFE0
	.error "the cartridge's RAM bank is over 8K (the tail starts at $BFE0)"
	.endif
IMGEND
BSS	= $0800			; in RAM: the page above low RAM
TSTART	= [>BSS]+1
	.else
; Pad to a whole page; the last two bytes hold the image sum (mkcas.py),
; or (ONE32) the last six: the sum, then CRCFIX, for the ROM test's check
; of the image from PAYAT on (stage 2, the system tests, the long test's
; copy: all as loaded when it runs; t_rom.asm's selfchk).
	.ifdef ONE32
TAILN	= 6
CRCAT	= PAYAT
	.else
TAILN	= 2
	.endif
PADTO	= [[*+TAILN+$FF]/$100]*$100
	.if PADTO-*-TAILN>0
	:[PADTO-*-TAILN] .byte 0
	.endif
CKSUM	.word 0
	.ifdef ONE32
CRCFIX	.dword 0
	.endif
IMGEND
NREC	= [IMGEND-LOAD]/128
	.ifdef ONE32
TSTART	= >IMGEND		; (BSS is the page in the image, above)
	.else
BSS	= IMGEND
TSTART	= [>BSS]+1
	.endif
	.endif
