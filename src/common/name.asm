; s_hpre: the program's name on the title bar (screen.asm's header), as its
; file is named, so it can't be taken for the machine found (the FOUND line
; under it). One list for every program; build.py's defines pick the line.
	.if .def ROM			; the cartridge
s_hpre	dta d' DIAG-CART  ',$FF
	.elseif .def DISK		; the boot disk, every piece
s_hpre	dta d' DIAG-DISK  ',$FF
	.elseif .def OWNTEST		; the memory test (tape2)
	.if .def NOXL
s_hpre	dta d' DIAG-8K-MEMTEST  ',$FF
	.elseif .def XEX
s_hpre	dta d' DIAG-16K-MEMTEST-XEX  ',$FF
	.elseif .def CART
s_hpre	dta d' DIAG-MEMTEST-CART  ',$FF
	.else
s_hpre	dta d' DIAG-16K-MEMTEST  ',$FF
	.endif
	.elseif .def ONE32		; the 32k+ program (its RAM stages)
	.ifdef XEX
s_hpre	dta d' DIAG-32K-XEX  ',$FF
	.else
s_hpre	dta d' DIAG-32K-XL-XE  ',$FF
	.endif
	.elseif .def ONE16
s_hpre	dta d' DIAG-16K-01-RAM  ',$FF
	.elseif .def SETNO		; the system tests (SETNO 0 = the 8k set,
	.if SETNO=4			; 1 = 16K, 3 = controls, 4 = 32k+)
	.ifdef XEX
s_hpre	dta d' DIAG-32K-XEX  ',$FF
	.else
s_hpre	dta d' DIAG-32K-XL-XE  ',$FF
	.endif
	.elseif SETNO=3
s_hpre	dta d' DIAG-CONTROLS  ',$FF
	.elseif SETNO=1
	.if TAPENO=3
s_hpre	dta d' DIAG-16K-03-HELLO  ',$FF
	.else
s_hpre	dta d' DIAG-16K-02-SYSTEM  ',$FF
	.endif
	.else
s_hpre	dta d' DIAG-8K-0',[TAPENO+$10]
	.if TAPENO=2
	dta d'-ROM  ',$FF
	.elseif TAPENO=3
	dta d'-INPUT  ',$FF
	.elseif TAPENO=4
	dta d'-PORTS  ',$FF
	.elseif TAPENO=5
	dta d'-SOUND  ',$FF
	.else
	dta d'-VIDEO  ',$FF
	.endif
	.endif
	.else				; the 8k set's RAM tape
s_hpre	dta d' DIAG-8K-01-RAM  ',$FF
	.endif
