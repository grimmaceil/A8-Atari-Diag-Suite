; The library: the reporter, the text screen, the machine line and the RAM
; test engine, the code the programs and their parts share.
;
; SHLIB, a one-load image (the 16k RAM tape, the 32k+ tape, the
; cartridge's RAM bank, the boot disk's RAM16): it is in the image once, in its first part
; (tape1/main.asm); the later parts (stage 2, the system tests) take its
; addresses from that part's label table (build.py writes build/shlib.asm
; from the labels between LIBBEG and LIBEND), and what differs between the
; parts is decided at run time (report.asm: SYSMODE, REDRAWV).
; NORAMT: without the RAM test engine (the system tests don't test RAM).
LIBBEG
	icl '../common/report.asm'
	icl '../common/screen.asm'
	icl '../common/info.asm'
	.ifndef NORAMT
	icl '../common/ramtest.asm'
	.endif
LIBEND
