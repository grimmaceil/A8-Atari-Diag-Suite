; Working storage. BSS is the page right after the loaded image: it is not
; loaded, so the image checksum does not cover it, and it is outside both the
; low-RAM test ($0000-$07FF) and the main RAM tests (which start one page
; above it). It is the only RAM the code trusts before low RAM is proven.

; No-stack return vectors (see NCALL). Page-aligned, so JMP (vec) never hits
; the 6502 $xxFF wrap bug.
RET1	= BSS+$00	; tone level
RET2	= BSS+$02	; delay level

SUM	= BSS+$04	; 2: image checksum accumulator
RTONE	= BSS+$06	; report: the long tone of the group being played
SYSMODE	= BSS+$07	; nonzero: the system tests run (report.asm, SHLIB)
REDRAWV	= BSS+$08	; 2: the screen OPTION brings back (report.asm, SHLIB)
SPKMASK	= BSS+$0A	; $08 while a beep plays: delay toggles the console speaker
SPKPH	= BSS+$0B	; current CONSOL speaker value
RCNT	= BSS+$0C	; reporter: tones left in this group
RBANK	= BSS+$0D	; reporter: bank being reported
RMASK	= BSS+$0E	; reporter: bad bits left to report
RBIT	= BSS+$0F	; reporter: bit number being examined (0-7)
LOADERR	= BSS+$10	; nonzero: the loaded image failed its checksum
NBANKS	= BSS+$11	; banks that got tested (pass report count)
RAMTOP	= BSS+$12	; first page with no RAM
MSTART	= BSS+$13	; march range, pages [MSTART, MEND)
MEND	= BSS+$14
MREAD	= BSS+$15	; expected value
MWRITE	= BSS+$16	; value to write
MFLAGS	= BSS+$17	; bit 7: skip write, bit 6: skip read
MTMP	= BSS+$18
CURBANK	= BSS+$19	; bank errors are charged to (1-4)
FMASK	= BSS+$1A	; FAULT builds: bits flipped on every read in CURBANK
P0	= BSS+$1B	; march background
P1	= BSS+$1C	; march inverse background
CNT	= BSS+$1D
AIAMODE	= BSS+$1E	; address-in-address: 0 = low byte, 1 = high byte
LXOR	= BSS+$1F
SCRPG	= BSS+$20	; first page of the 1K text screen block; 0 = none found
DISPOK	= BSS+$21	; display prerequisites passed
VIDEOOK	= BSS+$22	; user confirmed the video check screen
MACHINE	= BSS+$23	; 0 = 400/800, 1 = XL/XE
CHSUM	= BSS+$24	; 2: character ROM sum, $E000-$E3FF
CHSTAB	= BSS+$26	; nonzero: second read of the character ROM matched
VCMIN	= BSS+$27	; VCOUNT range seen
VCMAX	= BSS+$28
INAIA	= BSS+$29	; nonzero while the address test runs (merr bookkeeping)
	.ifdef XSWEEP		; the long test (tape 2, BOUNCE): one march over
RNGN	= $91		; all the RAM it reaches (ramtest.asm): count,
RNGS	= $92		; 10 start pages,
RNGE	= $9C		; 10 end pages (zero page: $91 up is free there)
XBLK	= $A6		; pages left out at the screen block: 4, or 8 with
			; the font's block while the OS is out (xlram.asm)
	.else
RNGN	= BSS+$2A	; range list (a bank minus the screen block): count,
RNGS	= BSS+$2B	; 2 start pages,
RNGE	= BSS+$2D	; 2 end pages
	.endif
RBS	= BSS+$2F	; range to split
RBE	= BSS+$30
PCY	= BSS+$31	; putc: saved Y
INV	= BSS+$32	; putc: $80 = inverse
DVAL	= BSS+$33	; 2: putdec value
RETESTV	= BSS+$35	; 2: where R in a result's pause goes (0 = nowhere): the
		; test again (report.asm's hold)
AUTON	= BSS+$37	; rounds of the code left before it goes on by itself (0 =
		; it waits for a press): the RAM test's summary where the ROM
		; test follows (report.asm, RPAUTO)
ISPAL	= BSS+$38
LEAD	= BSS+$39	; putdec: still in leading zeros
SCRERR	= BSS+$3A	; 2: error count before a screen-block test
RROW	= BSS+$3C	; results: current row
JPREV	= BSS+$3D	; joyc: the joysticks at the last look (system/common.asm)
HOLDC	= BSS+$3E	; hold: border color
SCRON	= BSS+$3F	; nonzero while the text screen is on
STACKOK	= BSS+$D0	; low RAM passed: stack/zero page usable, controls read
HARMED	= BSS+$D1	; hold: controls seen released
INB	= BSS+$D2	; inputs: result being built
CONTVEC	= BSS+$D3	; 2: where a press in the result pauses goes on to (0 = end)
BANKOVR	= BSS+$D5	; nonzero: charge address-test errors here, not by page
S2LEFT	= BSS+$D6	; stage 2 load: records left
S2PAGES	= BSS+$D7	; stage 2 size in pages
L2MSG	= BSS+$D8	; 2: why stage 2 didn't run (0 = it did / not tried)
L2STAT	= BSS+$DA	; SIO status of a failed stage 2 read
PBSAVE	= BSS+$DC	; PORTB as the OS left it (xlram.asm)
OSRAM	= BSS+$DD	; 0 = not an XL/XE, 1 = no RAM under the OS, 2 = tested
XERAM	= BSS+$DE	; nonzero: 130XE extended banks found
XEBANK	= BSS+$DF	; extended bank being tested (0-3)
TCUR	= BSS+$F8	; tone: the tone being played (its pause, after)
ENDING	= BSS+$F7	; nonzero: the end of a program: START goes on, nothing by itself;
			; 2: the final results (pass: the charge twice)
RAMK	= BSS+$F9	; all the RAM found, in K (boot.asm: for the machine line)
HSEL	= BSS+$FA	; hold: it ended on SELECT (report: play the code again)
INRT	= BSS+$FF	; nonzero: the RAM test proper runs (SKIPKEY: its march looks for S)
SKIPRAM	= BSS+$FE	; nonzero: CTRL+S skipped the first RAM test (SKIPKEY builds)
SLATCH	= BSS+$FD	; START was seen down during a delay (a tap in mid-tone counts)
QUIET	= BSS+$FB	; the picture is confirmed (VIDEOOK) and the text is on: the
			; reporter keeps the border steady and doesn't repeat (screen.asm)

; Per-bank results, 16 entries each, indexed by:
;   1-4  main RAM banks (16K each; 4 = under the XL/XE OS)
;   5-8  130XE extended banks 0-3 (reported as 5-8, as the brief has it)
;   9    the loader area (stage 2's relocate test); it is in bank 1, so
;        it is folded into bank 1 for the beep code
; Entry 0 is unused.
LDRIDX	= 9
BADMASK	= BSS+$40	; OR of every (wrote XOR read)
ECNTLO	= BSS+$50	; error count, saturates at $FFFF
ECNTHI	= BSS+$60
EADRLO	= BSS+$70	; first error: address, value written, value read
EADRHI	= BSS+$80
EWROTE	= BSS+$90
EREAD	= BSS+$A0
MBAD	= BSS+$B0	; bad bits seen by the march tests
AIABAD	= BSS+$C0	; bad bits seen by the address test

; Zero page, used only after low RAM passes.
PTR	= $80
CUR	= $82		; screen cursor
SPTR	= $84		; string pointer
