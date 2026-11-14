; ldmem: the long memory test from the cartridge. It tests all the RAM,
; the 8K under the cartridge too, so it can't run from ROM: its image (the
; same boot image as the tape's, tools/mkcar.py) is copied from banks
; MEMBK on (MEMPG pages, DATAPG to a bank) to $0800, the cartridge switches
; itself off ($D510: until the power goes off) and the image starts at
; $0806, as from tape. The copy loop runs from low RAM, since the bank it
; came from goes away; it only branches, so it runs wherever it is put.
LDAT	= $0600			; the copy loop, in low RAM (tested)
LDNPG	= $86			; pages left to copy
LDBANK	= $87			; bank being copied
LDPIB	= $88			; pages left in this bank
TRIG3	= $D013			; 1 = a cartridge is in (XL/XE)
COLDST	= $0244			; nonzero: RESET starts the machine from cold
GINTLK	= $03FA			; XL/XE OS: TRIG3 as at power-on

ldmem	sei
	lda #0
	sta NMIEN
	sta DMACTL
	sta PTR
	sta CUR
	lda #$08
	sta CUR+1
	lda #MEMBK
	sta LDBANK
	lda #MEMPG
	sta LDNPG
	ldx #ld_len-1
ld_cp	lda ld_code,x
	sta LDAT,x
	dex
	bpl ld_cp
	jmp LDAT

ld_code	ldx LDBANK
	sta $D500,x
	lda #$A0
	sta PTR+1
	lda #DATAPG
	sta LDPIB
	ldy #0
ld_by	lda (PTR),y
	sta (CUR),y
	iny
	bne ld_by
	inc PTR+1
	inc CUR+1
	dec LDNPG
	beq ld_done
	dec LDPIB
	bne ld_by
	inc LDBANK
	bne ld_code		; (always)
ld_done	lda #1			; RESET: a cold start
	sta COLDST
	sta $D510		; the cartridge off: $A000-$BFFF is RAM
	lda TRIG3		; (the XL OS halts if TRIG3 changes from this)
	sta GINTLK
	jmp $0806
ld_len	= *-ld_code
