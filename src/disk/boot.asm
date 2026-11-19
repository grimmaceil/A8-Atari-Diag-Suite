; The boot disk's sectors 1-4 (Atari-diag-boot-disk-scope.md). The OS
; loads them to $0600-$07FF at power-on and calls $0606, with everything
; running. Their loader (dload.asm's DLBOOT: one way, no screen) is in
; place at $0700 (DLDR), where every piece puts its own copy.
; They check the joysticks, then pick the RAM piece by the RAM the OS found
; (RAMTOP: under 16K, only a 400/800, gets RAM8, without the XL/XE parts)
; and load it.

	icl '../common/hw.asm'
	icl '../common/defs.asm'
	icl '../common/vars.asm'

BSS	= $0800		; (the pieces' results page: not set up yet)
DLBOOT	= 1			; (the boot's loader: dload.asm)
RAMTOP_OS = $6A

	opt h-
	org $0600
	.byte 0, 4		; flags, sectors
	.word $0600, bt_rts	; load, init

; The short check (common/stuck.asm), here so it comes at switch-on, before
; the RAM piece loads (the pieces leave it out). It needs the OS quiet: no
; VBI (it would put the shadows back in COLBK and DMACTL), ANTIC off, POKEY
; out of SIO's serial state, the other voices off. dchain turns the VBI
; and the interrupts back on; SIOV sets POKEY up again.
	sei
	lda #0
	sta NMIEN
	sta DMACTL
	sta AUDCTL
	sta SKCTL
	lda #3
	sta SKCTL
	lda #AUD_OFF
	sta AUDC1+2
	sta AUDC1+4
	sta AUDC1+6
	icl '../common/stuck.asm'
	ldx #$FF		; S again (the OS's frames: never returned to)
	txs

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
