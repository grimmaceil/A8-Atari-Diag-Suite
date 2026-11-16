; System tapes, shared code: the test list, the per-test result flow, frame
; sync, yes/no answers, the test-result screen and the tape's results.
;
; Each test leaves its failed items in BADMASK[test] (item n = bit n-1). A
; test ends with jmp tend; the tape's tlist says what comes next. Only the
; ROMs (test 1) and the RAM (index 8, shown as test 0) get a beep code
; (report.asm, SYSCODES); the other tests' results are on the screen.

; The system tapes run no RAM tests, so their data lives in the first-error
; arrays ($70-$CF of the BSS page), which only merr writes. (qscr uses ECNTLO.)
TEST	= BSS+$E0		; current test, 1-7
NEXTVEC	= BSS+$E1		; 2: where the test flow goes on to
STASH	= BSS+$E3		; 8: BADMASK 1-8 while one test's code plays
KEEP	= BSS+$EB		; nonzero: STASH holds the tests' results (ramagain)
TIDX	= BSS+$ED		; next tlist entry, times 2
MRUN	= BSS+$F0		; tests run so far, bit per test number
T3D	= $A0			; 96 bytes of test data, in zero page ($A0-$FF:
				; nothing else uses it once the boot is over, and
				; each instruction that uses it is a byte shorter):
NPORT	= T3D+$02		; joystick ports on this machine (paddles: twice)
				; $03-$1F: test 1's results (kept for the summary)
TSCR	= T3D+$20		; $20-$5F: scratch, each test its own use

; trun: from the boot, the first test on the list.
trun	jsr tinit
	lda #0
	sta TIDX
	.ifdef MENU
	sta MMODE
	lda DISPOK		; no picture: no menu, all of them in order
	beq tst_all
	.ifdef RAM8		; at power on, after the RAM test: the ROM test,
	lda KEEP		; then the menu. The RAM test run from the menu
	bne tst_mn		; (KEEP): back to the menu
	sta MSEL		; (0: the ROM test's line)
	jmp mgo
tst_mn	lda #0
	sta KEEP
	.endif
	ldx MNT
	stx MSEL		; the ALL line first
	jmp menu
tst_all	inc MMODE
	.endif
	jsr tnextv
	jmp (NEXTVEC)

; tinit: what the tests need to know about the machine and the tape.
tinit	lda #2			; ports: 4 on the 400/800, 2 on the XL/XE
	ldx MACHINE
	bne tst_xl
	lda #4
tst_xl	sta NPORT
	.ifdef MENU
	ldx #0			; MNT: the tests on the tape
tst_n	lda ttests,x
	beq tst_nt
	inx
	bne tst_n
tst_nt	stx MNT
	.endif
	rts

; tend: the end of a test: its result, then the next one on the list (from
; the menu: back to the menu, the next test highlighted).
tend	ldx TEST		; (run: its line says PASS or FAIL, not SKIPPED)
	lda bitn-1,x
	ora MRUN
	sta MRUN
	jsr tnextv
	.ifdef MENU
	lda MMODE
	bne te_x
	inc MSEL		; the next test (after the last: the results)
	lda MSEL
	cmp MNT
	bne te_m
	inc MSEL
te_m	lda #<menu
	sta NEXTVEC
	lda #>menu
	sta NEXTVEC+1
te_x
	.endif
	jmp tresult

; tskip: leave test TEST without a result (X): on to the next test
; when running them all (or without a menu), else back to the menu.
tskip
	.ifdef RAM8
	lda #0			; (the keyboard latch off: t_rom's xkey)
	sta IRQEN
	.endif
	jsr waitrel
	jsr tnextv
	.ifdef MENU
	lda MMODE
	bne tk_go
	jmp menu
tk_go
	.endif
	jmp (NEXTVEC)

	.ifndef MENU
	.ifdef WANT_ROM
; trestart: R at the end of the ROM tape (no menu): the test again, with a
; fresh result. (With a menu it is picked again there instead.)
trestart lda #0
	sta ENDING
	sta TIDX
	sta MRUN
	ldx #7
trs_cl	sta BADMASK,x
	dex
	bne trs_cl
	jsr tnextv
	jmp (NEXTVEC)
	.endif
	.endif

; tnextv: NEXTVEC = the next tlist entry.
tnextv	ldx TIDX
	lda tlist,x
	sta NEXTVEC
	lda tlist+1,x
	sta NEXTVEC+1
	inx
	inx
	stx TIDX
	rts

; vsync: wait for the start of the next frame (VCOUNT back from the bottom;
; 124 is reached on NTSC (130) and PAL (155)).
vsync	lda VCOUNT
	cmp #124
	bcc vsync
vs_2	lda VCOUNT
	cmp #124
	bcs vs_2
	rts

	.ifdef NEEDYN
; yesno: wait for the answer, as long as it takes. C set: Y or START. C
; clear: N or SELECT. Console keys too, so a dead keyboard can answer. The
; border is purple while it waits, so a question shows without a picture.
; YNSND: the sound being asked about, repeated until the answer: 0 none,
; 1 POKEY voice YNV/2 (a scale, then noise: 1 s on, 0.2 s off), 2 the
; console speaker (0.7 s on, 0.5 s off). A key
; pressed while the speaker tone runs (the CPU is busy making it) still
; counts: POKEY latches it in IRQST.
YNSND	= BSS+$F4
YNV	= BSS+$F5		; POKEY voice times 2 (its AUDF/AUDC offset)
YNFRM	= BSS+$F6		; frame in the on/off cycle
yesno	jsr waitrel
	lda #C_PURPLE
	sta COLBK
	lda #$40		; the keyboard IRQ latch (the CPU masks the IRQ)
	sta IRQEN
	lda #0
	sta YNFRM
yn_lp	lda YNFRM
	bne yn_s1
	jsr ynon
	jmp yn_f
yn_s1	cmp #60
	bne yn_f
	jsr ynoff
yn_f	jsr vsync
	.ifdef WANT_POK
	jsr ynnote
	.endif
	inc YNFRM
	lda YNFRM
	cmp #72
	bne yn_k
	lda #0
	sta YNFRM
yn_k	lda IRQST		; a key since the last look?
	and #$40
	bne yn_con
	lda #0
	sta IRQEN
	lda #$40
	sta IRQEN
	lda KBCODE
	and #$3F
	cmp #$2B		; Y
	beq yn_yes
	cmp #$23		; N
	beq yn_no
yn_con	lda CONSOL
	lsr			; START
	bcc yn_yes
	lsr			; SELECT
	bcc yn_no
	jmp yn_lp
yn_no	clc
	bcc yn_x
yn_yes	sec
yn_x	php
	jsr ynoff
	lda #0
	sta IRQEN
	sta YNSND
	lda #C_BLACK
	sta COLBK
	jsr waitrel
	plp
	rts

; ynon/ynoff: YNSND's sound on, off. The console speaker has no hardware
; tone: ynon makes 0.7 s of it then and there (WAITMS toggles the speaker).
ynon	lda YNSND
	beq yo_x
	.ifdef WANT_POK
	cmp #1
	bne yo_spk
	ldx YNV
	lda #AUD_ON
	sta AUDC1,x
	.else
	bne yo_spk
	.endif
yo_x	rts
yo_spk	lda #$08
	sta SPKMASK
	WAITMS 700
	lda #0
	sta SPKMASK
	lda #42			; that was the on time: on to the gap
	sta YNFRM
	rts
	.ifdef WANT_POK
; ynnote: a POKEY voice (YNSND 1) plays a rising scale, a note every 4
; frames (C5 to C6), not one pitch: a voice whose divider has a dead bit
; plays some of the notes wrong. Then, from frame 32 until it goes off (60),
; noise at the last note's rate.
ynnote	lda YNSND
	cmp #1
	bne yt_x
	ldx YNV
	lda YNFRM
	cmp #32
	bcc yt_n
	bne yt_x
	lda #AUD_NOISE
	sta AUDC1,x
	rts
yt_n	lsr
	lsr
	tay
	lda scale,y
	sta AUDF1,x
yt_x	rts
scale	.byte 60, 53, 47, 45, 40, 35, 31, 30
	.endif
ynoff
	.ifdef WANT_POK
	lda YNSND
	cmp #1
	bne yf_x
	ldx YNV
	lda #AUD_OFF
	sta AUDC1,x
	.endif
yf_x	rts
	.endif

; tresult: the end of test TEST. A pass gives the charge and goes on after
; ~2 s (OPTION holds it). A fail: report.asm's doom and a steady red border,
; waiting for START, a key or fire; the ROM test plays its code too. Only
; this test's result is in BADMASK meanwhile (the others wait in STASH), so
; no other test's code plays. Then the flow goes on at NEXTVEC.
; A tape without a menu: after its last test, straight to final (the end:
; its lines and its sound say it all, no pause before them).
tresult
	.ifndef MENU
	lda TIDX		; (tnextv has read final's entry, the last)
	cmp #ttests-tlist
	bne tr_nl
	jmp final
tr_nl
	.endif
	jsr tshow
	ldx TEST
	lda BADMASK,x
	bne tr_fail
	.ifdef WANT_ROM
	cpx #1			; the ROMs: a pass waits too, to read the sums
	bne tr_ps
	stx ENDING		; (report.asm's pass: no going on by itself)
	stx NBANKS		; (one flash)
	lda #<tr_go
	sta CONTVEC
	lda #>tr_go
	sta CONTVEC+1
	jmp pass
tr_go	lda #0
	sta ENDING
	jmp (NEXTVEC)
tr_ps
	.endif
	lda NEXTVEC
	sta CONTVEC
	lda NEXTVEC+1
	sta CONTVEC+1
	jmp pass
tr_fail	ldx #8
tf_st	lda BADMASK,x
	sta STASH-1,x
	cpx TEST
	beq tf_keep
	lda #0
	sta BADMASK,x
tf_keep	dex
	bne tf_st
	lda #<tr_back
	sta CONTVEC
	lda #>tr_back
	sta CONTVEC+1
	jmp report
tr_back	ldx #8
tf_rs	lda STASH-1,x
	sta BADMASK,x
	dex
	bne tf_rs
	jmp (NEXTVEC)

; tpage: a fresh page for test TEST, titled A/Y.
tpage	ldx DISPOK
	beq tp_x
	pha
	tya
	pha
	jsr scr_on
	pla
	tay
	pla
	jsr header
	lda #2
	jmp machinfo
tp_x	rts

; tshow: the result lines of test TEST on rows 21-23 (the test's own screen
; stays above). Also scrtoggle's redraw. A tape without a menu, at its end
; (ENDING 2): every test's line and what to load next (tsend).
tshow
	.ifdef MENU
	lda TEST		; 8: past the last test, the results
	cmp #8
	bne ts_t
	jmp results
ts_t
	.endif
	lda DISPOK
	beq ts_x
	lda SCRON
	bne ts_on
	jsr scr_on		; back from full-screen flashes: a plain page
	lda TEST
	asl
	tax
	lda tnames-2,x
	ldy tnames-1,x
	jsr header
ts_on	lda #23
	jsr clrrow
	.ifndef MENU
	lda ENDING
	cmp #2
	beq tsend
	.endif
	lda #21
	jsr tline
	ldx TEST
	lda BADMASK,x
	bne ts_go
	.ifdef WANT_ROM
	dex			; (the ROMs wait for a press)
	beq ts_go
	.endif
	.ifdef MENU
	lda MMODE		; one test from the menu: back to it
	bne ts_np
	PRINT 23, 0, s_mpass
	rts
ts_np
	.endif
	PRINT 23, 0, s_tpass
ts_x	rts
ts_go
	.ifdef MENU
	lda MMODE
	bne ts_ng
	PRINT 23, 0, s_toggle3	; R, T, a key = the menu
	rts
ts_ng
	.endif
	PRINT 23, 0, s_goon
	rts

	.ifndef MENU
; tsend: the end of a tape without a menu: a line for each test on it (two
; at most: rows 21-22), then what to load next. Nothing to press.
tsend	lda TEST
	pha
	ldx #0
te_lp	stx CNT
	lda ttests,x
	beq te_x
	sta TEST
	txa
	clc
	adc #21
	jsr tline
	ldx CNT
	inx
	bne te_lp
te_x	pla
	sta TEST
	PRINT 23, 0, s_next
	rts
	.endif

; tline: on row A, "TEST n PASS" or "TEST n FAIL, ITEMS 1 3" for test TEST
; (a tape without a menu: SKIPPED for one left with X).
tline	pha
	jsr clrrow
	pla
	ldx #0
	jsr at
	lda #<s_test
	ldy #>s_test
	jsr puts
	lda TEST
	clc
	adc #$10
	jsr putc
	lda #0
	jsr putc
	ldx TEST
	.ifndef MENU
	lda bitn-1,x
	and MRUN
	bne tl_ran
	lda #<s_skipd
	ldy #>s_skipd
	jmp puts
tl_ran
	.endif
	lda BADMASK,x
	bne tl_f
	lda #<s_pass
	ldy #>s_pass
	jmp puts
tl_f	pha
	lda #<s_fail
	ldy #>s_fail
	jsr puts
	lda #<s_items
	ldy #>s_items
	jsr puts
	pla
; putitems: the set bits of A as item numbers, " 1 3".
putitems sta MTMP
	ldx #0
pi_lp	lsr MTMP
	bcc pi_nx
	lda #0
	jsr putc
	txa
	clc
	adc #$11
	jsr putc
pi_nx	inx
	cpx #8
	bne pi_lp
	rts

redraw	= tshow			; scrtoggle's text screen

; ---------------------------------------------------------------------------
	.ifndef XFINAL
; final: past the last test: the results. A failed test: the doom, and a
; ROM or RAM fault's code; all passed: the charge, twice, and green; none
; failed but not all ran (left with X or S, or not run from the menu):
; partial, yellow and one chirp. With a menu: the results page, a press
; back to the menu. Without: the tape's lines on the last test's screen,
; and it stays: nothing to press.
final
	.ifdef MENU
	lda #8			; tshow, as redraw, shows the results from here
	sta TEST
	lda #0			; (no R: the menu picks a test again)
	sta RETESTV+1
	lda #<menu		; a key: back to the menu
	sta CONTVEC
	lda #>menu
	.else
	.ifdef WANT_ROM
	lda #<trestart		; R: the ROM test again
	sta RETESTV
	lda #>trestart
	sta RETESTV+1
	.endif
	lda #0			; (a key: the tones again)
	.endif
	sta CONTVEC+1
	lda #2			; the result stays up (2: a pass plays the charge
	sta ENDING		; twice; tshow: the end of a tape)
	ldx #0
fi_cnt	lda ttests,x
	beq fi_n
	inx
	bne fi_cnt
fi_n	stx NBANKS
	jsr tshow
fi_chk	ldx #8			; any failed test: the doom, and the codes of the
fi_lp	lda BADMASK,x		; ROMs and the RAM (report.asm)
	bne fi_bad
	dex
	bne fi_lp
	ldx #0			; none failed: did every one run?
fi_rn	ldy ttests,x
	beq fi_all
	lda bitn-1,y
	and MRUN
	beq partial
	inx
	bne fi_rn
fi_all
	.ifdef SKIPKEY
	lda SKIPRAM		; (the RAM test, skipped with S)
	bne partial
	.endif
	jmp pass		; all passed: the charge, twice
fi_bad	jmp report

; partial: none failed, but not every test ran: steady yellow and one chirp
; (the start-up one: boot.asm), then it waits (a press: CONTVEC).
partial	jsr arm
	lda #C_YELLOW
	sta COLBK
	lda #AUD_ON
	sta AUDC1
	ldx #80
pc_step	stx AUDF1
	ldy #40
pc_line	sta WSYNC
	dey
	bne pc_line
	dex
	cpx #20
	bne pc_step
	lda #AUD_OFF
	sta AUDC1
pt_lp	lda #50
	sta RCNT
	lda #C_YELLOW
	sta HOLDC
	NCALL RET1, hold
	jmp pt_lp
	.endif

	.ifdef MENU
; ---------------------------------------------------------------------------
; The test menu (16k and 32k+ tapes): every test on the tape with its state, then
; ALL (every test in order) and the results. START runs the highlighted
; line, SELECT moves down, OPTION up; keys 1-7 run that test. After a test
; it comes back here with the next one highlighted, so START, START...
; walks the tests forward. It waits as long as it takes: no timeouts.
MSEL	= BSS+$EE		; highlighted line: a ttests index, MNT = ALL,
				; MNT+1 = the results
MMODE	= BSS+$EF		; nonzero: running all of them in order
MNT	= BSS+$F3		; tests on the tape
	.ifdef RAMAGAIN		; the first test's row: under the RAM line (0)
MROW0	= 5
	.else
MROW0	= 4
	.endif

menu	lda #0
	sta MMODE
	lda #C_BLACK		; a steady border, whatever the last test left
	sta COLBK
	jsr mdraw
mn_rel	jsr waitrel
mn_lp	jsr vsync
	lda CONSOL
	eor #7
	and #7
	bne mn_con
	lda SKSTAT		; a key: 1-7 runs that test
	and #4
	bne mn_lp
	lda KBCODE
	and #$3F
	.ifdef RAMAGAIN
	cmp #$32		; 0: the RAM test again (the 32k+ tape: tape 1's
	bne mn_n0		; code is still here, intact; it comes back here)
	jsr waitrel
	jmp ramrun
mn_n0
	.endif
	cmp #$35		; 8: the results
	bne mn_n8
	ldx MNT
	inx
	stx MSEL
	jmp mgo
mn_n8
	.ifdef LONGT
	cmp #$30		; 9: the long memory test
	bne mn_n9
	jsr waitrel
	jmp golong
mn_n9
	.endif
	ldx #6
mn_dig	cmp kdigit,x
	beq mn_d
	dex
	bpl mn_dig
	bmi mn_lp
mn_d	inx			; test number X: its line, if it is on the tape
	txa
	ldx MNT
mn_fd	dex
	bmi mn_lp
	cmp ttests,x
	bne mn_fd
	stx MSEL
	jmp mgo
mn_con	lsr
	bcs mgo			; START
	lsr
	bcc mn_up
	ldx MNT			; SELECT: down (the last line is MNT+1, the
	inx			; results; then the long memory test and the RAM
	.ifdef RAMAGAIN		; test, where the tape has them), round to the top
	inx
	.endif
	.ifdef LONGT
	inx
	.endif
	stx MTMP
	ldx MSEL
	cpx MTMP
	inx
	bcc mn_set
	ldx #0
	beq mn_set
mn_up	ldx MSEL		; OPTION: up, round to the bottom
	dex
	bpl mn_set
	ldx MNT
	inx
	.ifdef RAMAGAIN
	inx
	.endif
	.ifdef LONGT
	inx
	.endif
mn_set	stx MSEL
	jsr mlines		; just the lines: no blanking, no flicker
	jmp mn_rel

; mgo: run the highlighted line: a test, all of them, or the results.
mgo	jsr waitrel
	lda #0			; (a pass goes on by itself again)
	sta ENDING
	lda MSEL
	cmp MNT
	bcc mr_t
	beq mr_all
	.ifdef RAMAGAIN
	sbc MNT			; (carry set) 1: the results, then (the
	.ifdef LONGT		; cartridge) 2: the long memory test; last:
	cmp #2			; the RAM test
	bne mg_r
	jmp golong
mg_r	cmp #3
	.else
	cmp #2
	.endif
	bne mg_fin
	jmp ramrun
mg_fin
	.endif
	jmp final
mr_all	inc MMODE		; all, from the first: every result starts clean
	ldx #7			; (not test 8, the RAM stages' result)
	lda #0
	sta MRUN
ma_cl	sta BADMASK,x
	dex
	bne ma_cl
	beq mr_go
mr_t	tax			; one test: its old result goes (a run after a
	ldy ttests,x		; fail must be able to pass)
	lda #0
	sta BADMASK,y
	txa
mr_go	asl
	sta TIDX
	jsr tnextv
	jmp (NEXTVEC)

	.ifdef RAMAGAIN
; ramrun: the RAM test again. It uses BADMASK 1-8 for its banks, so the
; tests' results (BADMASK 1-7) wait in STASH: the RAM stages leave BSS
; $E0-$F3 alone, and put them back on the way to the menu (KEEP).
ramrun	ldx #7
ra_st	lda BADMASK,x
	sta STASH-1,x
	dex
	bne ra_st
	inc KEEP
	jmp RAMAGAIN
	.endif

	.ifdef LONGT
; golong: the long memory test (it copies itself to RAM: 16K or more).
golong	lda RAMTOP
	cmp #$40
	bcs gl_ok
	jmp menu
gl_ok	jmp xmem
	.endif

; mdraw: the menu screen.
mdraw	jsr scr_on
	lda #<s_hmenu
	ldy #>s_hmenu
	jsr header
	lda #2
	jsr machinfo
	PRINT 18, 0, s_m1
	PRINT 19, 0, s_m2
; mlines: the menu's lines, the highlighted one in inverse (over the old).
mlines	ldx #0
md_lp	stx CNT
	lda #0			; the highlighted line in inverse
	cpx MSEL
	bne md_inv
	lda #$80
md_inv	sta INV
	txa
	clc
	adc #MROW0
	ldx #0
	jsr at
	lda #0
	jsr putc
	ldx CNT
	lda ttests,x
	beq md_res
	asl
	tax
	lda tnames-2,x
	ldy tnames-1,x
	jsr puts
	lda CNT			; its state at column 20
	clc
	adc #MROW0
	ldx #20
	jsr at
	ldx CNT
	ldy ttests,x
	lda bitn-1,y
	and MRUN
	bne md_ran
	lda #<s_notrun
	ldy #>s_notrun
	jsr puts
	jmp md_nx
md_ran	lda BADMASK,y
	bne md_f
	lda #<s_pass
	ldy #>s_pass
	jsr puts
	jmp md_nx
md_f	pha
	lda #<s_fail
	ldy #>s_fail
	jsr puts
	pla
	jsr putitems
md_nx	ldx CNT
	inx
	bne md_lp
md_res	lda #<s_mall		; then ALL and the results
	ldy #>s_mall
	jsr puts
	lda #0
	sta INV
	ldx MNT
	inx
	cpx MSEL
	bne md_r
	lda #$80
	sta INV
md_r	txa
	clc
	adc #MROW0
	ldx #0
	jsr at
	lda #0
	jsr putc
	lda #<s_mres
	ldy #>s_mres
	jsr puts
	.ifdef LONGT		; the cartridge: the long memory test, as key 8
	lda #0
	sta INV
	ldx MNT
	inx
	inx
	cpx MSEL
	bne md_l
	lda #$80
	sta INV
md_l	txa
	clc
	adc #MROW0
	ldx #0
	jsr at
	lda #0
	jsr putc
	lda #<s_mlong
	ldy #>s_mlong
	jsr puts
	lda #0
	sta INV
	lda RAMTOP
	cmp #$40
	bcs md_lx
	lda MNT
	clc
	adc #MROW0+2
	ldx #20
	jsr at
	lda #<s_m16
	ldy #>s_m16
	jsr puts
md_lx
	.endif
	.ifdef RAMAGAIN		; the 32k+ tape: the RAM test too, as key 0,
	lda #0			; with its result so far (test 8)
	sta INV
	ldx MNT
	inx
	inx
	.ifdef LONGT
	inx
	.endif
	cpx MSEL
	bne md_g
	lda #$80
	sta INV
md_g	lda #4			; (the top line; SELECT reaches it from the
	ldx #0			; bottom, OPTION from the first test)
	jsr at
	lda #0
	jsr putc
	lda #<s_mram
	ldy #>s_mram
	jsr puts
	lda #0
	sta INV
	lda #4
	ldx #20
	jsr at
	.ifdef SKIPKEY
	lda SKIPRAM
	beq md_gr
	lda #<s_skipd
	ldy #>s_skipd
	jsr puts
	jmp md_gx
md_gr
	.endif
	lda BADMASK+8
	bne md_gf
	lda #<s_pass
	ldy #>s_pass
	jsr puts
	jmp md_gx
md_gf	pha
	lda #<s_fail
	ldy #>s_fail
	jsr puts
	pla
	jsr putitems
md_gx
	.endif
	lda #0
	sta INV
	rts

kdigit	.byte $1F, $1E, $1A, $18, $1D, $1B, $33	; KBCODEs of 1-7
s_hmenu	dta d'MENU',$FF
s_notrun dta d'-',$FF
s_mall	dta d'ALL OF THEM, IN ORDER',$FF
s_mres	dta d'8 RESULTS AND THE FINAL CODE',$FF
s_m1	dta d'START=RUN  SELECT=DOWN  OPTION=UP',$FF
	.ifdef LONGT
s_m2	dta d'OR PRESS 0-9 FOR THAT LINE',$FF
s_mram	dta d'0 RAM',$FF
s_mlong	dta d'9 LONG RAM TEST',$FF
s_m16	dta d'NEEDS 16K',$FF
	.elseif .def RAMAGAIN
s_m2	dta d'OR PRESS 0-8 FOR THAT LINE',$FF
s_mram	dta d'0 RAM',$FF
	.else
s_m2	dta d'OR PRESS 1-8 FOR THAT LINE',$FF
	.endif
s_toggle3 dta d'T=TONES  ANY KEY=MENU',$FF
s_mpass	dta d'MENU IN 2 S',$FF
	.endif

	.ifdef MENU
; results: every test on the tape, PASS or FAIL and its items, then the ROM
; names if test 1 ran.
	.ifdef RAM8		; the first test's row: under the RAM line (0)
RZROW0	= 5
	.else
RZROW0	= 4
	.endif
results	jsr scr_on
	lda #<s_hres
	ldy #>s_hres
	jsr header
	lda #2
	jsr machinfo
	ldx #0
rz_lp	stx CNT
	lda ttests,x
	beq rz_end
	txa
	clc
	adc #RZROW0
	ldx #0
	jsr at
	ldx CNT
	lda ttests,x
	asl
	tax
	lda tnames-2,x
	ldy tnames-1,x
	jsr puts
	lda CNT
	clc
	adc #RZROW0
	ldx #18			; status at column 18
	jsr at
	ldx CNT
	ldy ttests,x
	.ifdef MENU
	lda bitn-1,y		; not run (from the menu)
	and MRUN
	bne rz_ran
	lda #<s_notrun
	ldy #>s_notrun
	jsr puts
	jmp rz_n
rz_ran
	.endif
	lda BADMASK,y
	bne rz_f
	lda #<s_pass
	ldy #>s_pass
	jsr puts
	jmp rz_n
rz_f	pha
	lda #<s_fail
	ldy #>s_fail
	jsr puts
	pla
	jsr putitems
rz_n	ldx CNT
	inx
	bne rz_lp
rz_end	.ifdef RAM8
	lda #4			; the 32k+ tape: RAM from stages 1-2, as test 0,
	ldx #0			; on top
	jsr at
	lda #<s_t8
	ldy #>s_t8
	jsr puts
	lda #4
	ldx #18
	jsr at
	.ifdef SKIPKEY
	lda SKIPRAM
	beq rz_rr
	lda #<s_skipd
	ldy #>s_skipd
	jsr puts
	jmp rz_rd
rz_rr
	.endif
	lda BADMASK+8
	bne rz_rf
	lda #<s_pass
	ldy #>s_pass
	jsr puts
	jmp rz_rd
rz_rf	pha
	lda #<s_fail
	ldy #>s_fail
	jsr puts
	pla
	jsr putitems
rz_rd	inc CNT
	.endif
	.ifdef WANT_ROM
	lda CNT
	clc
	adc #5
	jsr rominfo
	.endif
	PRINT 18, 0, s_items2
	PRINT 23, 0, s_toggle3	; START: back to the menu
	rts
s_items2 dta d'NUMBERS AFTER FAIL = FAILED ITEMS',$FF
s_hres	dta d'RESULTS',$FF
	.endif

bitn	.byte 1, 2, 4, 8, 16, 32, 64, 128

	.ifdef WANT_GTIA	; (test 7)
; gans: the answer: A = 1 yes (Y, START), 2 no (N, SELECT), 0 none (Z set).
gans	lda SKSTAT
	and #4
	bne ga_c
	lda KBCODE
	and #$3F
	cmp #$2B		; Y
	beq ga_y
	cmp #$23		; N
	beq ga_n
ga_c	lda CONSOL
	lsr
	bcc ga_y		; START
	lsr
	bcc ga_n		; SELECT
	lda #0
	rts
ga_y	lda #1
	rts
ga_n	lda #2
	rts

; gwave: A = 0-63, a point on the wave -> A = 4 + 4 sin, 0-8. The table is
; a quarter of it (gqsin, 16 steps); the rest by symmetry: the second
; quarter backwards, the second half below the middle. Keeps X.
gwave	pha
	and #15
	tay
	pla
	pha
	and #16
	beq gw_q
	tya			; the second and fourth quarters: backwards
	eor #15
	tay
gw_q	pla
	and #32
	beq gw_up
	lda gqsin,y		; the second half: 4 - it
	eor #$FF
	clc
	adc #5
	rts
gw_up	lda gqsin,y		; the first half: 4 + it
	clc
	adc #4
	rts

gqsin	.byte 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 4	; 4 sin, a quarter
s_gq	dta d'LOOKS RIGHT? Y/START=YES, N/SELECT=NO',$FF
	.endif


; tnames: the tests' names (a tape without a menu: only its own; the menu
; lists them all).
tnames	.word s_t1, s_t2, s_t3, s_tjoy, s_tpad, s_tpok, s_t7
	.ifdef WANT_ROM
s_t1	dta d'1 ROMS',$FF
	.elseif .def MENU
s_t1	dta d'1 ROMS',$FF
	.else
s_t1	= 0
	.endif
	.ifdef WANT_KB
s_t2	dta d'2 KEYBOARD',$FF
	.elseif .def MENU
s_t2	dta d'2 KEYBOARD',$FF
	.else
s_t2	= 0
	.endif
	.ifdef WANT_CON
s_t3	dta d'3 CONSOLE KEYS',$FF
	.elseif .def MENU
s_t3	dta d'3 CONSOLE KEYS',$FF
	.else
s_t3	= 0
	.endif
	.ifdef WANT_JOY
s_tjoy	dta d'4 JOYSTICKS',$FF
	.elseif .def MENU
s_tjoy	dta d'4 JOYSTICKS',$FF
	.else
s_tjoy	= 0
	.endif
	.ifdef WANT_PAD
s_tpad	dta d'5 PADDLES',$FF
	.elseif .def MENU
s_tpad	dta d'5 PADDLES',$FF
	.else
s_tpad	= 0
	.endif
	.ifdef WANT_SND
s_tpok	dta d'6 POKEY: HELLO',$FF
	.elseif .def WANT_POK
s_tpok	dta d'6 POKEY',$FF
	.elseif .def MENU
s_tpok	dta d'6 POKEY',$FF
	.else
s_tpok	= 0
	.endif
	.ifdef WANT_GTIA
s_t7	dta d'7 GTIA/ANTIC',$FF
	.elseif .def MENU
s_t7	dta d'7 GTIA/ANTIC',$FF
	.else
s_t7	= 0
	.endif
	.ifdef RAM8
s_t8	dta d'0 RAM, BANKS',$FF
	.endif
	.ifdef SKIPKEY
s_skipd	dta d'SKIPPED',$FF
	.elseif .not .def MENU
s_skipd	dta d'SKIPPED',$FF
	.endif
s_test	dta d'TEST ',$FF
s_pass	dta d'PASS',$FF
s_fail	dta d'FAIL'*,$FF
s_items	dta d', ITEMS',$FF
s_tpass	dta d'NEXT TEST IN 2 S',$FF
s_goon	dta d'T=TONES  ANY KEY=GO ON',$FF
	.ifdef NEEDYN
s_heard	dta d'HEARD IT? Y/START=YES, N/SELECT=NO',$FF
	.endif
	.ifndef MENU
; s_next: the end of a tape without a menu: what to load next.
	.if SETNO=0
	.if TAPENO=6
s_next	dta d'DONE. LAST 8K TAPE',$FF
	.else
	.if TAPENO=2
s_next	dta d'DONE. R=RETEST. NEXT: DIAG-8K-0',[TAPENO+$11]
	.else
s_next	dta d'DONE. NEXT: DIAG-8K-0',[TAPENO+$11]
	.endif
	.if TAPENO=2
	dta d'-INPUT',$FF
	.elseif TAPENO=3
	dta d'-PORTS',$FF
	.elseif TAPENO=4
	dta d'-SOUND',$FF
	.else
	dta d'-VIDEO',$FF
	.endif
	.endif
	.elseif SETNO=1
s_next	dta d'DONE. LAST 16K TAPE',$FF
	.else
s_next	dta d'DONE',$FF
	.endif
	.endif
