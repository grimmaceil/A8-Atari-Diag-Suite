; romtab: the known ROMs, by CRC32 (the scope doc, section 10a), and their
; names: test 1 (src/system/t_rom.asm) and the dead test's stage A
; (src/deadtest/stagea.asm) both include it. Each table: a count, then
; entries of the CRC32 (low byte first) and a name number (romnames).
; The tables (section 10a). Name numbers index romnames.
tab_d8	.byte 1
	.dword $6A5D766E
	.byte 0
tab_e0	.byte 3
	.dword $29F64E17
	.byte 1
	.dword $D818F3E8
	.byte 2
	.dword $8E547F56
	.byte 3
tab_f0	.byte 3
	.dword $BC533F0C
	.byte 1
	.dword $C1690A9B
	.byte 2
	.dword $BE55B413
	.byte 3
tab_xl	.byte 11
	.dword $C5C11546
	.byte 4
	.dword $1A1D7B1B
	.byte 5
	.dword $643BCC98
	.byte 6
	.dword $1F9CD270
	.byte 7
	.dword $29F133F7
	.byte 8
	.dword $0D477AA1
	.byte 9
	.dword $D425A9CF
	.byte 10
	.dword $1EAF4002
	.byte 11
	.dword $0E000B99
	.byte 12
	.dword $45F47988
	.byte 13
	.dword $F0A236D3
	.byte 14
; The halves: the 1200XL's two chips (MAME), and revs 1-4 split from ROM
; files whose whole-image CRC matches the table above (section 10a).
tab_c0h	.byte 6
	.dword $0391386B
	.byte 4
	.dword $6E29EC8D
	.byte 5
	.dword $C376D2F2
	.byte 6
	.dword $F1E30A44
	.byte 7
	.dword $79E0D038
	.byte 8
	.dword $4A3AE4E5
	.byte 11
tab_e0h	.byte 6
	.dword $B502F1E7
	.byte 4
	.dword $D73CE29A
	.byte 5
	.dword $4502AF6F
	.byte 6
	.dword $397BAA67
	.byte 7
	.dword $2C8B447A
	.byte 8
	.dword $ACCF9678
	.byte 11
tab_bas	.byte 3			; BASIC revisions A, B, C (the XL/XE's built-in
	.dword $4BEC4DE2	; ROM is B or C)
	.byte 15
	.dword $F0202FB3
	.byte 16
	.dword $7D684184
	.byte 17

romnames .word n_ab, n_antsc, n_bntsc, n_apal, n_r10, n_r11, n_r1, n_r2
	.word n_r3, n_r3a, n_r3b, n_r4, n_r5, n_r59, n_r59a
	.word n_basa, n_basb, n_basc
n_ab	dta d'A/B, ANY',$FF
n_antsc	dta d'A NTSC',$FF
n_bntsc	dta d'B NTSC',$FF
n_apal	dta d'A PAL',$FF
n_r10	dta d'10 1200XL',$FF
n_r11	dta d'11 1200XL',$FF
n_r1	dta d'1',$FF
n_r2	dta d'2',$FF
n_r3	dta d'3',$FF
n_r3a	dta d'3A',$FF
n_r3b	dta d'3B',$FF
n_r4	dta d'4',$FF
n_r5	dta d'5',$FF
n_r59	dta d'59 (3B?)',$FF
n_r59a	dta d'59A',$FF
n_basa	dta d'A',$FF
n_basb	dta d'B',$FF
n_basc	dta d'C',$FF
