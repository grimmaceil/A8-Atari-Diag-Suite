; A8 DIAG system tapes: one boot stage that runs a list of tests. build.py
; picks the tests with WANT_* defines, and SETNO/TAPENO for the header:
;   1 ROMs (WANT_ROM)            identified by CRC32 against published tables
;   2 keyboard (WANT_KB)         stuck keys, then a map with three key states
;   3 console keys (WANT_CON)    START, SELECT, OPTION and the console speaker
;   4 joysticks (WANT_JOY)       live, per port
;   5 paddles (WANT_PAD)         open-input check, then live values
;   6 POKEY (WANT_POK)           timer IRQ, RANDOM, the voices and noise by ear
;     or (WANT_SND, the 16k hello tape) the sampled "hello" only
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
	icl '../common/defs.asm'
	.ifdef CHAIN		; part of a one-load image: tape 1's library
SHLIB	= 1			; (lib.asm)
	.endif

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
	.ifdef ROM		; common.asm: the long memory test on the menu (9):
LONGT	= 1			; the cartridge, and the disk file, which carries
	.elseif .def XEX	; its image behind the system tests (MEMAT)
LONGT	= 1
xmem	= ldmem
	.endif
	.ifdef WANT_POK		; cart/hello.asm: sampled sound, where there is
	.ifdef ROM		; room: the cartridge and the disk file, and the
SAMPLED	= 1			; 8k hello tape (WANT_SND)
	.elseif .def XEX
SAMPLED	= 1
	.endif
	.elseif .def WANT_SND
SAMPLED	= 1
	.endif
	.ifdef WANT_CON		; common.asm: the tests that ask Y/N
NEEDYN	= 1
	.elseif .def WANT_POK
NEEDYN	= 1
	.elseif .def WANT_GTIA
NEEDYN	= 1
	.endif
	.ifdef WANT_ROM		; the ROM test checks this program's own copy too
	.ifndef ROM		; (t_rom.asm's selfchk): a tape or disk file on its
	.ifndef CHAIN		; own ends in CRCFIX (mkcas.py), from CRCAT = LOAD;
SELFCRC	= 1			; the 32k+ image's comes from tape 1 (build.py)
SELFAT	= LOAD
SELFPG	= [IMGEND-LOAD]/256
CRCAT	= LOAD
	.endif
	.endif
	.endif
	.ifdef GPART2		; the 8K sound and video tape: test 7's page 2 is
SYSPART	= 1			; the tape's part two (gpart2.asm), loaded over
NORAMCHK = 1			; the tests already run (common/loader.asm)
LDTO	= P2AT
	.endif
	.ifndef WANT_ROM
NOFONT	= 1			; display.asm, info.asm: only the ROM test shows
	.endif			; the font's sum (the 8k tapes are short of room)

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
	lda #<tshow		; (report.asm: OPTION's screen; and SYSMODE,
	sta REDRAWV		; a code only for the ROMs and the RAM)
	lda #>tshow
	sta REDRAWV+1
	sta SYSMODE		; (nonzero)
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
	lda KEEP		; the RAM test again, from the menu: the tests'
	beq ch_nk		; results back (common.asm's ramagain)
	ldx #7
ch_kp	lda STASH-1,x		; (KEEP stays set: trun goes to the menu)
	sta BADMASK,x
	dex
	bne ch_kp
ch_nk
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
	.elseif .def WANT_SND
	.word t_snd
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
	.elseif .def WANT_SND
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
TESTBEG
P2AT	= [[TESTBEG+$FF]/$100]*$100	; (GPART2: part two loads here)

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
	.elseif .def WANT_SND
; t_snd: test 6, the sampled "hello" only (the 16k hello tape: the rest of
; the POKEY test is on the system tapes). Item 7 as in the full test.
t_snd	lda #6
	sta TEST
	lda #<s_tpok
	ldy #>s_tpok
	jsr tpage
	jsr hello
	jmp tend
	.endif
	.ifdef WANT_GTIA
	icl 't_gtia.asm'
	.endif

	.ifdef ROM		; (no boot here: bank 0 did it)
	icl '../cart/romsum.asm'
	.ifdef HASLDR
	icl '../cart/ldmem.asm'
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
TESTEND				; (GPART2: part two may reach here: the tests and
				; the boot's own code are done with by then)

	.ifdef SHLIB
	icl '../../build/shlib.asm'	; the library's addresses (tape 1's part)
	.else
NORAMT	= 1			; (no RAM test here)
	icl '../common/lib.asm'
	.endif
	icl 'common.asm'
	.ifdef SAMPLED
	icl '../cart/hello.asm'
	.endif
	.ifdef XEX
	icl '../cart/ldmem.asm'
	.endif
	.ifdef GPART2
	icl '../common/loader.asm'
	.endif

	.ifdef ROM
	.if *>$BFE0
	.error "this cartridge bank is over 8K (the tail starts at $BFE0)"
	.endif
IMGEND
BSS	= $0800			; in RAM, shared by the banks
TSTART	= [>BSS]+1
	.else
	.ifndef CHAIN		; (the one-load image: no pages of its own, so the
				; disk file needs no more than 32K)
; Pad to a whole page; the last two bytes hold the image sum (mkcas.py),
; or (SELFCRC) the last six: the sum, then CRCFIX.
	.ifdef SELFCRC
TAILN	= 6
	.else
TAILN	= 2
	.endif
PADTO	= [[*+TAILN+$FF]/$100]*$100
	.if PADTO-*-TAILN>0
	:[PADTO-*-TAILN] .byte 0
	.endif
CKSUM	.word 0			; (as stage 3: the loader's plain sum)
	.ifdef SELFCRC
CRCFIX	.dword 0
	.endif
	.endif
IMGEND
NREC	= [IMGEND-LOAD]/128
	.ifdef SHAREBSS
BSS	= SHAREBSS		; one image: tape 1's BSS page is this one's
	.else
BSS	= IMGEND
	.endif
TSTART	= [>BSS]+1
	.endif
