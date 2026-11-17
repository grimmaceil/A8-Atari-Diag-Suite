; The boot disk's loader (Atari-diag-boot-disk-scope.md, section 8), in
; every piece and in the boot. A piece can't load the next one over itself,
; so dchain sets everything up, copies dl_src to page 7 (DLDR) and runs it
; there: it reads the piece's sectors with the OS's SIOV, turns the
; interrupts off again and enters the piece (or, dfetch, comes back: a data
; piece that loads above the caller).
;
; Needs from the includer: BSS (SCRON, SCRPG), hw.asm, defs.asm.
; The disk's layout, build/disktab.asm (tools/mkatr.py): for each piece its
; first sector (dtsl, dtsh), its sector count (dtcnt) and its load page
; (dtpg); every piece loads at a page start and is entered at LOAD+6 (or
; LOAD+9: a RAM piece's "again").

DLDR	= $0700			; the loader runs here (page 7: free once booted;
DMARK	= $07FE			; $07FE-$07FF: "back from the long test", $5A $A5)
DLOAD	= $0900			; where the pieces load (the results page: $0800)
HELLOAT	= $1C00			; the "hello" recording (16K: up to $38FF)
P_RAM8	= 0			; the pieces, in disk order (mkatr.py's PIECES)
P_RAM16	= 1
P_MENU	= 2
P_ROM	= 3
P_INPUT	= 4
P_PORTS	= 5
P_SOUND	= 6
P_VIDEO	= 7
P_HELLO	= 8
P_MEM	= 9
XREQ	= BSS+$FC		; why a piece was loaded: 0 the menu, 1-7 that
				; test, 8 the long test, 9 the results,
XPWRON	= $80			; and the RAM piece's power-on hand-over

DDEVIC	= $0300			; the OS's SIO control block (SIOV changes only
DUNIT	= $0301			; DSTATS)
DCOMND	= $0302
DSTATS	= $0303
DBUFLO	= $0304
DTIMLO	= $0306
DBYTLO	= $0308
DAUX1	= $030A
SIOV	= $E459
SYSVBV	= $E45F			; the OS's own VBI routines (fixed jump-table
	.ifndef XITVBV		; addresses on every OS; the long test has
XITVBV	= $E462			; these two already)
	.endif
	.ifndef VVBLKI
VVBLKI	= $0222
	.endif
VVBLKD	= $0224
SDMCTL	= $022F			; the shadows the OS's VBI copies to the chips
SDLSTL	= $0230
CHACT	= $02F3
CHBAS	= $02F4
COLOR1	= $02C5
COLOR2	= $02C6
COLOR4	= $02C8
ATRACT	= $4D
DLPTR	= $80			; (PTR: the messages' screen row)

	icl '../../build/disktab.asm'

; dfetch: load piece X and come back (the "hello" recording).
dfetch	lda #$FF
; dchain: load piece X and enter it at LOAD + A (6 or 9). Never returns.
dchain	pha
	txa
	pha
	sei
	ldx #0			; the loader to page 7
dc_cp	lda dl_src,x
	sta DLDR,x
	inx
	cpx #DLLEN
	bne dc_cp
	pla
	tax
	lda dtsl,x
	sta DLDR+[dl_sec-dl_src]
	lda dtsh,x
	sta DLDR+[dl_sec-dl_src]+1
	lda dtcnt,x
	sta DLDR+[dl_cnt-dl_src]
	lda dtpg,x
	sta DLDR+[dl_buf-dl_src]+1
	sta DLDR+[dl_vec-dl_src]+1
	pla
	sta DLDR+[dl_vec-dl_src]	; (the entry: LOAD+A; $FF: come back)
	lda #$31			; drive 1, read, 128 bytes
	sta DDEVIC
	lda #1
	sta DUNIT
	lda #$52
	sta DCOMND
	lda #7
	sta DTIMLO
	lda #128
	sta DBYTLO
	lda #0
	sta DBYTLO+1
	sta ATRACT			; the shadows, so the OS's VBI keeps the
	sta IRQEN			; screen as it is while the piece loads
	sta DLPTR			; (SIOV turns on the serial IRQs it needs)
	sta DLPTR+1			; (no screen: no messages)
	ldx SCRON
	beq dc_ns
	lda #<[23*40]			; the messages: row 23
	sta DLPTR
	lda SCRPG
	clc
	adc #>[23*40]
	sta DLPTR+1
	lda #$22
dc_ns	sta SDMCTL
	lda #<SCRDL
	sta SDLSTL
	lda SCRPG
	clc
	adc #>SCRDL
	sta SDLSTL+1
	lda #$E0
	sta CHBAS
	lda #2
	sta CHACT
	lda #C_TEXTLUM
	sta COLOR1
	lda #C_TEXTBG
	sta COLOR2
	lda #C_YELLOW
	sta COLOR4
	lda #$FF		; XL/XE: the OS in (SIOV), BASIC out, main RAM
	sta PORTB		; (400/800: an input port, the write does nothing)
	lda #<SYSVBV		; the OS's own VBI (the long test hooks it)
	sta VVBLKI
	lda #>SYSVBV
	sta VVBLKI+1
	lda #<XITVBV
	sta VVBLKD
	lda #>XITVBV
	sta VVBLKD+1
	lda #$40
	sta NMIEN
	cli
	jmp DLDR

; ---------------------------------------------------------------------------
; dl_src: runs at DLDR. Branches, and its own bytes by DLDR+offset.
	.ifdef DLALIGN		; the boot: already in place (the copy moves
	.if *>DLDR		; nothing, so it can't run over itself)
	.error "the boot's code runs into page 7"
	.endif
	:[DLDR-*] .byte 0
	.endif
dl_src
dl_new	ldx #dt_load-dl_txt	; LOADING...
	jsr DLDR+[dl_msg-dl_src]
dl_rd	lda #$40
	sta DSTATS
	lda DLDR+[dl_buf-dl_src]
	sta DBUFLO
	lda DLDR+[dl_buf-dl_src]+1
	sta DBUFLO+1
	lda DLDR+[dl_sec-dl_src]
	sta DAUX1
	lda DLDR+[dl_sec-dl_src]+1
	sta DAUX1+1
	jsr SIOV
	bmi dl_err
	inc DLDR+[dl_sec-dl_src]	; the next sector, 128 bytes on
	bne dl_s1
	inc DLDR+[dl_sec-dl_src]+1
dl_s1	lda DLDR+[dl_buf-dl_src]
	eor #$80
	sta DLDR+[dl_buf-dl_src]
	bne dl_s2
	inc DLDR+[dl_buf-dl_src]+1
dl_s2	dec DLDR+[dl_cnt-dl_src]
	bne dl_rd
	sei
	lda #0
	sta NMIEN
	sta IRQEN
	lda DLDR+[dl_vec-dl_src]
	cmp #$FF
	bne dl_go
	rts			; dfetch: back to the caller
dl_go	jmp (DLDR+[dl_vec-dl_src])

; A sector that won't read (the OS's SIO has tried it again already): red,
; a low tone and the message; a key, START or fire tries it again.
dl_err	lda #C_RED
	sta COLOR4
	lda #F_END
	sta AUDF1
	lda #AUD_ON
	sta AUDC1
	ldx #dt_err-dl_txt
	jsr DLDR+[dl_msg-dl_src]
dl_wr	jsr DLDR+[dl_in-dl_src]	; all let go, then a press
	bne dl_wr
dl_wp	jsr DLDR+[dl_in-dl_src]
	beq dl_wp
	lda #AUD_OFF
	sta AUDC1
	lda #C_YELLOW
	sta COLOR4
	bne dl_new

; dl_in: A nonzero (Z clear) while START, fire or a key is down.
dl_in	lda SKSTAT		; bit 2: 0 while a key is down
	and #4
	eor #4
	sta DLDR+[dl_tmp-dl_src]
	lda TRIG0		; bit 0: 0 while fire is down,
	and CONSOL		; or START
	eor #1
	and #1
	ora DLDR+[dl_tmp-dl_src]
	rts

; dl_msg: the text at dl_txt+X ($FF ends) on row 23, blanks after it.
dl_msg	lda DLPTR+1
	beq dm_x
	ldy #0
dm_lp	lda DLDR+[dl_txt-dl_src],x
	cmp #$FF
	bne dm_put
	lda #0			; (then blanks to the end of the row)
	dex
dm_put	sta (DLPTR),y
	inx
	iny
	cpy #40
	bne dm_lp
dm_x	rts

dl_txt
dt_load	dta d'LOADING...',$FF
dt_err	dta d'DISK ERROR. A KEY TRIES AGAIN',$FF
dl_sec	.word 0			; the next sector
dl_cnt	.byte 0			; sectors left
dl_buf	.word 0			; where it goes
dl_vec	.word 0			; the entry ($FF: come back)
dl_tmp	.byte 0
dl_end
DLLEN	= dl_end-dl_src
	.if DLLEN>DMARK-DLDR
	.error "the disk loader runs into the long test's mark ($07FE)"
	.endif

; dsum: Z set if this piece's sum is right: every byte from LOAD up to the
; stored sum (CKSUM; CRCFIX after it isn't summed), as tools/mkatr.py sums
; it. Needs the stack and PTR.
	.ifdef WANTDSUM
dsum	lda #0
	sta SUM
	sta SUM+1
	sta PTR
	tay
	lda #>LOAD
	sta PTR+1
ds_lp	lda PTR+1
	cmp #>CKSUM
	bne ds_add
	cpy #<CKSUM
	beq ds_cmp
ds_add	lda (PTR),y
	clc
	adc SUM
	sta SUM
	bcc ds_nc
	inc SUM+1
ds_nc	iny
	bne ds_lp
	inc PTR+1
	bne ds_lp
ds_cmp	lda SUM
	cmp CKSUM
	bne ds_x
	lda SUM+1
	cmp CKSUM+1
ds_x	rts
	.endif
