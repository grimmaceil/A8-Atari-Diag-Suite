; made by tools/mkcrc8.py from the OS ROM dumps: do not edit
; The dead test's CRC-8 of each known OS chip (see mkcrc8.py), a
; count then the CRC-8s; and of a floating bus (the chip not there).
c8_d8	dta 1
	dta $E0		; CRC32 $6A5D766E: Atari 400-800 OS rev A PAL - CRC 72B3FED4.rom
c8_e0	dta 2
	dta $AD		; CRC32 $8E547F56: Atari 400-800 OS rev A PAL - CRC 72B3FED4.rom
	dta $42		; CRC32 $D818F3E8: Atari 400-800 OS rev B NTSC - CRC 0E86D61D.rom
c8_f0	dta 2
	dta $A9		; CRC32 $BE55B413: Atari 400-800 OS rev A PAL - CRC 72B3FED4.rom
	dta $A1		; CRC32 $C1690A9B: Atari 400-800 OS rev B NTSC - CRC 0E86D61D.rom
c8_xl	dta 5
	dta $C5		; CRC32 $C5C11546: Atari 1200XL OS rev 10 - 1982-10-26 - CRC C5C11546.rom
	dta $2E		; CRC32 $29F133F7: Atari XE OS rev 3 - 800XE - 1985-03-01 - CRC 29F133F7.rom
	dta $86		; CRC32 $1EAF4002: Atari XEGS OS rev 4 - XE Game System - 1987-05-07 - CRC 1EAF4002.rom
	dta $5C		; CRC32 $643BCC98: Atari XL OS rev 1 - 600XL - 1983-03-11 - CRC 643BCC98.rom
	dta $E2		; CRC32 $1F9CD270: Atari XL-XE OS rev 2 - 800XL 65XE 130XE - 1983-05-10 - CRC 1F9CD270.rom
C8FL_D8	= $17	; a floating bus
C8FL_E0	= $3A	; a floating bus
C8FL_F0	= $72	; a floating bus
C8FL_XL	= $53	; a floating bus
C8FL_C0	= $A3	; a floating bus
crc8t			; the CRC-8 table
	dta $00,$07,$0E,$09,$1C,$1B,$12,$15,$38,$3F,$36,$31,$24,$23,$2A,$2D
	dta $70,$77,$7E,$79,$6C,$6B,$62,$65,$48,$4F,$46,$41,$54,$53,$5A,$5D
	dta $E0,$E7,$EE,$E9,$FC,$FB,$F2,$F5,$D8,$DF,$D6,$D1,$C4,$C3,$CA,$CD
	dta $90,$97,$9E,$99,$8C,$8B,$82,$85,$A8,$AF,$A6,$A1,$B4,$B3,$BA,$BD
	dta $C7,$C0,$C9,$CE,$DB,$DC,$D5,$D2,$FF,$F8,$F1,$F6,$E3,$E4,$ED,$EA
	dta $B7,$B0,$B9,$BE,$AB,$AC,$A5,$A2,$8F,$88,$81,$86,$93,$94,$9D,$9A
	dta $27,$20,$29,$2E,$3B,$3C,$35,$32,$1F,$18,$11,$16,$03,$04,$0D,$0A
	dta $57,$50,$59,$5E,$4B,$4C,$45,$42,$6F,$68,$61,$66,$73,$74,$7D,$7A
	dta $89,$8E,$87,$80,$95,$92,$9B,$9C,$B1,$B6,$BF,$B8,$AD,$AA,$A3,$A4
	dta $F9,$FE,$F7,$F0,$E5,$E2,$EB,$EC,$C1,$C6,$CF,$C8,$DD,$DA,$D3,$D4
	dta $69,$6E,$67,$60,$75,$72,$7B,$7C,$51,$56,$5F,$58,$4D,$4A,$43,$44
	dta $19,$1E,$17,$10,$05,$02,$0B,$0C,$21,$26,$2F,$28,$3D,$3A,$33,$34
	dta $4E,$49,$40,$47,$52,$55,$5C,$5B,$76,$71,$78,$7F,$6A,$6D,$64,$63
	dta $3E,$39,$30,$37,$22,$25,$2C,$2B,$06,$01,$08,$0F,$1A,$1D,$14,$13
	dta $AE,$A9,$A0,$A7,$B2,$B5,$BC,$BB,$96,$91,$98,$9F,$8A,$8D,$84,$83
	dta $DE,$D9,$D0,$D7,$C2,$C5,$CC,$CB,$E6,$E1,$E8,$EF,$FA,$FD,$F4,$F3
