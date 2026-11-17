; ramhand: the end of a boot disk's RAM piece (its summary, by a press or by
; itself; or S, or back from the long test). The RAM faults (banks 1-8, the
; piece's own RAM folded into bank 1) become test 0's items (BADMASK+8,
; item = bank), as the cartridge's tomenu does; the other tests' results
; come back if this was the RAM test run again from the menu (KEEP); then
; the menu's piece takes over (XREQ $80: system/common.asm's trun).
ramhand	lda #0
	sta MTMP
	ldx #8
rh_lp	asl MTMP
	lda BADMASK,x
	beq rh_n
	inc MTMP
	lda #0
	sta BADMASK,x
rh_n	dex
	bne rh_lp
	lda BADMASK+LDRIDX
	beq rh_l
	lda #0
	sta BADMASK+LDRIDX
	lda #1
	ora MTMP
	sta MTMP
rh_l	lda MTMP
	sta BADMASK+8
	lda KEEP
	beq rh_go
	ldx #7
rh_kp	lda STASH-1,x
	sta BADMASK,x
	dex
	bne rh_kp
rh_go	lda #XPWRON
	sta XREQ
	ldx #P_MENU
	lda #6
	jmp dchain
