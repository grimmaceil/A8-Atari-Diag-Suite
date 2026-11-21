; The start-up screen (main.asm includes it: in the standalone after the
; font, where there is room).
; The screen: three blank-line groups, then the rows (mode 2, 40 columns).
dl	dta $70,$70,$70
	dta $42,a(scr)
	dta $02,$02
	dta $41,a(dl)

scr	dta d' DEAD TEST'*	; row 0: the title bar, the version at the right
	.if VMIN>9
	:25 dta $80
	dta d'V'*,[VMAJ+$90],d'.'*,[VMIN/10+$90],[VMIN-VMIN/10*10+$90]
	.else
	:26 dta $80
	dta d'V'*,[VMAJ+$90],d'.'*,[VMIN+$90]
	.endif
	:40 dta 0		; row 1
	dta d'TESTING THE RAM'	; row 2
	:25 dta 0
