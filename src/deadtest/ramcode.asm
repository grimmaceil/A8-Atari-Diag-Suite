; Stage A's work, run from the good page whose base is RB (each .local in
; stagea.asm sets RB and includes this; stagea.asm copies the bytes to
; RB+$500 and jumps there). Assembled for RB+$500 with org r:, stored in
; place. No stack, no zero page (the good page may be in bank 2 or 3, with
; zero page and the stack page bad): the primitives return through R_RET,
; and their pointers are their own operands (this runs in RAM).
;
; The good page (the plan's ledger: B = RB):
;   B+$000  the OS rows' lines, 40 columns each (rows 9, 10, 11)
;   B+$3C0  their display-list fragments, 4 bytes apart
;   B+$400  the work: below
;   B+$500  this code
R_LINES	= RB
R_FRAG	= RB+$3C0
R_SAVB	= RB+$400		; DDRB (a RAM result) while the self-test ROM is in
R_CRC	= RB+$404		; the CRC32 being made
R_FLT	= RB+$408		; 0: every byte so far read its own page number
R_RET	= RB+$40A		; a primitive's return address
R_N	= RB+$40C		; pages or entries left
R_SLOT	= RB+$40D		; a CRC's slot (0, 4, 8) in R_CRCS
R_E	= RB+$40E		; an entry's start in a table
R_A	= RB+$40F		; A, kept across CALL
R_IDS	= RB+$410		; 3 name numbers: $FF unknown, $FE not there
R_ROMBAD = RB+$413		; 1: a fault (test 1's item 3): a chip shown unknown
				; or not there (the show bank's verdict reads it)
R_CRCS	= RB+$414		; 3 CRC32s, low byte first

tmpl
	org r:RB+$500
rstart	ldx #0			; the machine: an XL/XE has ROM at $C000 (read
	stx R_FLT		; the same twice, not just its page number)
ms_lp	lda $C000,x
	cmp $C000,x
	bne m800		; (a moving bus: nothing there)
	cmp #$C0
	beq ms_n
	inc R_FLT
ms_n	inx
	bne ms_lp
	lda R_FLT
	beq m800
	jmp mxl

; The 400/800: each chip on its own.
m800	CALL crcnew
	lda #$D8
	ldx #8
	CALL crcpg
	ldy #0
	CALL crcput
	ldx #0
	lda #<tab_d8
	ldy #>tab_d8
	CALL ident
	sta R_IDS
	CALL crcnew
	lda #$E0
	ldx #16
	CALL crcpg
	ldy #4
	CALL crcput
	ldx #4
	lda #<tab_e0
	ldy #>tab_e0
	CALL ident
	sta R_IDS+1
	CALL crcnew
	lda #$F0
	ldx #16
	CALL crcpg
	ldy #8
	CALL crcput
	ldx #8
	lda #<tab_f0
	ldy #>tab_f0
	CALL ident
	sta R_IDS+2
	lda #0			; any chip unknown or not there: a fault
	sta R_ROMBAD
	ldx #2
mb_lp	lda R_IDS,x
	cmp #$FE
	bcc mb_n
	inc R_ROMBAD
mb_n	dex
	bpl mb_lp
	LINE 0,lbl_d8
	LINE 1,lbl_e0
	LINE 2,lbl_f0
	jmp sa_ret

; The XL/XE: the 16K image as test 1 reads it ($C000-$CFFF, the self-test
; ROM for $D000-$D7FF, $D800-$FFFF); the $C000 half (to $DFFF) and the
; $E000 half on their own, shown when the image is unknown.
mxl	CALL crcnew
	lda #$C0
	ldx #16
	CALL crcpg
	lda PBCTL		; the self-test ROM in: PORTB bit 7 low, which
	and #$FB		; needs it an output: DDRB (bank 2's result)
	sta PBCTL		; kept here meanwhile
	lda DDRB
	sta R_SAVB
	lda #$FF
	sta DDRB
	lda PBCTL
	ora #4
	sta PBCTL
	lda #$7F
	sta PORTB
	lda #$50
	ldx #8
	CALL crcpg
	lda #$FF
	sta PORTB
	lda PBCTL
	and #$FB
	sta PBCTL
	lda R_SAVB
	sta DDRB
	lda #$D8
	ldx #8
	CALL crcpg
	ldy #4			; the $C000 half
	CALL crcput
	lda #$E0
	ldx #32
	CALL crcpg
	ldy #0			; the image
	CALL crcput
	CALL crcnew
	lda #$E0
	ldx #32
	CALL crcpg
	ldy #8			; the $E000 half
	CALL crcput
	lda #1			; (an XL/XE's ROM is there: the reset ran in it)
	sta R_FLT
	ldx #0
	lda #<tab_xl
	ldy #>tab_xl
	CALL ident
	sta R_IDS
	ldx #4
	lda #<tab_c0h
	ldy #>tab_c0h
	CALL ident
	sta R_IDS+1
	ldx #8
	lda #<tab_e0h
	ldy #>tab_e0h
	CALL ident
	sta R_IDS+2
	lda #0			; a fault: the image unknown and a half unknown
	sta R_ROMBAD		; (test 1: two known halves are a known pair)
	lda R_IDS
	cmp #$FF
	bne mx_k
	lda R_IDS+1
	cmp #$FF
	beq mx_b
	lda R_IDS+2
	cmp #$FF
	bne mx_k
mx_b	inc R_ROMBAD
mx_k	LINE 0,lbl_xl
	lda R_IDS		; a known image: the halves' rows stay blank
	cmp #$FF
	beq mx_h
	BLANKLINE 1
	BLANKLINE 2
	jmp sa_ret
mx_h	LINE 1,lbl_c0
	LINE 2,lbl_e0
	jmp sa_ret

; crcnew: a new CRC32, and no byte seen that isn't floating.
crcnew	lda #$FF
	sta R_CRC
	sta R_CRC+1
	sta R_CRC+2
	sta R_CRC+3
	lda #0
	sta R_FLT
	jmp (R_RET)

; crcpg: X pages from page A into the CRC32 (table-driven: crc32tab.asm);
; R_FLT set by any byte that isn't its own page number.
crcpg	sta rd+2
	sta fl+1
	stx R_N
cp_pg	ldx #0
rd	lda $FF00,x
	tay
fl	cpy #$FF
	beq cp_f
	lda #1
	sta R_FLT
cp_f	tya
	eor R_CRC
	tay
	lda R_CRC+1
	eor crc32t0,y
	sta R_CRC
	lda R_CRC+2
	eor crc32t1,y
	sta R_CRC+1
	lda R_CRC+3
	eor crc32t2,y
	sta R_CRC+2
	lda crc32t3,y
	sta R_CRC+3
	inx
	bne rd
	inc rd+2
	inc fl+1
	dec R_N
	bne cp_pg
	jmp (R_RET)

; crcput: the CRC32 (inverted, as CRC32 ends) to slot Y of R_CRCS.
crcput	ldx #0
cu_lp	lda R_CRC,x
	eor #$FF
	sta R_CRCS,y
	iny
	inx
	cpx #4
	bne cu_lp
	jmp (R_RET)

; ident: A = the name number of slot X's CRC in the table at A/Y (romtab:
; a count, then entries of 4 CRC bytes and a name number); $FF if none
; matches, $FE if the chip read as a floating bus (R_FLT 0: not there).
ident	stx R_SLOT
	ldx R_FLT
	bne id_go
	lda #$FE
	jmp (R_RET)
id_go	sta id_n+1
	sty id_n+2
	clc
	adc #1
	sta id_d+1
	sta id_m+1
	tya
	adc #0
	sta id_d+2
	sta id_m+2
id_n	lda $FFFF		; the count
	sta R_N
	ldy #0
id_ent	sty R_E
	ldx R_SLOT
id_d	lda $FFFF,y
	cmp R_CRCS,x
	bne id_no
	iny
	inx
	tya
	sec
	sbc R_E
	cmp #4
	bne id_d
id_m	lda $FFFF,y		; the name number
	jmp (R_RET)
id_no	lda R_E
	clc
	adc #5
	tay
	dec R_N
	bne id_ent
	lda #$FF
	jmp (R_RET)

; puts: the $FF-ended string at A/Y to ps_d's address (set by DEST).
puts	sta ps_s+1
	sty ps_s+2
	ldx #0
ps_s	lda $FFFF,x
	cmp #$FF
	beq ps_x
ps_d	sta $FFFF,x
	inx
	bne ps_s
ps_x	jmp (R_RET)


; hex: slot R_SLOT's CRC32, high byte first, as 8 digits at the address
; HEXDEST set (both stores' operands).
hex	lda R_SLOT
	clc
	adc #3
	sta R_SLOT
	ldy #0
hx_b	ldx R_SLOT
	lda R_CRCS,x
	lsr
	lsr
	lsr
	lsr
	DIGIT
hx_d	sta $FFFF,y
	iny
	ldx R_SLOT
	lda R_CRCS,x
	and #$0F
	DIGIT
hx_e	sta $FFFF,y
	iny
	dec R_SLOT
	cpy #8
	bne hx_b
	jmp (R_RET)
rend
	.if rend-rstart>$B00
	.error "stage A's RAM code is over $B00 bytes (the good page: B+$500-$FFF)"
	.endif
	org tmpl+[rend-rstart]
