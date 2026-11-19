# A8 Atari Diag Suite: development

By **Michael Grimm**, written with Claude (Anthropic's AI). Free to use,
copy, change and share under the [MIT license](../LICENSE); please keep
the credit when you pass it on.

This is for anyone who wants to build the programs from source, change
them, or check how they work. To test a machine you only need the release
files (`carts/`, `disks/`, `disk-set/`, `cassettes/`) and the [user guide](USER-GUIDE.md).

## Contents

1. [Authorship and how the work is done](#authorship-and-how-the-work-is-done)
2. [Environment](#environment)
3. [Building](#building)
4. [The programs](#the-programs)
5. [How a program runs](#how-a-program-runs)
6. [The reporter and the keys](#the-reporter-and-the-keys)
7. [Memory and byte budgets](#memory-and-byte-budgets)
8. [The rules the code keeps](#the-rules-the-code-keeps)
9. [Source layout](#source-layout)
10. [The simulator](#the-simulator)
11. [Documentation pictures](#documentation-pictures)
12. [Lessons learned](#lessons-learned)
13. [Contributing](#contributing)
14. [Attributions](#attributions)

## Authorship and how the work is done

The author has programmed 6502 machine language and assembler since
childhood. Even so, the code, tools and documents here are, for now, 100%
written by AI (Claude, by Anthropic). The author directs the work, reviews
it and tests it on hardware.

The project grew over many sessions in November 2026, with the author
trying each build and deciding what changes; the design moved a lot along
the way, and the documents describe where it ended up, not every step. The
version history in the [README](../README.md#versions) has the steps.

How a change is tested:
- **The simulator** (below) first, but only as much as the change needs:
  the assembler's own checks (sizes, `.error` guards), then one short run
  of the screen that changed. Long regression runs slowed the work down
  more than they caught.
- **The author's MiSTer** (Atari800 core): every build is copied to its
  share at once (see [Building](#building)), in the order cartridge, disk
  file, tape (the cartridge is quickest to try). It is the development
  set-up, not a machine anyone diagnoses: the user documents name only
  real machines as ways to run the tests.
- **Real hardware:** an 800 and an 800XL, with the disks over an SIO
  adapter (the cassettes can't be played in that way). The joystick and
  paddle ports get their real test there; the MiSTer has no working
  paddle adapter.
- **The video test** (test 7: the ramps, the moving ATARI sprites, the
  video modes page) is judged by eye on the MiSTer by the author: the
  simulator can't draw sprite motion or the ANTIC/GTIA modes.

## Environment

| What | Version | Notes |
|---|---|---|
| Windows 11 | | any OS with Python and MADS works |
| [MADS](https://github.com/tebe6502/Mad-Assembler) (Mad-Assembler) | 2.1.9 | put `mads.exe` in `tools/bin/` (not in git) |
| Python | 3.12 | |
| [py65](https://github.com/mnaberez/py65) | 1.x | `pip install py65`: the 6502 core in the simulator |
| [Pillow](https://python-pillow.org/) | 13 | `pip install pillow`: the documentation pictures |
| [NumPy](https://numpy.org/), [soundfile](https://github.com/bastibe/python-soundfile) | | only `tools/mkhello.py`, to remake the "hello" sample |
| MiSTer Atari800 core | | the hardware tests (with an SIO adapter for real machines) |

## Building

```
python tools/build.py              # everything: build/ (all output), and the releases in cassettes/, disks/, disk-set/, carts/
python tools/build.py --nodeploy   # the same, without copying the changed files to the MiSTer share
python tools/build.py --fault 2,5  # extra builds with a stuck bit 5 in bank 2, to hear a fail code
python tools/build.py --fast       # skip the $55/$AA march pass (quicker simulator runs); build/ only
```

The version is `VERSION` in `tools/build.py`. It goes into every release
file's name (`cassettes/diag-...-v0.13.cas`; `build/` keeps the plain
names, which the simulator examples below use) and onto every title bar
(`screen.asm`'s header: one digit before the point, one or two after, in
five columns). A patch level (`0.13.1`, `VPAT`) would take seven, and the
longest titles (test 3 and test 7's modes page on `diag-16k-02-system`)
would then leave the version out. A
build removes the release files of other versions.

Every build copies the release files that changed to the share (`SHARE`
in `tools/build.py`: the author's MiSTer `_diag` folder; change it for
yours), so a new build can be tried at once. A copy that fails prints `NOT
deployed` and the build goes on. FAST and fault builds are never copied.

## The programs

### The cassettes

`TAPES` in `tools/build.py` lists them, each with its builder and
defines. Each tape that needs more than 8K has `NEEDPG`, the RAM it needs
in pages ($40 = 16K, $80 = 32K): its boot code compares that with the OS's
RAMTOP ($6A) before it touches anything else, and halts below it (red
border, the low tone on and off).

| Builder | Tapes | How |
|---|---|---|
| `tape1` | `diag-8k-01-ram` | `src/tape1/main.asm`, stage 1 (fits 8K), then `stage2.asm` as a second file on the tape, loaded through the OS's SIOV on 16K and up. `-part2.cas` is stage 2 alone, for players that can't wait. |
| `system` | `diag-8k-02-rom` ... `-06-video`, `diag-16k-02-system`, `diag-16k-03-hello`, `diag-controls` | `src/system/main.asm`; the `WANT_*` defines pick the tests, `MENU` adds the menu, `TAPENO`/`SETNO` the names and the "next tape" line |
| `build_one16` | `diag-16k-01-ram` | stage 1 (`ONE16`) with stage 2 inserted into the same image at the address it was built for, one load |
| `build_one32` | `diag-32k-xl-xe` | stage 1 (`ONE32`), stage 2 and the system tests in one image; the addresses depend on the sizes, so a few rounds settle them |
| `tape2` | `diag-8k-memtest` | `src/tape2/main.asm` with `OWNTEST` (page-tests its own RAM), `NOXL` |
| `build_bounce` | `diag-16k-memtest` | the same source with `BOUNCE`: two copies that take turns, each testing the other's RAM; a relocation bitmap made by assembling at $0800 and $0C00, checked byte for byte against both |

`tools/mkcas.py` writes the `.cas`: FUJI and baud chunks, then the boot
records ($55 $55 sync, control byte $FC/$FA/$FE, 128 bytes, checksum),
with the boot header in the first record. Every file on a tape ends in an
EOF record: the OS boot reads one record past its count.

Up to 0.11 the 32k+ image and the long memory test were executables too
(`.xex`, [Atari-diag-disk-scope.md](design/Atari-diag-disk-scope.md)); the
boot disk does what they did, and 0.12 dropped them.

### The boot disk

`disks/diag-disk.atr` (single density, 720 sectors) is the cartridge
rebuilt for a disk: the same programs as its banks, each a "piece" loaded
from the disk when it is needed. Design and reasons:
[Atari-diag-boot-disk-scope.md](design/Atari-diag-boot-disk-scope.md).

| Piece | Built from | Load | Sectors (0.13) |
|---|---|---|---|
| boot | `src/disk/boot.asm`: the short check, then the RAM piece for this machine | $0600-$07FF | 1-4 |
| RAM8 | tape 1's stage 1 with `DISK` (no ONE16): RAM above it, then its own RAM page by page (`ownram`) | $0900-$1BFF | 38 |
| RAM16 | tape 1 with `ONE16` and `DISK` (`build_one16(disk=True)`) | $0900-$24FF | 56 |
| MENU, ROM, INPUT, PORTS, SOUND, VIDEO | `src/system/main.asm` with `DISK` and the `WANT_*` of each (the menu: `MENUPC`) | $0900, at most $1BFF | 30-38 |
| HELLO | the recording packed (`build/hello-pak.bin`, `hello_pak`), data | $1C00-$2AFF | 30 |
| MEM | tape 2 with `BOUNCE`, `CART` and `DISK` | $0800 | 60 |

- Every piece but HELLO has the tape image's 6-byte header (mkatr reads
  its record count and load page) and is entered at LOAD+6 (a RAM piece's
  LOAD+9: the RAM test again from the menu). The results page (BSS) is
  $0800 for all of them, as on the cartridge; the RAM pieces put the
  screen where no later piece loads ($1C00 under 16K, $3C00 from 16K:
  `RAMPC` in `display.asm`).
- `src/disk/dload.asm`, in every piece: `dchain` (X = piece, A = entry
  offset) and `dfetch` (load and come back: HELLO) set up the OS's SIO
  control block, its VBI vectors and shadow registers, copy the loader to
  page 7 and jump there; it reads the sectors with SIOV, turns the
  interrupts off and enters the piece. A disk error waits for a key and
  reads the sector again. `build/disktab.asm` (written by
  `tools/mkatr.py`) gives each piece's first sector, count and load page.
  `dsum`: a system piece's own sum, checked at its entry. Each has only
  what it uses: `DLFETCH` (the RAM pieces, which keep the whole loader,
  and the sound piece, for HELLO) has `dfetch` and its way back; `DLBOOT`
  (the boot: no screen yet, the loader already in place at $0700, one
  way) has no messages, no copy, and none of the screen's or the VBI's
  set-up.
- The boot sectors give the short check (`src/common/stuck.asm`) before
  anything loads, with the OS's VBI off, ANTIC off and POKEY out of SIO's
  serial state, and S set back to $FF after it; the pieces leave it out
  (`DISK`).
- `XREQ` says why a piece was loaded, as on the cartridge (0 the menu, 1-7
  that test, 8 the long test, 9 the results; $80 the RAM piece's power-on
  hand-over, `src/disk/ramhand.asm`). In `system/main.asm`, `SPLIT` makes
  the tests of other pieces thunks (`xgo`, `tpiece`); the menu screen and
  the power-on start are only in the menu's piece (`MENUCODE`,
  `NEEDTRUN`), the results page only in the ROM test's (`RESPAGE`).
- `build_disk` builds every piece twice: the layout table's size is
  fixed, so the second round, with the real table, settles it; then the
  sums (`mkatr.patch_piece`) and the image.
- The long test's way back is the cartridge's: the mark $5A $A5 at
  $07FE, then the 16K+ RAM piece's power-on entry, which skips the RAM
  test and goes to the menu.

### The disk set

`disk-set/` holds the 8k tapes as disks (`build_diskset`), each named as
its tape and holding the tape's own program, byte for byte:
`mkatr.cas_image` takes it from the tape file (the $FC records, as many as
the header counts), so the title bars and `NEXT:` lines name the disks.
A tape program boots from a disk unchanged: the OS's disk boot reads the
same 6-byte header (flags, sectors, load, init), loads the sectors to LOAD
and calls LOAD+6, as the cassette boot does, and the program sets up the
machine itself (`common/boot.asm`: POKEY, ANTIC, the motor).

| Disk | Sectors | How |
|---|---|---|
| `diag-8k-02-rom`, `-03-input`, `-04-ports`, `-06-video` | the program from sector 1 (`mkatr.plain`) | booted by the OS |
| `diag-8k-01-ram` | part 1, then part 2 | part 1 built with `DSKLD`: `loader.asm` reads part 2 from the sectors after its own (sector `(IMGEND-LOAD)/128+1` on) through SIOV, a sector at a time into the cassette buffer, instead of the tape's records; part 2 is the tape's (`build_diskset` stops if it isn't) |
| `diag-8k-05-sound`, `diag-8k-memtest` | boot (4), the 8K program, the 16K one (`mkatr.choice`) | `src/disk/setboot.asm`: RAMTOP under $40 the tape's program, else the 16K one, loaded by `dload.asm`'s DLBOOT from `build/settab.asm` (`SETTAB`) and entered at $0806. The 16K sound program is `system` with `HELLO16` (`SAMPLED` with the recording in the image, as `diag-16k-03-hello`), named as the 8k sound tape; the 16K memtest is `diag-16k-memtest`'s |

`disks/diag-16k-memtest.atr` is `diag-16k-memtest`'s program the same way
(`mkatr.plain`).

### The cartridge

`carts/diag-cart.car` is an AtariMax 128K (`.car` type 41: 16 banks of 8K
at $A000-$BFFF; a write to $D500+n selects bank n, $D510 switches the
cartridge off). The tests run from ROM, so they need 8K of RAM and no
loading. `build_car` assembles the code banks with `ROM=1` and
`tools/mkcar.py` packs them (`src/cart/romsum.asm` has the layout):

- **Bank 0, the RAM test:** `tape1/main.asm` with `stage2.asm` in the same
  image, as the one-load 16k tape. `boot.asm`'s ROM variant doesn't change
  its own code. It also looks for RAM under the cartridge at every start
  and tests it (`src/cart/undercart.asm`: the cartridge switches itself
  off from a routine in low RAM).
- **Banks 1 and 2, the system tests:** `system/main.asm` twice, with tests
  1-3 and 4-7. Both have the menu and list all seven; a test in the other
  bank is a thunk that sets `XREQ` and switches (`OTHER`).
- **From bank 3:** the long memory test's image (`CARMEMBK`), which
  `src/cart/ldmem.asm` copies to $0800 before switching the cartridge off;
  at its end it switches bank 0 back in and the cartridge skips straight
  to the menu (two marker bytes at $07FE). After it: the "hello" sample in
  a bank of its own (`HELLOBK`), played from low RAM.

BSS is one page of RAM at $0800 shared by all the banks, so results travel
with a bank switch. Every bank ends with the same 32 bytes (mkcar's
`TAIL`): the power-on jump to bank 0, the bank's sum at $BFEE, the switch
at $BFF0 (`sta $D500,x` / `jmp $A003`: the instruction after the write
comes from the new bank, which holds the same bytes), each code bank's
CRC32 at $BFF6, and the cartridge header.

## How a program runs

`src/common/boot.asm` is the start of every program:

1. **Alive:** SEI, NMIEN = 0, the screen off, green border and a chirp.
   Until low RAM has passed, nothing uses the stack or zero page: calls
   go through `NCALL` (the return address in a BSS vector, one per call
   level).
2. **The image checksum.** A bad sum is the code long ×1, then the end
   tone: the RAM it loaded into is suspect.
3. **The low RAM test**, $0000-$07FF, non-destructive.
4. **The RAM size** (one probe per 4K; a block with a few dead bits still
   counts as RAM, an empty bus doesn't), the machine (400/800 or XL/XE by
   the direction of the PIA's port B, which the OS sets: an idle bus at
   $C000 can read back anything), the RAM under an XL/XE's OS and a 130XE's
   extra banks.
5. **The display prerequisites** (`display.asm`): VCOUNT counts, the
   character set reads the same twice, and a 1K screen block that tests
   good. Only then does text appear; without them the program reports by
   beeps and the border alone.

The programs with the ROM test also check themselves: see
[The ROM test's self-check](#the-rom-tests-self-check).

### The shared library and one-load images

`src/common/lib.asm` is the code every program shares: the reporter
(`report.asm`), the text screen (`screen.asm`, with the title-bar name from
`name.asm`), the machine line (`info.asm`) and the RAM test engine
(`ramtest.asm`). The macros and constants are in `defs.asm`.

A one-load image (the 16k RAM tape, the 32k+ tape, the
cartridge's RAM bank) has the library once, in stage 1 (`SHLIB`). Its
later parts are separate assemblies: build.py writes `build/shlib.asm` from
stage 1's label table, every label between `LIBBEG` and `LIBEND` except
the branch labels inside routines (`xx_yy`), and those parts include it
instead of the modules. What the parts do differently, the reporter
decides at run time: `SYSMODE` (the system tests: a beep code only for the
ROMs and the RAM) and `REDRAWV` (the screen OPTION brings back).

### The ROM test's self-check

The ROM test also checks the program it is part of (`selfchk`, item 6).
A tape or disk piece with the ROM test ends in the image sum and then 4
more bytes, `CRCFIX`. `mkcas.py`'s `patch_boot` puts there the CRC32 of the
image from `CRCAT` up to them, as it is in RAM once the boot has run (the
page operands boot.asm changes as it runs at their final values), so at
run time the CRC from `CRCAT` to the end leaves the register at the CRC32
residue, $DEBB20E3, whatever the program: there is no per-build constant
in the code. On the cartridge `mkcar.py` stores each code bank's CRC32 of
$A000-$BEFF at $BFF6 (a code bank's code must stay below $BF00), and the
ROM test switches each bank in from a routine in low RAM to compare.

The ROM names come from section 10 of the
[design document](design/Atari-diag-cassette-scope.md): published CRC32s, never
the values of one machine.

BASIC (`basread`): a cartridge if one is in, else an XL/XE's built-in
ROM. The OS boots a tape (START held) or a disk with a cartridge in, and
enters the booted program (JSR load+6) before it would start the
cartridge (OS rev B's cold start, $F1E1-$F20F, and its boot loader,
$F301-$F37B), so the programs see a BASIC cartridge at $A000. They find
one as the OS does: on a 400/800 no RAM at $A000 (RAMTOP) and $BFFC zero
(an empty bus reads $BF there); on an XL/XE TRIG3 = 1. The diag
cartridge has the slot, so on a 400/800 it reports none.

## The reporter and the keys

`src/common/report.asm` turns results into border colours and beeps. The
tone table (`tt_frq`, `tt_col`, `tt_len`, `tt_gap`) holds every sound:
the long, short and end tones of a code, the charge (G4 C5 E5 G5) for a
pass, the long green flash per bank, "impending doom" (C4 C4 F#3) before a
fail, and the ROM test's lower pair. `pass`, `report` (a fail) and
`partial` (the final result when nothing failed but not every test ran:
steady yellow and the start-up chirp) all end in `hold`, which waits, for
as long as it takes, on `inputs`:

| Bit | Inputs | Does |
|---|---|---|
| 0 | START, any other key, a joystick button | go on: `CONTVEC`; none set (the end of a tape): the tones again |
| 1 | SELECT or T | the tones again (`HSEL`) |
| 2 | OPTION or F | full-screen flashes on and off (`scrtoggle`; only with a working display) |
| 3 | R | re-test: `RETESTV`, where one is set |

A press only counts after all the inputs were seen released (`HARMED`), so
a stuck key never fires; a tap of START during a tone is latched
(`SLATCH`). `RETESTV` is set only where there is no menu: the RAM tapes'
summaries, the end of every tape without a menu (`trestart` runs its
tests again) and the memory test's summary. `ENDING` marks the end of a
program (2: the final results, the charge twice). `QUIET`: once the
picture is confirmed and the text is up, the border stays steady and a
code plays once.

One result goes on by itself: the RAM summary where the ROM test follows
(the cartridge and the 32k+ image: stage 2's `GOMENU`). Stage 2 sets
`AUTON` to 3; `pass` and `report` (`RPAUTO`, the shared library) count a
round at each pause and, at the third, jump to `CONTVEC` as a press would.
`waitrel` clears `AUTON`, so any press stops the count: T and OPTION then
leave it waiting. The 8k and 16k RAM tapes never set it.

**The joystick** (`joyc`, `src/common/report.asm`, in every build) stands
in for the console keys on every screen: fire = START, down = SELECT, up =
OPTION, in port 1 or 2 (left and right are the paddles' triggers). It
reports only presses since the last look (`JPREV`), so a stuck stick counts
once and never blocks `waitrel`; each place that polls it primes it first
with one call. `inputs` (every result, `waitrel`, the memory test's stop
check) ORs it into its bits, so the reporter takes down and up as SELECT
and OPTION too, and `rpkey` keeps a press it doesn't act on (one seen
after a tone) in `SLATCH` for the next pause: a stick's press is only seen
once. The menu, `yesno`, `gans` (test 7), the "hello"'s answer and the
keyboard and console key tests call `joyc` directly. `inputs` now uses Y,
so the memory test's raw NMI (`nmiraw`, OS switched out) saves X and Y.
The boot disk's loader (`dl_in`) takes fire and START as a new press the
same way. `FIREONLY` (`diag-8k-memtest`, no room for `joyc`): `inputs`
takes fire only, also as a new press.

**The short check** (`src/common/stuck.asm`, included by `boot.asm`
right after the hardware is reset, in every build's start; on the boot
disk, by its boot sectors instead): a joystick line in port 1 or 2
already active at power-on is stuck (a switch shorts its line to ground).
It gives a signal, not an alarm: three shots, each a pure-tone beep
falling from 1.9 kHz to 250 Hz with COLBK bright orange ($28), then a gap,
quiet and near black ($A0 in both AUDC1 and COLBK). Each shot and its gap
is one count of Y ($10-$7F the beep, AUDF1 = Y; $80-$FF the gap), a step
every S scan lines: S is 16, 12, then 8, so the shots get quicker and the
two gaps differ (0.13 s, 0.1 s); about half a second in all. Registers
only: no RAM has been tested yet, so the step lives in the stack pointer
(nothing is pushed until low RAM passes and `lr_pass` sets S). It is 62
bytes; `diag-8k-03-input`, the fullest tape, has 2 bytes left (0.12). `joyc` keeps the
line from blocking anything. `NOSHORT` leaves it out (`diag-8k-memtest`:
no room).

## Memory and byte budgets

- **BSS** is one page right after the image (`src/common/vars.asm` has the
  map): untested by the RAM test, and the only RAM trusted before low RAM
  passes. The cartridge's is at $0800; the 32k+ image keeps it inside the
  image, below $4000.
- **The screen** is a 1K block (40×24 text at $000-$3BF, the display list
  at $3C0), found by testing candidates: just above the program, then the
  top 1K of each 16K bank.
- **8K images** (the 8k tapes, `diag-8k-memtest`, the 8k RAM tape's
  stage 1) load at $0800 and must end by $1AFE (the sum), with BSS at
  $1B00 and the screen at $1C00-$1FFF. Several are within a few bytes of
  that; `display.asm`'s `.error` stops the build when one is over. Ways
  that have made room: shorter strings, inlining a routine called once,
  tail calls (`jmp` for `jsr`/`rts`), and leaving out of a format what it
  can't use. `diag-8k-memtest` is the fullest: it builds with `FIREONLY`
  and `NOSHORT`. The boot disk's RAM8 ($0900-$1BFF) and the page-7 loader
  (250 of its 254 bytes) are close too.
- **The 130XE window:** a 130XE switches its extra banks in at
  $4000-$7FFF, so the code and BSS that test them must be below $4000.
- **The XL/XE self-test ROM** appears at $5000-$57FF when PORTB bit 7 is 0:
  a screen there must be off while the ROM test reads it.

## The rules the code keeps

These came from the author's direction over the sessions:
- **Colour and beeps first**, text only after the screen is proven. Every
  flash has a beep, so a result reads by eye or by ear.
- **No timeouts and no timers** after boot: every question and every
  result waits for as long as it takes. A sound being asked about repeats
  until the answer. The one exception (Mike's call, 2026-11-16): the RAM
  summary where the ROM test comes next goes on after its code has played
  three times, so a machine left alone runs on; a press stops the count.
- **Two keys for everything:** each action has a console key and a
  keyboard key (R, T/SELECT, F/OPTION, any other key), so one dead key
  never traps you. "Any key" means any key, START included.
- **R only where there is no menu:** a menu picks a test again, so it needs
  no re-test key.
- **Each format carries only the code it can run:** the RAM builds are as
  small as they can be; the cartridge may have extras (the RAM under it,
  the sampled "hello" in its own bank).
- **The same numbers everywhere:** 0 RAM, 1 ROMs, 2 keyboard, 3 console
  keys, 4 joysticks, 5 paddles, 6 POKEY, 7 GTIA/ANTIC, 8 the results, 9 the
  long memory test.
- **A test relies only on what was proven before it:** RAM before anything
  runs from it, the keyboard before a question is asked.
- **Comments say why**, not what the instruction does.

## Source layout

| Path | What |
|---|---|
| `src/common/` | shared: `boot.asm` (alive, checksum, low RAM, size probe), `stuck.asm` (the short check), `display.asm` (screen prerequisites), `report.asm` (the reporter and keys), `screen.asm`, `info.asm`, `ramtest.asm`, `pagetest.asm` (a program's own RAM, page by page), `xlram.asm` (RAM under the OS, 130XE banks), `loader.asm` (a tape's second stage; `DSKLD`: from the disk set's RAM disk), `vars.asm`, `defs.asm`, `hw.asm`, `name.asm` (the title-bar names), `lib.asm` |
| `src/tape1/` | the RAM test: stage 1 and stage 2 |
| `src/tape2/` | the memory test (`diag-8k-memtest`, `diag-16k-memtest`, the cartridge's) |
| `src/system/` | tests 1-7: `main.asm` builds a program from the tests `WANT_*` picks; one file per test (`t_rom`, `t_kb`, `t_con`, `t_joy`, `t_pad`, `t_pok`, `t_gtia` and `t_gtia2`, its video modes page); `common.asm` the flow, the menu and the end of a tape; `tlist.asm` the order; `kbmap.asm` the keyboard map (`tools/gen_kbmap.py`) |
| `src/cart/` | the cartridge: `romsum.asm` (bank layout, sums), `ldmem.asm` (the long test's loader), `undercart.asm` (the RAM under it), `hello.asm` and `audio/` (the sampled "hello", made by `tools/mkhello.py`) |
| `src/disk/` | the boot disk's boot sectors (`boot.asm`), loader (`dload.asm`) and the RAM pieces' hand-over (`ramhand.asm`); the disk set's two-program boot (`setboot.asm`) |
| `tools/` | `build.py`, `mkcas.py`, `mkcar.py`, `mkatr.py` (the disks), `mkhello.py`, `sim.py`, `antic.py` (the simulator's picture of a screen with more than text: test 7's modes page), `disktest.py` (the boot disk's checks), `docshots.py`, `gen_kbmap.py` |
| `cassettes/`, `disks/` (the boot disk, the 16k memtest's), `disk-set/` (the 8k tapes as disks), `carts/` | the release files |
| `docs/design/Atari-diag-cassette-scope.md` | the design: constraints, feedback, sets, the ROM table, open items |
| `docs/design/Atari-diag-disk-scope.md` | the executables' design (`.xex`, up to 0.11) |
| `docs/design/Atari-diag-boot-disk-scope.md` | the boot disk's design |

## The simulator

`tools/sim.py` runs a program on a cycle-timed 6502 (py65), with 114
cycles a scan line and a floating bus. It models:
- the cassette boot, and later stages read through a stand-in for SIOV;
  a `.xex` loaded as DOS loads it (`--memlo`); a `.car` (AtariMax 128K),
  with the bank switches and the cartridge switching itself off; an `.atr`
  (the OS's disk boot, disk reads through SIOV at an 810's pace, a sector
  that fails with `--diskerr SECTOR[:TIMES]`, and the OS's own VBI doing
  its shadow copies)
- RAMTOP as the OS sizes it (`--ram`), XL/XE banking (`--xl`), the 130XE
  (`--xe`, `--xejunk` for extended RAM full of random bytes as at
  power-on), the self-test ROM
- RAM faults: stuck bits (`--stuck`), flaky bits (`--flaky`), mirrored
  banks (`--mirror`)
- the VBI, the keyboard (`--key SECS`, `--kb CODE:SECS[:HOLD]`), console
  keys (`--con KEY:SECS[:HOLD]`), joystick 1 (`--joy UP|DOWN|LEFT|RIGHT|FIRE:SECS[:HOLD]`),
  paddles, POKEY's interrupt latches
- real OS and BASIC ROMs (`--osrom`, `--basic`), or made-up ROM bytes
  without them; `--forge` gives the made-up 400/800 OS chips chosen CRC32s

It prints the screen as text (`--snap`), decodes the beep code, and saves
pictures (`--shot`, `--shoton`). `--auto` answers the prompts and presses
on at each result as a person would; `--menuwalk` runs the menu's tests one
by one. For debugging, `SIM_IMGDIFF=1` lists the image bytes that changed
in RAM, and `SIM_DUMP=LO-HI` dumps memory at the end.

What it can't show: horizontal sprite positions and motion, and ANTIC
going astray when the memory under its display list changes. The other
ANTIC modes and fine scrolling it draws only as a still (`antic.py`, for
the guide's picture of test 7's page 2). Those need the MiSTer or a real
machine. py65 is pure Python, so a run takes minutes (the video test's
screens are slowest).

```
python tools/sim.py build/diag-8k-03-input.cas --auto --until 90
python tools/sim.py build/diag-8k-01-ram.cas --stuck 2:5:1 --until 200
python tools/sim.py build/diag-cart.car --ram 0xC000 --kb 3E:1 --snap 14 --until 14
python tools/sim.py build/diag-disk.atr --ram 0x2000 --auto --until 200
```

`tools/disktest.py` runs the boot disk's checks (a fast build of it, in
the simulator): the boot on 8K and 64K, a disk error, both RAM pieces and
a fault in RAM8's own RAM, the menu, each test from it, the results
page, the long test and back, 8K
without the "hello", a joystick button stuck from power-on (`stuckfire`)
and stick up on a result (`stickup`). A check can ask for text between
two times (`(after, by, text)`), and any run where the simulator reports
a POKEY voice 3 or 4 turned on while SKCTL's serial mode holds it silent
fails. All of them take about an hour.

## Documentation pictures

`python tools/docshots.py` runs the simulator on the release builds (the
tapes, the cartridge, and for its menu picture the boot disk,
`build/diag-disk.atr`) and saves the screens in `docs/img/`. It needs
real ROMs (`--sysroms`) for the font and the ROM names, and the MiSTer
core's palette (`--palette`, `ntsc.act`), so the colours are the core's.
Neither is in this repository.

Each scenario in `RUNS` takes a picture a set time after some text first
shows on screen; a trigger that starts with `^` must start a screen row
(the RAM tapes' page test shows the program's own strings in the top
rows). With `--auto` the simulator presses on about 0.25 s after a result
appears, so those pictures use a short delay. `ANNOT` holds the numbered
callouts; `--annotate` redraws them without running anything. The raw
screens go to `docs/img/raw/` (not in git). The video test's first
picture (`av-02-gtia`) is left out of the runs: the simulator can't draw
its moving sprites as they really look. Its second page, the video modes
(`av-03-modes`), is drawn by `tools/antic.py`, which `sim.py`'s picture
hands any display list with more than GRAPHICS 0 text: the bitmap and
GTIA modes, the scrolls, and the registers as they were on each scan
line (no players or missiles). The 16k menu pictures walk tests 1-6 by
their keys and then open line 8, the results (`--walk 1234568`); test 7
shows there as not run. (The simulator's 32k+
menu doesn't take the number keys, so it has no results picture of its
own: the page is the same.)

## Lessons learned

Notes from the sessions, for whoever works on this next.

**MADS**
- Labels are case-insensitive: a macro or routine named like a variable
  (`DELAY`/`delay`, `chsum`/`CHSUM`) clashes.
- `.if .def X .or .def Y` doesn't do what it reads as: use `.ifdef X` /
  `.elseif .def Y` chains. A wrong one here once blanked the menu's names.

**The hardware**
- A 400/800 has nothing at $C000, and an idle bus reads back anything:
  tell the machines apart by the PIA port B direction, not by a byte.
- ANTIC's blank-line instructions ($x0, $70 included) have no address,
  even with bit 6 set: test the low nibble before taking bit 6 as LMS. A
  display list generator that got this wrong scrolled the whole page.
- A cartridge in a 400/800 disables the RAM under it in hardware: no
  program can see it (a 48K 800 with BASIC shows 40K). An AtariMax can
  switch itself off ($D510) and back on (a bank select), which is how the
  diag cartridge counts and tests that RAM.
- With a cartridge in, a 400/800 won't boot a cassette, but a disk boots.
- The OS's cassette boot reads one record past the count it was given:
  every file needs its EOF record.
- The sampled sound plays with the screen off: ANTIC takes the processor
  on every line it draws, which makes the samples late and uneven.
- Anything a program changes in itself (the boot's page operands) must be
  at its final value in the CRC the build stores.
- Counting a RAM test's banks by "was there something to test above the
  program" misses bank 1 when the program sits above $4000 (the 32k+
  image): count the banks the RAM reaches.

**The MiSTer Atari800 core**
- Its "Boot Tape" holds START and boots the tape; "Load Tape" only mounts
  it (for a BASIC `ENTER "C:"`). It can't rewind: loading the image again
  starts it over. It pauses the tape while the motor is off, so a second
  stage loaded minutes later still works.
- Its built-in OS and BASIC are replacements, not Atari's (their CRC32s
  are in no table: `UNKNOWN` is right). A `.car` given as the BASIC ROM
  loads 16 bytes off (the header wraps): see section 10 of the design.

**Working on it**
- The simulator found real bugs in the pictures (a ramp over its label,
  lost key marks, a stale FAIL), so the pictures are worth regenerating
  after a screen changes.
- The 8K images are tight: check the free bytes (`build/*.lab`) before
  adding to one, and expect the `.error` guard rather than a crash.

## Contributing

Issues and pull requests on GitHub are the way to reach the author (email
isn't checked). Reports from real hardware are as welcome as code: the
machine, OS revision and RAM, the file, and what the screen and the beeps
said.

To add a test to the system tapes:
1. A file `src/system/t_xxx.asm` with the test, ending through `tend`
   (the result: `BADMASK+test` holds the failed items as bits).
2. A `WANT_XXX` define, its `icl` in `system/main.asm`, its entry in
   `tlist.asm` and its name in `common.asm`'s `tnames`.
3. The tapes that get it in `TAPES` (`tools/build.py`); watch the 8K
   budgets.
4. A short simulator run (`--auto`), a picture in `docshots.py` if it has
   a screen, and its items in the user guide's item table.

Keep [the rules](#the-rules-the-code-keeps): no timers, two keys for
everything, the same test numbers everywhere.

## Attributions

- **ROM identification:** the CRC32 table combines these sources (the
  design document, section 10, records how they cross-check):
  - the [atari800 emulator](https://github.com/atari800/atari800)'s
    `src/sysrom.c`, for whole images;
  - [MAME](https://github.com/mamedev/mame)'s `src/mame/atari/atari400.cpp`
    and `hash/a800.xml`, per chip and for the BASIC cartridges;
  - Freddy Offenga's *Atari 8-bit Operating Systems* (OSROMS.TXT v3.3),
    for dates, systems and part numbers.
- **The "hello" recording:** `En-us-hello.ogg` by Dvortygirl, on
  Wikimedia Commons, public domain; prepared by `tools/mkhello.py`.
- **Tools:** [MADS](https://github.com/tebe6502/Mad-Assembler) by Tomasz
  Biela (Tebe); [py65](https://github.com/mnaberez/py65) by Mike
  Naberezny; [Pillow](https://python-pillow.org/).
- **Testing:** the [MiSTer Atari800 core](https://github.com/MiSTer-devel/Atari800_MiSTer);
  [AspeQt](https://sourceforge.net/projects/aspeqt/) (Fatih Aygün and
  contributors) for cassette playback over SIO2PC.
- **References:** *Mapping the Atari* (Ian Chadwick), the *Altirra Hardware
  Reference Manual* (Avery Lee), *De Re Atari*, Atari's OS and hardware
  manuals. The hardware facts come from general Atari knowledge and these
  works; a line-by-line check against *Mapping the Atari* is still an open
  item.
- **Prior art:** Atari's SALT and Super SALT diagnostic disks, and
  Sys-Check.
- The programs contain no Atari ROM code. The simulator and the pictures
  used the author's own ROM files, which are not distributed here.
