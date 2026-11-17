; The boot disk's sectors 1-4 (Atari-diag-boot-disk-scope.md). The OS
; loads them to $0600-$07FF at power-on and calls $0606, with everything
; running. The loader's own copy is at $0700 (DLALIGN), where every piece
; puts its copy.
; They pick the RAM piece by the RAM the OS found (RAMTOP: under 16K, only
; a 400/800, gets RAM8, without the XL/XE parts) and load it.

	icl '../common/hw.asm'
	icl '../common/defs.asm'
	icl '../common/vars.asm'

BSS	= $0800		; (the pieces' results page: not set up yet)
DLALIGN	= 1			; (the loader in place: dload.asm)
RAMTOP_OS = $6A

	opt h-
	org $0600
	.byte 0, 4		; flags, sectors
	.word $0600, bt_rts	; load, init

	lda #0			; no screen of ours yet: no text while it loads
	sta SCRON
	ldx #P_RAM16
	lda RAMTOP_OS
	cmp #$40
	bcs bt_go
	ldx #P_RAM8
bt_go	lda #6			; the power-on entry
	jmp dchain
bt_rts	rts

	icl 'dload.asm'

	.if *>DMARK
	.error "the boot runs into the long test's mark ($07FE)"
	.endif
	:[$0800-*] .byte 0
