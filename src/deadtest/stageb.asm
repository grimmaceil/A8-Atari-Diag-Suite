; Stage B: the RAM test with no RAM, $0000-$9FFF (the cartridge covers
; $A000-$BFFF). Nothing here reads or writes RAM but the bytes under test,
; and nothing uses the stack, zero page or the OS ROM (tools/deadtest.py
; --static checks SBBEG-SBEND): the CPU's registers, the V flag, and the
; PIA's direction registers hold everything.
;
; Two passes (V clear, then set). Pass 0 writes byte X of page P with X EOR
; P, pages in rising order; pass 1 X EOR P EOR $FF, pages in falling order.
; Every bit is seen as 0 and as 1; a byte's own address bits catch faults
; inside a page; the page number catches pages that answer for each other,
; and since a pass writes all 160 pages before any is read back, in both
; orders, both pages of such a pair read wrong (the one written last wins
; in each pass). Then each byte is read back: (read EOR expected) ORed into
; its bank's mask. One X loop per block, its body unrolled across the
; pages: without RAM there is no pointer, so every page needs its own
; instructions.
;
; The results (the plan's results interface, kept until the hand-over;
; PACTL/PBCTL bit 2 = 0, so $D300/$D301 are the direction registers):
;   DDRA  bank 1's bad bits ($0000-$3FFF)
;   DDRB  bank 2's ($4000-$7FFF)
;   S     bank 3's ($8000-$9FFF)
;   PACTL bit 0 = 1: zero page bad; PBCTL bit 0 = 1: the stack page bad
; A mask of $FF: no RAM there (nothing reads back). S can only take a whole
; byte while X is free, so bank 3 is done first (both passes, into DDRA),
; moved to S, and banks 2 and 1 follow (two more passes). Bank 1's upper 8K
; ($2000-$3FFF) is checked with bank 3, into DDRB: when nothing answers
; there it is left out (an 8K machine, or a hole: main.asm's sbdone tells
; them apart), else its bad bits start bank 1's mask. ORA and ORB are
; $FF first, so a direction register's bits change nothing outside: an
; output driving 1 is what an input pulled up reads (on the XL/XE PORTB
; stays $FF: the OS in, BASIC and the self-test out, the 130XE's main RAM).
SB_CTL	= $38			; PACTL/PBCTL: the direction registers, motor off,
				; command line high; +1: zero page / stack bad

; WRITE lo, hi: A = the pass's value for byte X; each page lo to hi-1, in
; rising order, gets it EOR the page number.
.macro WRITE
	eor #:1
	.rept :2-:1
	sta.w $100*[:1+.r],x
	eor #[[:1+.r]^[:1+.r+1]]
	.endr
.endm

; WRITED lo, hi: the same, pages hi-1 down to lo.
.macro WRITED
	eor #[:2-1]
	.rept :2-:1
	sta.w $100*[:2-1-.r],x
	eor #[[:2-1-.r]^[:2-2-.r]]
	.endr
.endm

; CHECK lo, hi, mask: each page's bad bits for byte X ORed into mask (a
; direction register); a bad zero page also sets PACTL bit 0, a bad stack
; page PBCTL bit 0. A = the pass's value for byte X; Y is used.
.macro CHECK
	eor #:1
	.rept :2-:1
	tay
	eor.w $100*[:1+.r],x
	.if [:1+.r]=0
	beq *+13
	ora :3
	sta :3
	lda #SB_CTL+1
	sta PACTL
	.elseif [:1+.r]=1
	beq *+13
	ora :3
	sta :3
	lda #SB_CTL+1
	sta PBCTL
	.else
	beq *+8
	ora :3
	sta :3
	.endif
	tya
	eor #[[:1+.r]^[:1+.r+1]]
	.endr
.endm

SBBEG
stageb	lda #$FF		; the output registers $FF (PACTL/PBCTL $3C: the
	sta PORTA		; port registers selected)
	sta PORTB
	lda #SB_CTL		; then the direction registers, cleared: the masks
	sta PACTL
	sta PBCTL
	lda #0
	sta DDRA
	sta DDRB
	clv			; pass 0
	ldy #0			; Y: what follows the writes: 0 bank 3's check,
	jmp wrall		; 1 banks 2 and 1

; wrall: every page written, rising in pass 0, falling in pass 1.
wrall	ldx #0
	bvc wa1
	jmp wd1
wa1	txa
	WRITE $00,$A0
	inx
	beq wa2
	jmp wa1
wa2	jmp wdone
wd1	txa
	eor #$FF
	WRITED $00,$A0
	inx
	beq wdone
	jmp wd1
wdone	cpy #0
	beq chk3
	jmp chk21

; chk3: bank 3, into DDRA, and bank 1's upper 8K, into DDRB; after pass 1
; bank 3's mask to S, and banks 2 and 1 begin.
chk3	ldx #0
c3a	txa
	bvc c3b
	eor #$FF
c3b	CHECK $80,$A0,DDRA
	txa
	bvc c3c
	eor #$FF
c3c	CHECK $20,$40,DDRB
	inx
	beq c3d
	jmp c3a
c3d	bvs c3s
	bit sbv40		; pass 1
	ldy #0
	jmp wrall
c3s	ldx DDRA		; bank 3's mask to S
	txs
	lda DDRB		; bank 1's upper 8K: nothing there ($FF) is left
	cmp #$FF		; out; else its bad bits start bank 1's mask
	bne c3u
	lda #0
c3u	sta DDRA
	lda #0
	sta DDRB
	clv			; pass 0 again, for banks 2 and 1
	ldy #1
	jmp wrall

; chk21: bank 2 into DDRB, bank 1's lower 8K into DDRA.
chk21	ldx #0
c21a	txa
	bvc c21b
	eor #$FF
c21b	CHECK $40,$80,DDRB
	txa
	bvc c21c
	eor #$FF
c21c	CHECK $00,$20,DDRA
	inx
	beq c21d
	jmp c21a
c21d	bvs sbfin
	bit sbv40		; pass 1
	ldy #1
	jmp wrall
sbfin
SBEND
	jmp sbdone		; (main.asm: on to the results)

sbv40	dta $40			; BIT sets V from this byte's bit 6
