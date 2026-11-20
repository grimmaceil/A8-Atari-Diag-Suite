# A8 Atari Diag Suite: scope and design

By **Michael Grimm**, written with Claude (Anthropic's AI). MIT license
(see [LICENSE](../../LICENSE)).

A diagnostic suite for every Atari 8-bit computer: the 400, 800, 1200XL,
600XL, 800XL, 65XE, 800XE, 130XE and XE Game System. It started as
cassettes only (hence this file's name) and now runs from a cartridge, a
boot disk, a set of one-test disks and cassettes, all built from one
source. The goal: as much
diagnostic information as possible, first through border colours and
beeps that work with no picture at all, then as plain text once the video
hardware has proven itself.

This document is the design as built at version 0.13: what is tested, how
results are reported, and why. How the code is put together is in
[docs/DEVELOPMENT.md](../DEVELOPMENT.md); how to use it, in the
[user guide](../USER-GUIDE.md).

Authorship: the author has programmed 6502 machine language and assembler
since childhood, but for now this project is 100% AI-written. Claude
writes the code; the author directs, reviews and tests it on a MiSTer and
on real machines. The design changed a lot over the sessions; this file
records where it ended up.

---

## 1. Target hardware

| Machine | RAM | Notes |
|---|---|---|
| 400 | 8K or 16K | No RAM on the motherboard; RAM on a plug-in board |
| 800 | Up to 48K, three 16K boards in slots | Slot position sets each board's address range; OS rev A/B on a removable OS board |
| 800XL | 64K, eight 4164 DRAMs, one chip per data bit | |
| 130XE | 64K main + 64K extended (4 x 16K banks) | Its own DRAM layout |
| 1200XL | 64K | No BASIC built in; F1-F4 and HELP keys; two 8K OS chips |
| 600XL | 16K (64K with the 1064 expansion) | Same MMU and PORTB banking as the 800XL |
| 65XE, 800XE | 64K | 800XL-compatible |
| XE Game System | 64K | Built-in BASIC and Missile Command (PORTB bit 6); detachable keyboard |

Memory decoding:
- **400/800:** a fixed memory map decoded by discrete TTL, no software
  banking. A cartridge pulls RD5 ($A000-$BFFF) or RD4 ($8000-$9FFF), which
  disables the RAM there in hardware.
- **XL/XE:** the MMU decodes using the address lines, RD4/RD5 and the PIA
  PORTB bits: bit 0 the OS ROM, bit 1 BASIC, bit 7 the self-test ROM,
  bits 2-5 (130XE) the bank, CPU access and ANTIC access.
- On the 400/800, PIA PORTB is joystick ports 3 and 4.

## 2. Formats, and what each needs

| Format | Needs | Strengths |
|---|---|---|
| Cartridge (`diag-cart.car`, AtariMax 128K) | 8K of RAM, a flash cartridge | The best test: no loading, every test on one menu, runs from ROM, tests the RAM under itself: for RAM too sick to load a program into |
| Boot disk (`diag-disk.atr`) | 8K of RAM, a disk drive or an SIO adapter; no DOS | The most convenient free way: the cartridge's menu, each test loaded as it is picked; the long test and the "hello" with 16K |
| Disk set (`disk-set/`) | 8K, a disk drive or an SIO adapter | The 8k tapes as disks, one test to a disk, no menu: for when the boot disk can't get far |
| Cassettes (`.cas`) | 8K and up, by set | No drive, no DOS, no flash cartridge: for an 8K 400 or a machine too sick to boot a disk |

Sets by RAM, not by model: the 8k set needs 8K, the 16k set,
`diag-controls` and `diag-16k-memtest` need 16K, `diag-32k-xl-xe` 32K.
Every tape works on any machine with at least that much RAM. The tapes
that need more than 8K check the OS's RAMTOP ($6A) first and halt below
it: red border, the low tone 0.6 s on and 0.6 s off, for good. The boot
disk loads only what the RAM can run (it picks its RAM test by the RAM
the OS found; the long test and the "hello" need 16K).

## 3. Key constraints

- **A cassette boot needs a working OS ROM and low RAM:** zero page, the
  stack, the cassette buffer at $0400, and wherever the program loads.
  The suite diagnoses partly-bad RAM, not dead RAM (the cartridge needs
  the least: 8K, and runs its code from ROM).
- **Boot:** hold START at power-on, wait for the beep, start the tape,
  press a key. A BASIC cartridge left in does no harm: the OS boots a tape
  (START held) or a disk before it would start the cartridge, and the
  program never hands it back, so test 1 reads it. But the documents say
  to take every cartridge out (the RAM under it can't be tested) and to
  check BASIC with BASCRC. The
  programs switch an XL/XE's BASIC off themselves.
- **A BOOT ERROR during load is itself diagnostic:** the OS checks each
  record, so the error points at low RAM, the cassette buffer or the SIO
  path.
- **600 baud** is about 3K a minute: keep each tape small. Cassette is
  sequential, so each test group is its own bootable image.
- **Before low RAM is proven** the code doesn't use the stack or zero
  page: SEI and NMIEN = 0, no JSR/RTS/PHA/PLA (return vectors in a BSS
  page instead), state in A/X/Y.

## 4. Feedback design

### The ladder (each level only after its hardware checks out)

1. **Abstract:** ANTIC DMA off; the border colour (COLBK) plus POKEY
   beeps (and the console speaker, in case POKEY is dead). Works even
   with garbage video: GTIA shows COLBK whatever ANTIC fetches.
2. **Display prerequisites:** a 1K screen block that tests good, the
   character ROM read the same twice, VCOUNT counting.
3. **Text:** every result also on screen. The first result screen is the
   picture check: pressing a key there says the picture can be read, and
   from then on the border stays steady and codes play once (QUIET).
   OPTION or F switches between text and full-screen flashes, for a
   garbled picture.

### Colours
- Green: alive, a pass. Bright green flash: a pass beep.
- Yellow: testing (a hang shows which test it stopped in). Memory test:
  an intermittent fault seen. At the end with the start-up chirp: nothing
  failed, but not every test ran.
- Red: a fault. Bright red flash: a fault beep.
- Purple: waiting for an answer.
- Colour is never needed to read a result: every colour comes with a sound.

### Sounds and the beep code
- **Pass:** the charge, G4 C5 E5 G5 (twice for the final pass); then, while
  it waits without text, one long green flash per 16K bank (RAM) every
  5 s.
- **Fail:** "impending doom", C4 C4 F#3, then the code if it has one.
- **The code:** group A, long beeps (~600 ms): where (the RAM bank 1-4,
  the 130XE's banks 5-8, or the test); group B, short beeps (~200 ms):
  what (the data bit counted 1-8, D0 = 1, or the item); one B group per
  bad bit, then a low end tone. At most 8 counts per group.
- **Only the RAM and the ROMs have a code:** they are what a machine with
  no picture can still tell you about. The ROM test's tones are lower than
  the RAM's, so the two can be told apart by ear. The other tests show
  their result on screen.

### Flow and keys
- **Nothing moves on by itself.** Every result and every question waits
  for as long as it takes; a sound being asked about repeats until the
  answer. (No timeouts after boot: they only annoy, and a technician needs
  time to read, to walk away, or to re-test.)
- **Two keys for every action**, a console key and a keyboard key, so a
  dead key never strands the user: R re-test; T or SELECT the tones
  again; F or OPTION full-screen flashes; any other key (START, a
  joystick button) goes on. Questions: Y or START yes, N or SELECT no.
- **R only where there is no menu:** the RAM tapes' summaries, the last
  screen of every tape without a menu (all its tests again: no reloading
  after a slip), the memory test's summary. A menu picks a test again.
- **Skips:** S skips the RAM test (cartridge, boot disk, 32k+ tape), X
  the console key test.

### Screen layout (40-column text)
- The title bar names the program (`DIAG-16K-02-SYSTEM  2 KEYBOARD`) and
  its version; the line below says what it found (`FOUND: XL/XE  RAM 64K
  NTSC`).
- Each test's screen, then its result lines at rows 21-23 with the keys.
- The end of a tape without a menu: a line per test and what to load
  next (`DONE. R=RETEST. NEXT: DIAG-8K-04-PORTS`).
- The menu (16k, 32k+, cartridge, boot disk): 0 RAM, 1-7 the tests, 8 the
  results and final code, 9 the long memory test (cartridge and boot
  disk). After each test the next one is highlighted, so START, START...
  walks them all in order.

## 5. The tests

Numbered the same in every format; the items are what `FAIL` lists.

| # | Test | What it does | Items |
|---|---|---|---|
| 0 | RAM | Low RAM ($0000-$07FF, non-destructive, no stack); then each 16K bank: March C- plus address-in-address (a decoder or address-line fault shows as a mirror); the program's own RAM page by page; the RAM under the XL/XE OS (bank 4) and a 130XE's banks 5-8; on the cartridge the 8K under it | the bank |
| 1 | ROMs | CRC32 of each OS chip (400/800: three, each named on its own), BASIC (a cartridge if one is in, else an XL/XE's built-in), the character set read twice, and the program itself (self-check) against section 10 | 1 OS reads differently twice; 2 BASIC matches no revision; 3 unknown OS; 4 character set differs; 5 OS chips from different revisions; 6 self-check failed |
| 2 | Keyboard | stuck key at the start; then a key map that lights each key | 1 stuck; 2 keys never pressed |
| 3 | Console keys | START, SELECT, OPTION; the console speaker by ear | 1-3 the key; 4 the speaker |
| 4 | Joysticks | live, 4 ports on a 400/800, 2 on an XL/XE; stuck lines at the start | the port |
| 5 | Paddles | open-input check (every unplugged input reads 228), then live values with min, max and jitter (no fast scan: it can't read paddles) | the paddle |
| 6 | POKEY | timer IRQ and RANDOM (automatic); each voice's scale and noise by ear; the sampled "hello" (cartridge; boot disk and the disk set's sound disk with 16K; `diag-16k-03-hello`) | 1 timer; 2 random; 3-6 voices; 7 "hello" |
| 7 | GTIA/ANTIC | luminance and colour ramps, the word ATARI in players and missiles scrolling right to left and snaking, PAL/NTSC; page 2: ANTIC 6, 7, the bitmaps 8, A, B, D, F, GTIA 9, 10, 11, fine scrolling | 1 page 1 looks wrong; 2 page 2 looks wrong |

The memory test (burn-in) loops the RAM tests until a key: a clock, the
passes done, and a log of every bad bit (first pass, passes failed);
solid versus intermittent; yellow once anything intermittent is seen.
- **16K and up** (`diag-16k-memtest`, the cartridge's and the boot disk's
  line 9): low RAM, then one March C- over all the RAM it reaches, the RAM
  under an XL/XE's OS too (a march over one sweep finds address faults as
  well, so there is no separate address test), then the **refresh
  check**: the RAM filled with $00, the screen off and the CPU idle in a
  tiny loop for 5 seconds, so only ANTIC's refresh keeps it, then read
  back; the same with $FF. Every read or write refreshes the row it
  touches, so a march can't see a refresh fault (a replacement chip that
  needs 256 rows refreshed in a machine whose ANTIC refreshes 128, say).
  Then a 130XE's banks, with an address test and the same wait. It keeps
  two copies of itself that test each other's RAM.
- **8K** (`diag-8k-memtest`): low RAM, the march bank by bank, an address
  test over all of it, its own RAM page by page. No room for the refresh
  check. It stops on an XL/XE, whose extra RAM it can't reach.

BASCRC checks BASIC on its own (CRC32, revisions A, B, C), from its own
disk or tape: with the diag cartridge, which can't read a BASIC
cartridge, or as a second opinion. Test 1 does the same check when a tape
or disk runs with BASIC in.

## 6. The files

| Set | Files |
|---|---|
| Boot disk | `diag-disk.atr`: everything on the cartridge's menu, each test loaded as picked; the long memory test on line 9 (16K) |
| Cartridge | `diag-cart.car`: everything; the long memory test on menu line 9 (16K) |
| Other disks | `diag-16k-memtest.atr` (boots into the long memory test), `diag-bascrc.atr` (boots into BASCRC; also a DOS 2 disk with `BASCRC.XEX` and `BASCRC.LST`) |
| Disk set | the 8k tapes as disks: `diag-8k-01-ram.atr` to `diag-8k-06-video.atr`, `diag-8k-memtest.atr`; on 16K the RAM disk loads its part 2 itself, the sound disk adds the "hello", the memtest disk runs `diag-16k-memtest` |
| 8k set | `diag-8k-01-ram` (stage 2 on 16K and up: its own RAM, the XL/XE extras), `-02-rom`, `-03-input` (2, 3), `-04-ports` (4, 5), `-05-sound` (6), `-06-video` (7), `diag-8k-memtest` |
| 16k set | `diag-16k-01-ram` (one load), `diag-16k-02-system` (1-7 with the menu), `diag-16k-03-hello`, `diag-16k-memtest` |
| 32k+ | `diag-32k-xl-xe`: the RAM test, then 1-7 with the menu, one load |
| Others | `diag-controls` (2, 4, 5: a companion to the SALT disks, no harness), `diag-bascrc` (BASCRC as a listing for `ENTER "C:"`) |

Within a set every tape relies only on what an earlier one proved: RAM
before anything runs from it, the keyboard before a question.

## 7. Build and development environment

- **Assembler:** MADS. **Tools:** Python (`tools/`): the build, the CAS,
  ATR and CAR writers, a cycle-timed simulator on py65, the documentation
  pictures.
- **Deploy:** every build copies the changed release files to the share
  the MiSTer reads.
- **Test order:** the simulator for what it can show; then the MiSTer
  (cartridge first, then disk, then tape); then real machines (an 800 and
  an 800XL over an SIO adapter). The video test is judged by eye.
- **Build flags:** `--fault BANK,BIT` builds with a fake stuck bit, to hear
  a fail code (no emulator simulates a bad chip); `--fast` skips the slow
  patterns.
- **File names** start with `diag-`, carry the set and number, and the
  version (`-v0.13`), so they sort together.

## 8. Register quick reference

| Register | Address | Use |
|---|---|---|
| COLBK | $D01A | Border/background color (status color) |
| CONSOL | $D01F | START/SELECT/OPTION; speaker |
| PAL | $D014 | PAL/NTSC detect |
| AUDF1-4 / AUDC1-4 | $D200-$D207 (write) | Tone frequency / control |
| POT0-7 | $D200-$D207 (read) | Paddle values 0-228 |
| AUDCTL / ALLPOT | $D208 (write/read) | Audio control / pot scan status |
| KBCODE | $D209 (read) | Keyboard code |
| RANDOM | $D20A (read) | Random number |
| POTGO | $D20B (write) | Start pot scan |
| SKCTL / SKSTAT | $D20F (write/read) | Serial/keyboard control (3 = normal); bit 2 = fast pot scan (not used: it can't read paddles) |
| PORTA | $D300 | Joysticks 1/2 |
| PORTB | $D301 | Joysticks 3/4 (400/800); banking (XL/XE) |
| PACTL | $D302 | Cassette motor control |
| DMACTL | $D400 | ANTIC DMA (0 = off) |
| DLISTL/H | $D402/$D403 | Display list pointer |
| CHBASE | $D409 | Character set base (ROM font at $E000) |
| WSYNC | $D40A | Wait for horizontal sync |
| VCOUNT | $D40B | Scanline counter / 2 |
| NMIEN | $D40E | NMI enable (0 = off) |
| Cart control | $D500-$D5FF | CCTL area, used by bank-switched carts |

---

## 9. Reference sources

- **Mapping the Atari, Revised Edition** (Ian Chadwick, Compute!): address-by-address map. The revised edition covers the XL. Free at atariarchives.org.
- **Altirra Hardware Reference Manual** (Avery Lee): the most accurate source on chip behavior, timing, and the cassette/SIO protocol.
- **Atari 400/800 OS User's Manual** and **Hardware Manual** (Technical Reference Notes): official specs, including the cassette boot record format and the boot sequence.
- **Atari OS source listings** (rev B for the 400/800, plus the XL OS): exactly what the OS does at reset and cassette boot, and which RAM it uses before handing over control.
- **De Re Atari** (Atari, 1981): display lists, POKEY sound, timing.
- **400/800 Field Service Manual** and **Sams Computerfacts for the 800XL** (and 130XE schematics): for the bit-to-chip tables.
- **a8cas** (a8cas.sourceforge.net): CAS format details and CAS/WAV conversion tools.
- **SALT** and Super SALT (prior art, harness-based) and **Sys-Check** (XL/XE PBI dead-test device): reference for test coverage.

---

## 10. Known ROM CRC32s (looked up, not taken from any one machine)

The ROM test identifies ROMs by CRC32 against this table. It must not rely
on the sums from one MiSTer's ROM files: a repaired machine can have mismatched
chips, and nobody can simulate every variant. A ROM that matches no entry is
reported as UNKNOWN; that covers patched, replacement (e.g. Altirra OS),
failing and mis-socketed chips alike.

Sources: atari800 emulator `src/sysrom.c` (whole images) and MAME
`src/mame/atari/atari400.cpp` (per chip), both read 2026-11-07. The two are
independent. Each set of MAME chip CRCs combines (CRC32 combine) exactly to
the atari800 whole-image CRC, so the chip values are confirmed even though
MAME marks them BAD_DUMP.

400/800 OS: three chips. The CRC covers each chip's range as the CPU sees it.

| Chip | Range | Rev A NTSC | Rev B NTSC | Rev A PAL |
|---|---|---|---|---|
| CO12399B | $D800-$DFFF | 6A5D766E | 6A5D766E | 6A5D766E |
| E000 chip | $E000-$EFFF | 29F64E17 (CO12499A) | D818F3E8 (CO12499B) | 8E547F56 (CO15199) |
| F000 chip | $F000-$FFFF | BC533F0C (CO14599A) | C1690A9B (CO14599B) | BE55B413 (CO15299) |
| whole | $D800-$FFFF | C1B3BB02 | 0E86D61D | 72B3FED4 |

XL/XE OS: one 16K image covering $C000-$FFFF. Its $D000-$D7FF holds the
self-test, which the CPU sees at $5000-$57FF when PORTB bit 7 = 0.

| Rev | CRC32 | Notes |
|---|---|---|
| 10 | C5C11546 | 1200XL (two 8K chips: $C000 0391386B, $E000 B502F1E7) |
| 11 | 1A1D7B1B | 1200XL (two 8K chips: $C000 6E29EC8D, $E000 D73CE29A) |
| 1 | 643BCC98 | 600XL (MAME) |
| 2 | 1F9CD270 | 800XL, 65XE, 130XE (MAME) |
| 3 | 29F133F7 | 800XE (MAME) |
| 3A | 0D477AA1 | 1450XLD, 3/23/1984 (OSROMS.TXT: both are "rev 3") |
| 3B | D425A9CF | 1450XLD, 6/21/1984 |
| 4 | 1EAF4002 | XEGS (OSROMS.TXT, 05/07/1987) |
| 5 | 0E000B99 | |
| 59 | 45F47988 | MAME calls this "Rev. 3B ?" (Arabic 65XE) |
| 59A | F0A236D3 | Offenga's OSROMS.TXT v3.3 calls this the Arabic 65XE's rev 3B, dated 7/21/1984. MAME and Offenga disagree on which dump is the Arabic one. |

XL/XE halves, each 8K. The $C000 half is $C000-$CFFF, then the self-test,
then $D800-$DFFF; the $E000 half is $E000-$FFFF. The 1200XL values are from
MAME (two chips). Revs 1-4 were split from Mike's ROM files (atari-os-romv33),
whose whole-image CRCs match the table above.

| Rev | $C000 half | $E000 half |
|---|---|---|
| 1 | C376D2F2 | 4502AF6F |
| 2 | F1E30A44 | 397BAA67 |
| 3 | 79E0D038 | 2C8B447A |
| 4 | 4A3AE4E5 | ACCF9678 |
| 10 (1200XL) | 0391386B | B502F1E7 |
| 11 (1200XL) | 6E29EC8D | D73CE29A |

Seen on Mike's MiSTer Atari800 core with its built-in ROMs (2026-11-07), and
not in any table found (atari800, MAME, JAC!'s ROM Checker): OS whole
72B08257, $C000 half 17640AF8, $E000 half 8B57241C, BASIC 5590539A, font sum
$DD47. These are probably the core's built-in replacement OS and BASIC. The
test reports them as UNKNOWN, which is correct.

BASIC, 8K at $A000:

| Rev | CRC32 | Notes |
|---|---|---|
| A | 4BEC4DE2 | |
| B | F0202FB3 | 600XL, 800XL (MAME CO60302A) |
| C | 7D684184 | 65XE, 130XE, 800XE (MAME CO24947A) |
| Arabic | C899F4D6 | MAME only (a65xea) |
| (rev A misloaded) | CCF05648 | Rev A loaded from a `.car` file as a raw 8K ROM, as the MiSTer core does when a `.car` is given as the BASIC ROM. The 16-byte CART header wraps, so BASIC sits 16 bytes on (verified on Mike's file, 2026-11-07). |

The ROM test names only A, B and C; anything else (the Arabic one, a
misload) is `UNKNOWN`, item 2: a failing BASIC, dirty contacts, or a
cartridge that isn't BASIC. The 1200XL has no BASIC (`NONE`).
On a 400/800 BASIC is a cartridge. The tapes and disks read it at $A000
(400/800: RAMTOP at most $A0 and $BFFC zero; XL/XE: TRIG3 says a
cartridge is in, else the built-in BASIC with PORTB bit 1): the OS boots
them before it would start the cartridge (OS rev B: cassette boot at
$F1E1 with no cartridge check, disk boot when $BFFD bit 0 is set, and
the boot enters the program at load+6 before the cartridge's start).
The diag cartridge can't read another cartridge: it takes the slot
itself, so its ROM test shows `BASIC NONE` on a 400/800. BASCRC checks
BASIC on its own against the same A, B and C values.

## 11. Open items

- [ ] Bit-to-chip tables for the 400, 800 (per 16K board), 800XL and
  130XE, from the schematics, so a RAM fault names its chip.
- [ ] The 130XE's ANTIC-access check (PORTB bit 5): a pattern in an
  extended bank shown on screen.
- [ ] The cartridge and the cassettes on a real machine, and a disk from
  a physical drive (so far the MiSTer; the boot disk and the executables,
  up to 0.11, ran on real machines over SIO2PC with AspeQt).
- [ ] The BASCRC tape (`ENTER "C:"`) confirmed on a MiSTer or a real
  recorder; BASCRC runs on an 800 (0.13).
- [ ] The refresh check seen to catch a real refresh fault (it catches
  the simulator's, `sim.py --leak`).
- [ ] The paddle test on a MiSTer (needs a paddle adapter that works with
  it); it is confirmed on real machines.
- [ ] ROM table gaps: OS rev B PAL (if it exists), the XEGS's 32K image
  (MAME D50260D1).
- [ ] The hardware facts checked line by line against *Mapping the Atari*.
- [ ] More test areas, if wanted: collision registers, every player and
  missile width and priority, DLI and VBI timing, POKEY's distortions,
  16-bit and high-pass modes, timer IRQs per clock, the PIA's lines one by
  one, cassette motor control.

## 12. Shelved

- **A RAM-less "dead test" cartridge:** the diagnostic-cart flag (bit 7 of
  the option byte at $BFFD) makes the OS jump to the cartridge very early,
  and a display could come from ROM with DMA off or by racing the beam.
  The AtariMax cartridge took the other road: it needs 8K of RAM and the
  OS, runs every test from ROM, and is the best way in all the same.
- **Executables (`.xex`), up to 0.11:** they needed DOS and 32K. The boot
  disk (0.10) boots with no DOS and needs 8K, so they went in 0.12
  (their design: [Atari-diag-disk-scope.md](Atari-diag-disk-scope.md) at
  the tag `v0.11`; that file is now the disk set's design).
- **Fast pot scan in the paddle test, up to 0.12:** it can't read
  paddles. The counts come out 114 times too high, and it turns off the
  transistors that empty the capacitors (Altirra Hardware Reference
  Manual, 5.9).

## 13. Status at 0.13 (2026-11-19)

All formats run on the MiSTer Atari800 core as a 400/800 and as an XL/XE
(64K, and a 128K 130XE). The executables (up to 0.11) ran on a real 800
and 800XL over an SIO adapter, where the joystick and paddle ports were
tested. Where the author has tried them, the results have been right: the
RAM banks and their beeps, the ROM names, the self-checks, BASIC by test 1
and by BASCRC on an 800.
