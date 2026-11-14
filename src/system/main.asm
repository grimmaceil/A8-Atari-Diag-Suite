; A8 DIAG system tapes: one boot stage that runs a list of tests. build.py
; picks the tests with WANT_* defines, and SETNO/TAPENO for the header:
;   1 ROMs (WANT_ROM)            identified by CRC32 against published tables
;   2 keyboard (WANT_KB)         stuck keys, then a map with three key states
;   3 console keys (WANT_CON)    START, SELECT, OPTION and the console speaker
;   4 joysticks (WANT_JOY)       live, per port
;   5 paddles (WANT_PAD)         open-input check, then live values
;   6 POKEY (WANT_POK)           timer IRQ, RANDOM, the voices and noise by ear
;   7 GTIA (WANT_GTIA)           ramps and sprites by eye
; They run in that order (progressive: the Y/N answers later tests ask for
; come from the keyboard and console keys tested before them), and the menu
; lists them by number (0 is the RAM test, on the 32k+ image). The numbers
; are the same on every tape, disk file and the cartridge.
;
; Boots like the other tapes (alive, image checksum, low RAM, size probe,
; machine, display prerequisites). The screen block gets a quick test only:
; tape 1 tests RAM. The image must fit an 8K 400 (display.asm checks).
;
; A test that passes plays the jingle and goes on by itself (~2 s). One that
; fails shows which items failed, with one low tone, and waits for START, a
; key or fire. Only the ROM test also plays a code (one long tone, then
; item = short tones); OPTION switches to full-screen flashes. After the
; last test, the tape's results; the final code is for ROM and RAM faults.
;
; CHAIN (the 32k+ tape): not a boot file but part of tape 1's image, at
; SYSAT, entered by its stage 2. It takes over stage 2's results; their RAM
; faults become test 8, item = bank, on the results screen and in the final
; code. Built with -d:PREVBSS=... (stage 2's BSS).
;
; ROM (the cartridge): one of its code banks (cart/romsum.asm), running at
; $A000 with BSS at $0800. The seven tests are split over two banks (the
; WANT_* defines say which are in this one); the menu is in both and lists
; all seven. A test in the other bank is a thunk that asks for it (XREQ)
; and switches to that bank (OTHER), whose warm entry runs it. HASLDR: this
; bank holds the long memory test's loader (cart/ldmem.asm).

	icl '../common/hw.asm'
	icl '../common/vars.asm'
	icl '../common/faults.asm'

QUICKSCR = 1			; display.asm: quick screen-block test
RESTART	= 1			; report.asm: the end waits for START (see final)
SYSCODES = 1			; report.asm: beep codes for the ROMs (test 1) and
				; the RAM (index 8) only, each with its own tones
	.ifdef CHAIN		; common.asm: the RAM's result is here too, as
RAM8	= 1			; test 0 (kept at index 8)
	.elseif .def ROM
RAM8	= 1
RAMAGAIN = xram			; and the RAM test again is in bank 0
	.endif
	.ifdef ROM		; common.asm: the RAM test can be skipped (CTRL+S,
SKIPKEY	= 1			; tape1/main.asm): its line says so
	.endif
	.ifdef WANT_CON		; common.asm: the tests that ask Y/N
NEEDYN	= 1
	.elseif .def WANT_POK
NEEDYN	= 1
	.elseif .def WANT_GTIA
NEEDYN	= 1
	.endif
	.ifndef WANT_ROM
NOFONT	= 1			; display.asm, info.asm: only the ROM test shows
	.endif			; the font's sum (the 400 tapes are short of room)

	opt h-
	.if .def ROM
LOAD	= $A000
	.elseif .def SYSAT
LOAD	= SYSAT			; the 32k+ one-load tape: in tape 1's image,
				; after its stage 2 (build.py's build_one32)
	.else
LOAD	= $0800
	.endif
	org LOAD

	.ifdef ROM
	jmp $BFE0		; power-on in this bank: on to bank 0 (the tail)
	jmp warm
; warm: from another bank. This bank's checksum, then what was asked for.
warm	sei
	cld
	ldx #$FF
	txs
	jsr romsum
	beq wm_ok
	inc LOADERR
	jmp report
wm_ok	lda DISPOK		; (START at the RAM summary: the picture is seen)
	sta VIDEOOK
	lda XREQ
	bne wm_t
	jmp trun		; 0: the menu
wm_t
	.ifdef HASLDR
	cmp #8			; 8: the long memory test
	bne wm_f
	jmp ldmem
wm_f
	.endif
	.ifdef WANT_ROM
	cmp #9			; 9: the results (this bank has the ROM names)
	bne wm_r
	jsr tinit
	jmp final
wm_r
	.endif
	pha			; 1-7: that test (it is in this bank)
	jsr tinit
	pla
	ldx #0
wm_fd	cmp ttests,x
	beq wm_go
	inx
	bne wm_fd
wm_go	txa
	asl
	sta TIDX
	jsr tnextv
	jmp (NEXTVEC)

; The other bank's tests, the RAM test (bank 0) and the long memory test.
xgo	sta XREQ
	ldx #OTHER
	jmp XBANK
xram	ldx #0
	jmp XBANK
	.ifndef WANT_ROM	; the results are the ROM test's bank's
XFINAL	= 1
final	lda #9
	bne xgo
	.endif
	.ifdef HASLDR
xmem	= ldmem
	.else
xmem	lda #8
	bne xgo
	.endif
	.ifndef WANT_ROM
xt1	lda #1
	bne xgo
	.endif
	.ifndef WANT_KB
xt2	lda #2
	bne xgo
	.endif
	.ifndef WANT_CON
xt3	lda #3
	bne xgo
	.endif
	.ifndef WANT_JOY
xt4	lda #4
	bne xgo
	.endif
	.ifndef WANT_PAD
xt5	lda #5
	bne xgo
	.endif
	.ifndef WANT_POK
xt6	lda #6
	bne xgo
	.endif
	.ifndef WANT_GTIA
xt7	lda #7
	bne xgo
	.endif
	.elseif .def CHAIN
; Same header layout as a boot file: the loader checks the record count and
; load address, then jumps to LOAD+6.
	.byte 0
	.byte NREC
	.word LOAD
	.word 0

	sei
	cld
	ldx #$FF
	txs
	ldx #0			; take over stage 2's results
ch_tk	lda PREVBSS,x
	sta BSS,x
	inx
	bne ch_tk
	lda #0			; RAM faults (banks 1-8; the loader area is
	sta MTMP		; bank 1) into test 8, item = bank
	ldx #8
ch_rm	lda BADMASK,x
	beq ch_rn
	lda bitn-1,x
	ora MTMP
	sta MTMP
	lda #0
	sta BADMASK,x
ch_rn	dex
	bne ch_rm
	lda BADMASK+LDRIDX
	beq ch_r9
	lda #1
	ora MTMP
	sta MTMP
	lda #0
	sta BADMASK+LDRIDX
ch_r9	lda MTMP
	sta BADMASK+8
	lda DISPOK		; START at the summary: someone sees the picture
	sta VIDEOOK
	jmp trun
	.else
; Cassette boot header. The OS reads NREC records to LOAD, then JSRs LOAD+6.
	.byte 0
	.byte NREC
	.word LOAD
	.word init_rts

	icl '../common/boot.asm'

	jsr dprereq
	lda DISPOK		; no video check on this tape: the display checks
	sta VIDEOOK		; passing counts as the picture confirmed
	jmp trun
	.endif

; The tests, in running order, then final. ttests: their numbers, 0 ends.
tlist
	.ifdef WANT_ROM
	.word t_rom
	.elseif .def ROM
	.word xt1
	.endif
	.ifdef WANT_KB
	.word t_kb
	.elseif .def ROM
	.word xt2
	.endif
	.ifdef WANT_CON
	.word t_con
	.elseif .def ROM
	.word xt3
	.endif
	.ifdef WANT_JOY
	.word t_joy
	.elseif .def ROM
	.word xt4
	.endif
	.ifdef WANT_PAD
	.word t_pad
	.elseif .def ROM
	.word xt5
	.endif
	.ifdef WANT_POK
	.word t_pok
	.elseif .def ROM
	.word xt6
	.endif
	.ifdef WANT_GTIA
	.word t_gtia
	.elseif .def ROM
	.word xt7
	.endif
	.word final

ttests
	.ifdef WANT_ROM
	.byte 1
	.elseif .def ROM
	.byte 1
	.endif
	.ifdef WANT_KB
	.byte 2
	.elseif .def ROM
	.byte 2
	.endif
	.ifdef WANT_CON
	.byte 3
	.elseif .def ROM
	.byte 3
	.endif
	.ifdef WANT_JOY
	.byte 4
	.elseif .def ROM
	.byte 4
	.endif
	.ifdef WANT_PAD
	.byte 5
	.elseif .def ROM
	.byte 5
	.endif
	.ifdef WANT_POK
	.byte 6
	.elseif .def ROM
	.byte 6
	.endif
	.ifdef WANT_GTIA
	.byte 7
	.elseif .def ROM
	.byte 7
	.endif
	.byte 0

	.ifdef WANT_ROM
	icl 't_rom.asm'
	.endif
	.ifdef WANT_KB
	icl 't_kb.asm'
	.endif
	.ifdef WANT_CON
	icl 't_con.asm'
	.endif
	.ifdef WANT_JOY
	icl 't_joy.asm'
	.endif
	.ifdef WANT_PAD
	icl 't_pad.asm'
	.endif
	.ifdef WANT_POK
	icl 't_pok.asm'
	.endif
	.ifdef WANT_GTIA
	icl 't_gtia.asm'
	.endif

	.ifdef ROM		; (no boot here: bank 0 did it)
	icl '../cart/romsum.asm'
	.ifdef HASLDR
	icl '../cart/ldmem.asm'
	.endif
	.ifdef WANT_POK
	icl '../cart/hello.asm'
	.endif
	.elseif .not .def CHAIN
	icl '../common/display.asm'

init_rts rts

; Low-RAM patterns: solid, checkerboard, walking 1, walking 0.
pats	.byte $00,$FF,$55,$AA
	.byte $01,$02,$04,$08,$10,$20,$40,$80
	.byte $FE,$FD,$FB,$F7,$EF,$DF,$BF,$7F
NPAT	= *-pats
	.endif

	icl '../common/report.asm'
	icl '../common/screen.asm'
	icl '../common/info.asm'
	icl 'common.asm'

; The header bar names the tape, as its file is named (SETNO 0 = the 400
; set, 1 = 16K, 3 = controls, 4 = 32k+), so it can't
; be taken for the machine found: that is the FOUND line below it.
	.if .def ROM
s_hpre	dta d' DIAG-CART  ',$FF
	.elseif SETNO=4
	.ifdef XEX			; the disk file (build.py)
s_hpre	dta d' DIAG-32K-XEX  ',$FF
	.elseif .def CART		; the cartridge (build.py)
s_hpre	dta d' DIAG-32K-CART  ',$FF
	.else
s_hpre	dta d' DIAG-32K-XL-XE  ',$FF
	.endif
	.elseif SETNO=3
s_hpre	dta d' DIAG-CONTROLS  ',$FF
	.elseif SETNO=1
s_hpre	dta d' DIAG-16K-02-SYSTEM  ',$FF
	.else
s_hpre	dta d' DIAG-400-0',[TAPENO+$10]
	.if TAPENO=2
	dta d'-ROM  ',$FF
	.elseif TAPENO=3
	dta d'-INPUT  ',$FF
	.elseif TAPENO=4
	dta d'-PORTS  ',$FF
	.else
	dta d'-AV  ',$FF
	.endif
	.endif

	.ifdef ROM
	.if *>$BFE0
	.error "this cartridge bank is over 8K (the tail starts at $BFE0)"
	.endif
IMGEND
BSS	= $0800			; in RAM, shared by the banks
TSTART	= [>BSS]+1
	.else
; Pad to a whole page; the last two bytes hold the image sum (mkcas.py).
PADTO	= [[*+2+$FF]/$100]*$100
	.if PADTO-*-2>0
	:[PADTO-*-2] .byte 0
	.endif
CKSUM	.word 0			; (as stage 3: the loader's plain sum)
IMGEND
NREC	= [IMGEND-LOAD]/128
	.ifdef SHAREBSS
BSS	= SHAREBSS		; one image: tape 1's BSS page is this one's
	.else
BSS	= IMGEND
	.endif
TSTART	= [>BSS]+1
	.endif
