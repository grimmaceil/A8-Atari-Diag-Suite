; The disk set's boot sectors, on its two disks that carry two programs
; (disk-set/diag-8k-05-sound.atr and diag-8k-memtest.atr; build.py's
; build_diskset). The OS loads them to $0600-$07FF at power-on and calls
; $0606. They pick the program by the RAM the OS found (RAMTOP): under 16K
; the 8k tape's own, 16K and up the 16K one (the sound test with the
; sampled "hello", or diag-16k-memtest), and load it with the boot disk's
; loader (dload.asm's DLBOOT: one way, no screen), which enters it at
; $0806, as the OS does from tape. Each program does its own start-up and
; stuck joystick check, as from tape.
; The two programs' places: build/settab.asm (tools/mkatr.py's settab).

	icl '../common/hw.asm'
	icl '../common/defs.asm'
	icl '../common/vars.asm'

BSS	= $0800		; (dload.asm's: nothing of it is used one way)
DLBOOT	= 1			; (the boot's loader: dload.asm)
SETTAB	= 1			; (dload.asm: the disk set's table)
RAMTOP_OS = $6A

	opt h-
	org $0600
	.byte 0, 4		; flags, sectors
	.word $0600, sb_rts	; load, init
	ldx #0			; under 16K: the first program
	lda RAMTOP_OS
	cmp #$40
	bcc sb_go
	inx			; 16K and up: the second
sb_go	lda #6			; entered at LOAD+6, as from tape
	jmp dchain
sb_rts	rts

	icl 'dload.asm'

	:[$0800-*] .byte 0
