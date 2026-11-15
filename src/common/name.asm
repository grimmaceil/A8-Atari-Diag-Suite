; s_hpre: the program's name on the title bar (screen.asm's header), as its
; file is named, so it can't be taken for the machine found (the FOUND line
; under it). One list for every program; build.py's defines pick the line.
	.if .def ROM			; the cartridge
s_hpre	dta d' DIAG-CART  ',$FF
	.elseif .def OWNTEST		; the memory test (tape2)
	.if .def NOXL
s_hpre	dta d' DIAG-400-MEMTEST  ',$FF
	.elseif .def XEX
s_hpre	dta d' DIAG-MEMTEST-XEX  ',$FF
	.elseif .def CART
s_hpre	dta d' DIAG-MEMTEST-CART  ',$FF
	.else
s_hpre	dta d' DIAG-MEMTEST  ',$FF
	.endif
	.elseif .def ONE32		; the 32k+ program (its RAM stages)
	.ifdef XEX
s_hpre	dta d' DIAG-32K-XEX  ',$FF
	.else
s_hpre	dta d' DIAG-32K-XL-XE  ',$FF
	.endif
	.elseif .def ONE16
s_hpre	dta d' DIAG-16K-01-RAM  ',$FF
	.elseif .def SETNO		; the system tests (SETNO 0 = the 400 set,
	.if SETNO=4			; 1 = 16K, 3 = controls, 4 = 32k+)
	.ifdef XEX
s_hpre	dta d' DIAG-32K-XEX  ',$FF
	.else
s_hpre	dta d' DIAG-32K-XL-XE  ',$FF
	.endif
	.elseif SETNO=3
s_hpre	dta d' DIAG-CONTROLS  ',$FF
	.elseif SETNO=1
s_hpre	dta d' DIAG-16K-02-SYSTEM  ',$FF
	.else
s_hpre	dta d' DIAG-400-0',[TAPENO+$10]
	.if TAPENO=2
	dta d'-ROM  ',$FF
	.elseif TAPENO=3
	dta d'-INPUT  ',$FF
	.elseif TAPENO=4
	dta d'-PORTS  ',$FF
	.else
	dta d'-AV  ',$FF
	.endif
	.endif
	.else				; the 400 set's RAM tape
s_hpre	dta d' DIAG-400-01-RAM  ',$FF
	.endif
