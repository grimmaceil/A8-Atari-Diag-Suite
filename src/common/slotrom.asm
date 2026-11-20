; slotrom: is a cartridge in the slot, its ROM at $BFFC? The OS's own test
; is $BFFC = 0, but with nothing there the read returns whatever was last on
; the bus, and with ANTIC fetching a blank screen that can be $00 (review of
; 0.13, item 2). So ANTIC's DMA goes off, and $BFFC is read eight times,
; each at a different point of its scan line (a WSYNC, then 5 cycles more
; for each read left): a cartridge only if every read is $00. (ANTIC's
; refresh cycles go on with DMA off; one of them can't land before all
; eight.) C set: a cartridge. Leaves DMACTL 0: the caller turns ANTIC back
; on. Uses A, X, Y.
slotrom	lda #0
	sta DMACTL
	ldx #8
sq_rd	sta WSYNC
	txa
	tay
sq_dl	dey
	bne sq_dl
	lda $BFFC
	bne sq_no
	dex
	bne sq_rd
	sec
	rts
sq_no	clc
	rts
