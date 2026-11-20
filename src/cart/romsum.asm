; The cartridge's bank layout and its checksum, shared by every code bank.
;
; Each code bank is a whole program at $A000-$BFDF that runs from ROM, with
; its working storage (BSS) in RAM at $0800, shared by all the banks: the
; results travel with it from bank to bank.
;   $A000  jmp cold    power-on (only bank 0's is used: the tail below
;                      takes every bank there)
;   $A003  jmp warm    from another bank, with XREQ saying what for
; tools/mkcar.py writes the same tail into every bank (16, or 128 on the
; 8 Mbit MaxFlash: whichever bank the cartridge powers up in leads to bank 0):
;   $BFE0  ldx #0 / sta $D500,x / jmp $A000   the OS's run address: bank
;                                             0's cold start
;   $BFE8  rts                                the OS's init address
;   $BFEE  the bank's sum (16 bits: every byte of the bank but these two)
;   $BFF0  sta $D500,x / jmp $A003            XBANK: on to bank X, warm
;   $BFF6  the CRC32 of $A000-$BEFF (a code bank: its code stays below $BF00;
;          the ROM test checks it, t_rom.asm)
;   $BFFA  the cartridge header
; A write to $D500+n selects bank n; the instruction after it comes from
; the new bank, which holds the same bytes there. A write to CARTOFF
; switches the cartridge off: the 128K AtariMax decodes $D500-$D51F (banks
; 0-15, off at $D510-$D51F), the 8 Mbit MaxFlash $D500-$D5FF (banks 0-127,
; off at $D580-$D5FF). Only these three writes differ between the two
; (undercart, ldmem, t_rom's bw_src): CART8M, build.py's 8 Mbit build.
ROMBASE	= $A000
RSUMAT	= $BFEE
RCRCAT	= $BFF6
XBANK	= $BFF0
	.ifdef CART8M
CARTOFF	= $D580
	.else
CARTOFF	= $D510
	.endif
XREQ	= BSS+$FC		; what a bank is entered for: 0 the menu, 1-7 that
				; test, 8 the long memory test's loader

; romsum: Z set if this bank's sum is right. Needs the stack and PTR.
romsum	lda #0
	sta SUM
	sta SUM+1
	sta PTR
	tay
	lda #>ROMBASE
	sta PTR+1
rm_lp	lda (PTR),y
	clc
	adc SUM
	sta SUM
	bcc rm_nc
	inc SUM+1
rm_nc	iny
	bne rm_lp
	inc PTR+1
	lda PTR+1
	cmp #$C0
	bne rm_lp
	sec			; take the two stored bytes back out
	lda SUM
	sbc RSUMAT
	sta SUM
	bcs rm_1
	dec SUM+1
rm_1	sec
	lda SUM
	sbc RSUMAT+1
	sta SUM
	bcs rm_2
	dec SUM+1
rm_2	lda SUM
	cmp RSUMAT
	bne rm_x
	lda SUM+1
	cmp RSUMAT+1
rm_x	rts
