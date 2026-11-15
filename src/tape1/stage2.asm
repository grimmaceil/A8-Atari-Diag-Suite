; A8 DIAG tape 1, stage 2. Loaded by stage 1 (with the OS's SIO) at S2LOAD,
; in bank 1 RAM stage 1 has just tested, and entered at S2LOAD+6 with
; interrupts off. Stage 1's results come over in its BSS page.
;
;   relocate test   the loader area, $0800 up to stage 1's TSTART: stage 1's
;                   own code and BSS, which stage 1 could not test
;   under the OS    XL/XE: the RAM behind the OS ROM ($C000-$CFFF and
;                   $D800-$FFFF; $D000-$D7FF is always I/O), as bank 4
;   130XE banks     the four extended 16K banks, as banks 5-8
;   summary         every test on the tape, with the first failure's detail
;
; Then the final code: the loader area counts as bank 1 for the beeps.
; Built with -d:S1BSS=... -d:S1TSTART=... from stage 1's label table.
;
; ONE16 (the 16k tape): not loaded but part of stage 1's image, at S2AT,
; sharing stage 1's BSS page. The relocate test can't march the area it
; runs in, so each page of it is saved in the screen block (tested), given
; March C- and an address-in-page test, and put back, by a copy of the page
; test running from low RAM (common/pagetest.asm). No display: the NOT test.
; ONE32 (the 32k+ tape, with ONE16): the same, then START goes on to the
; system tests, which are in the image too.

	icl '../common/hw.asm'
	icl '../common/vars.asm'
	icl '../common/faults.asm'
	icl '../common/defs.asm'

LDRFOLD	= 1			; report.asm: fold the loader area into bank 1
	.ifdef ONE16
RESTART	= 1			; report.asm: the end waits for START: again
SHLIB	= 1			; one-load image: stage 1's library (lib.asm)
	.endif
SROW	= BSS+$DB		; summary: row of the item being printed
	.ifdef ONE32		; START at the summary goes to the menu
GOMENU	= 1
	.elseif .def ROM	; (the cartridge: in another bank, cart/romsum.asm)
GOMENU	= 1
XBANK	= $BFF0
XREQ	= BSS+$FC
STASH	= BSS+$E3		; (system/common.asm: the tests' results, kept
KEEP	= BSS+$EB		; while the RAM test ran again)
	.endif
	.if .def ONE32
FONT	= $7800			; ROM font copy while the OS is out (above the
S2LOAD	= S2AT			; image, the screen and the BSS page)
S1LOADPG = $08
	.elseif .def ONE16
FONT	= $3800			; ROM font copy while the OS is switched out
S2LOAD	= S2AT
S1LOADPG = $08
	.else
FONT	= $3800			; ROM font copy while the OS is switched out
S2LOAD	= $2000
S1LOADPG = $08
	.endif

	opt h-
	org S2LOAD

; Same header layout as a boot file: stage 1 checks the record count and
; load address, then jumps to S2LOAD+6.
	.byte 0
	.byte NREC
	.word S2LOAD
	.word 0

entry2	sei
	cld
	ldx #$FF
	txs
	.ifndef ONE16		; (ONE16: the same page)
	ldx #0			; take over stage 1's results
tk_lp	lda S1BSS,x
	sta BSS,x
	inx
	bne tk_lp
	.endif
	.ifdef SHLIB
	lda #<summary		; (OPTION's screen: report.asm)
	sta REDRAWV
	lda #>summary
	sta REDRAWV+1
	.endif
	.ifdef ROM
	lda #0			; (S: from here on only at skip2's safe points,
	sta INRT		; not in the middle of the march)
	.endif
	lda #0			; this stage's result is the tape's last
	sta CONTVEC+1
	.ifdef ROM		; CTRL+S in stage 1: no RAM test, on to the menu
	lda SKIPRAM
	beq noskip
	jmp tomenu
noskip
	.endif

	lda #C_YELLOW
	sta COLBK
	lda DISPOK
	beq rl_go
	jsr scr_on
	lda #<s_hrel
	ldy #>s_hrel
	jsr header
	lda #2
	jsr machinfo
	lda #3
	jsr chinfo
	.ifndef ROM
	PRINT 5, 0, s_tldr
	jsr ldrend
	.endif

; Relocate test: the area stage 1 ran from. Errors are charged to the loader
; area's own entry, so the summary can tell it apart from the rest of bank 1.
	.ifdef ROM
rl_go				; (in ROM: no loader area to test)
	.elseif .def ONE16
rl_go	ldx #0			; the page and NOT tests into low RAM
rl_cp	lda pgsrc,x
	sta PGCODE,x
	inx
	cpx #PICLEN
	bne rl_cp
	lda #0
	sta NTPTR
	sta BUFP
	lda SCRPG
	sta BUFP+1
	lda #S1LOADPG
	sta NTPTR+1
	lda DISPOK		; no display: no tested save page
	bne rl_pg
	sta NTERR
	ldx #S1TSTART-S1LOADPG
	jsr NTCODE
	lda NTERR
	beq rl_xl
	ldx #S1LOADPG		; (the first page, as the hint)
	jsr rlbad
	jmp rl_xl
rl_pg	lda #0			; page by page, to name the first bad one
	sta NTERR
	jsr PGCODE
	lda NTERR
	beq rl_ok
	ldx NTPTR+1
	jsr rlbad
rl_ok	inc NTPTR+1
	lda NTPTR+1
	cmp #S1TSTART
	bne rl_pg
	lda DISPOK		; the screen: it was the save page
	beq rl_xl
	jsr scr_on
	lda #<s_hrel
	ldy #>s_hrel
	jsr header
	jmp rl_xl
; rlbad: page X failed with the bits in NTERR: the loader area's entry.
rlbad	lda NTERR
	ora BADMASK+LDRIDX
	sta BADMASK+LDRIDX
	lda NTERR		; the march found them (the summary's hint)
	ora MBAD+LDRIDX
	sta MBAD+LDRIDX
	lda ECNTLO+LDRIDX	; the first one: its page, as the detail
	ora ECNTHI+LDRIDX
	bne rb_n
	stx EADRHI+LDRIDX
	lda #0
	sta EADRLO+LDRIDX
	sta EWROTE+LDRIDX
	lda NTERR
	sta EREAD+LDRIDX
rb_n	inc ECNTLO+LDRIDX	; (pages, not bytes)
	bne rb_x
	inc ECNTHI+LDRIDX
rb_x	rts
rl_xl
	.else
rl_go	lda #LDRIDX
	sta CURBANK
	sta BANKOVR
	jsr setfmask
	lda #S1LOADPG
	sta RBS
	lda #S1TSTART
	sta RBE
	jsr split
	jsr march2
	inc INAIA
	lda #0
	sta AIAMODE
	jsr aia
	inc AIAMODE
	jsr aia
	dec INAIA
	lda #0
	sta BANKOVR
	.endif

	lda MACHINE
	beq no_os
	.ifdef ROM
	jsr skip2
	.endif
	jsr underos
	.ifdef ROM
	jsr skip2
	.endif
	jsr xebanks
no_os	lda DISPOK
	beq fin
	jsr summary
fin
	.ifdef ROM
	lda #<tomenu		; START: on to the system tests' bank
	sta CONTVEC
	lda #>tomenu
	sta CONTVEC+1
	lda #1			; the summary stays up till then
	sta ENDING
	.elseif .def ONE32
	lda #<[SYS32+6]		; START: on to the system tests, in this image
	sta CONTVEC		; (they take the RAM results over as test 0)
	lda #>[SYS32+6]
	sta CONTVEC+1
	lda #1			; the summary stays up till then
	sta ENDING
	.endif
	ldx #LDRIDX
fin_lp	lda BADMASK,x
	bne fin_bad
	dex
	bne fin_lp
	jmp pass
fin_bad	jmp report

redraw	= summary		; scrtoggle's text screen

	.ifdef ROM
; skip2: CTRL+S, between this stage's parts (as stage 1's skipchk).
skip2	lda SKSTAT
	and #4
	beq s2_key
	lda IRQST
	and #$40
	bne s2_x
	lda #0
	sta IRQEN
	lda #$40
	sta IRQEN
s2_key	lda KBCODE
	and #$3F
	cmp #$3E		; S
	bne s2_x
	inc SKIPRAM
	ldx #$FF
	txs
	jmp tomenu
s2_x	rts

; tomenu: the RAM faults (banks 1-8) become test 0's items (kept at index
; 8: item = bank), as the system tests' results have them; then the menu.
tomenu	lda #0
	sta MTMP
	ldx #8
tm_lp	asl MTMP
	lda BADMASK,x
	beq tm_n
	inc MTMP
	lda #0
	sta BADMASK,x
tm_n	dex
	bne tm_lp
	lda MTMP
	sta BADMASK+8
	lda KEEP		; the RAM test again, from the menu: the tests'
	beq tm_nk		; results back
	ldx #7
tm_kp	lda STASH-1,x		; (KEEP stays set: trun goes to the menu)
	sta BADMASK,x
	dex
	bne tm_kp
tm_nk	lda #0			; (XREQ 0: trun)
	sta XREQ
	ldx #SYSA
	jmp XBANK
	.endif


; Progress lines for xlram.asm.
osprog	lda DISPOK
	beq pg_x
	PRINT 6, 0, s_tos
pg_x	rts
xeprog	lda DISPOK
	beq pg_x
	PRINT 7, 0, s_txe
	rts

; ldrend: "$xxFF", the end of the loader area.
ldrend	lda #S1TSTART-1
	jsr puthex
	lda #<s_ff
	ldy #>s_ff
	jmp puts

; ---------------------------------------------------------------------------
; summary: every test on the tape, then the first failure in detail.
SCOL	= 26			; status column
summary	jsr scr_on
	lda #<s_hsum
	ldy #>s_hsum
	jsr header
	lda #2
	jsr machinfo
	lda #3
	jsr chinfo

	lda #5
	sta SROW
	PRINT 5, 0, s_i1	; got here, so low RAM passed
	lda #<s_pass
	ldy #>s_pass
	jsr puts_st
	lda #6
	sta SROW
	PRINT 6, 0, s_i2	; and so did the display checks (or no summary)
	lda #<s_pass
	ldy #>s_pass
	jsr puts_st

su_banks lda #1
	sta CURBANK
su_bk	clc
	adc #6			; rows 7-9
	sta SROW
	ldx #0
	jsr at
	lda CURBANK		; "3 BANK 1 $0000-$3FFF"
	clc
	adc #$12		; '2' + bank
	jsr putc
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
	lda CURBANK
	sec
	sbc #1
	jsr bankhi
	jsr puthex
	lda #<s_00dash
	ldy #>s_00dash
	jsr puts
	lda CURBANK
	jsr bankhi
	sec
	sbc #1
	jsr puthex
	lda #<s_ff
	ldy #>s_ff
	jsr puts
	lda CURBANK		; present at all?
	sec
	sbc #1
	jsr bankhi
	cmp RAMTOP
	bcc su_have
	lda #<s_none
	ldy #>s_none
	jsr puts_st
	jmp su_next
su_have	jsr bankstat
su_next	inc CURBANK
	lda CURBANK
	cmp #4
	bne su_bk

	.ifndef ROM
	lda #10
	sta SROW
	PRINT 10, 0, s_i7	; loader area
	jsr ldrend
	lda #LDRIDX
	sta CURBANK
	jsr bankstat
	.endif
	lda OSRAM
	beq su_cnt
	lda #11
	sta SROW
	PRINT 11, 0, s_i8
	lda OSRAM
	cmp #2
	beq su_os
	lda #<s_none
	ldy #>s_none
	jsr puts_st
	jmp su_xe
su_os	lda #4
	sta CURBANK
	jsr bankstat
su_xe	lda XERAM		; 130XE: one line for banks 5-8
	beq su_cnt
	lda #12
	sta SROW
	PRINT 12, 0, s_i9
	lda BADMASK+5
	ora BADMASK+6
	ora BADMASK+7
	ora BADMASK+8
	bne su_xf
	lda #<s_pass
	ldy #>s_pass
	jsr puts_st
	jmp su_cnt
su_xf	lda #<s_fail		; FAIL and which banks
	ldy #>s_fail
	jsr puts_st
	ldx #5
su_xl	lda BADMASK,x
	beq su_xn
	lda #0
	jsr putc
	txa
	clc
	adc #$10
	jsr putc
su_xn	inx
	cpx #9
	bne su_xl

su_cnt	PRINT 14, 0, s_nfail	; failures, and the first one's detail
	lda #0
	sta DVAL
	sta DVAL+1
	sta CNT			; first failed index
	ldx #LDRIDX
su_cl	lda BADMASK,x
	beq su_cn
	inc DVAL
	stx CNT
su_cn	dex
	bne su_cl
	jsr putdec
	lda CNT
	bne su_det
	PRINT 16, 0, s_nextok
	jmp su_end
su_det	sta CURBANK
	PRINT 16, 0, s_detail
	lda CURBANK
	cmp #LDRIDX
	beq su_dl
	cmp #5
	bcc su_mb
	lda #<s_xe
	ldy #>s_xe
	jsr puts
su_mb	lda #<s_bank
	ldy #>s_bank
	jsr puts
	lda CURBANK
	clc
	adc #$10
	jsr putc
	jmp su_dd
su_dl	lda #<s_ldr
	ldy #>s_ldr
	jsr puts
su_dd	lda #16
	sta RROW
	jsr faildetail
	PRINT 21, 0, s_nextbad
su_end
	PRINT 23, 0, s_toggle2
	rts

; bankhi: A = bank-1 (0-3) -> A = its first page ($00/$40/$80/$C0).
bankhi	asl
	asl
	asl
	asl
	asl
	asl
	rts

; bankstat: PASS, or FAIL and the bad bits (as $xx if more than 3), for
; CURBANK, at the status column of the current row.
bankstat ldx CURBANK
	lda BADMASK,x
	bne bs_fail
	lda #<s_pass
	ldy #>s_pass
	jmp puts_st
bs_fail	lda #<s_fail
	ldy #>s_fail
	jsr puts_st
	ldx CURBANK
	lda BADMASK,x
	jsr popcnt
	cpx #4
	bcs bs_hex
	jmp putbits
bs_hex	lda #<s_dol
	ldy #>s_dol
	jsr puts
	ldx CURBANK
	lda BADMASK,x
	jmp puthex

; puts_st: print A/Y at the status column of row SROW.
puts_st	pha
	tya
	pha
	lda SROW
	ldx #SCOL
	jsr at
	pla
	tay
	pla
	jmp puts

; ---------------------------------------------------------------------------
	.ifdef SHLIB
	icl '../../build/shlib.asm'	; the library's addresses, in stage 1
	.else
	icl '../common/lib.asm'
	.endif
	icl '../common/bits.asm'
	icl '../common/detail.asm'
	icl '../common/xlram.asm'
	.ifdef ONE16
	.ifndef ROM
	icl '../common/pagetest.asm'
	.endif
	.endif

	.ifdef ROM
s_hrel	dta d'RAM TEST',$FF
	.else
s_hrel	dta d'LOADER AREA',$FF
	.endif
s_hsum	dta d'SUMMARY',$FF
s_tldr	dta d'TESTING LOADER AREA $0800-$',$FF
s_i1	dta d'1 LOW RAM $0000-$07FF',$FF
s_i2	dta d'2 DISPLAY CHECKS',$FF
s_i7	dta d'6 LOADER AREA $0800-$',$FF
s_i8	dta d'7 BANK 4 $C000-$FFFF',$FF
s_i9	dta d'8 130XE BANKS 5-8',$FF
s_xe	dta d' XE',$FF
s_bank	dta d' BANK ',$FF
s_ldr	dta d' LOADER AREA',$FF
s_dol	dta d' $',$FF
s_00dash dta d'00-$',$FF
s_ff	dta d'FF',$FF
s_pass	dta d'PASS',$FF
s_fail	dta d'FAIL'*,$FF
s_none	dta d'NOT FOUND',$FF
s_tos	dta d'TESTING RAM UNDER THE OS ROM',$FF
s_txe	dta d'TESTING 130XE BANKS',$FF
s_nfail	dta d'FAILURES: ',$FF
s_detail dta d'DETAIL:',$FF
	.ifdef GOMENU
s_nextok dta d'ALL PASSED',$FF
s_nextbad dta d'FIX THIS FIRST',$FF
	.elseif .def ONE16
s_nextok dta d'ALL PASSED. NEXT: DIAG-16K-02-SYSTEM',$FF
s_nextbad dta d'FIX THIS FIRST',$FF
	.else
s_nextok dta d'ALL PASSED. NEXT: DIAG-8K-02-ROM',$FF
s_nextbad dta d'FIX THIS FIRST',$FF
	.endif
	.ifdef GOMENU
s_toggle2 dta d'START=GO ON  SELECT=RE-BEEP',$FF
	.else
s_toggle2 dta d'SELECT=RE-BEEP  OPTION=FLASH',$FF
	.endif

	.ifndef ROM		; (in ROM every byte counts: no page alignment)
PADTO	= [[*+2+$FF]/$100]*$100
	.if PADTO-*-2>0
	:[PADTO-*-2] .byte 0
	.endif
	.endif
IMGSUM	.word 0			; mkcas.py: sum of every byte before this
IMGEND
NREC	= [IMGEND-S2LOAD]/128
	.if .def ONE16
BSS	= S1BSS			; one image: stage 1's BSS page is this one's
				; (ONE32: a page in the image, below $4000)
	.else
BSS	= IMGEND
	.endif
	.if .def ONE32
	.if IMGEND>$4000
	.error "stage 2 too big: it must end below $4000 (it runs while a 130XE bank is in at $4000-$7FFF)"
	.endif
	.elseif [>BSS]+1>[>FONT]
	.error "stage 2 too big: $3800-$3FFF must stay free (font copy, screen block)"
	.endif
