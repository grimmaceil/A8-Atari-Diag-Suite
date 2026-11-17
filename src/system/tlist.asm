; The tests, in running order, then final. ttests: their numbers, 0 ends.
tlist
	.ifdef WANT_ROM
	.word t_rom
	.elseif .def SPLIT
	.word xt1
	.endif
	.ifdef WANT_KB
	.word t_kb
	.elseif .def SPLIT
	.word xt2
	.endif
	.ifdef WANT_CON
	.word t_con
	.elseif .def SPLIT
	.word xt3
	.endif
	.ifdef WANT_JOY
	.word t_joy
	.elseif .def SPLIT
	.word xt4
	.endif
	.ifdef WANT_PAD
	.word t_pad
	.elseif .def SPLIT
	.word xt5
	.endif
	.ifdef WANT_POK
	.word t_pok
	.elseif .def WANT_SND
	.word t_snd
	.elseif .def SPLIT
	.word xt6
	.endif
	.ifdef WANT_GTIA
	.word t_gtia
	.elseif .def SPLIT
	.word xt7
	.endif
	.word final

ttests
	.ifdef WANT_ROM
	.byte 1
	.elseif .def SPLIT
	.byte 1
	.endif
	.ifdef WANT_KB
	.byte 2
	.elseif .def SPLIT
	.byte 2
	.endif
	.ifdef WANT_CON
	.byte 3
	.elseif .def SPLIT
	.byte 3
	.endif
	.ifdef WANT_JOY
	.byte 4
	.elseif .def SPLIT
	.byte 4
	.endif
	.ifdef WANT_PAD
	.byte 5
	.elseif .def SPLIT
	.byte 5
	.endif
	.ifdef WANT_POK
	.byte 6
	.elseif .def WANT_SND
	.byte 6
	.elseif .def SPLIT
	.byte 6
	.endif
	.ifdef WANT_GTIA
	.byte 7
	.elseif .def SPLIT
	.byte 7
	.endif
	.byte 0
