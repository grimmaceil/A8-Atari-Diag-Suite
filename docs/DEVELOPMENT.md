# A8 Atari Diag Suite: development

Free to use, copy and share. Please credit **Michael Grimm** (and
Claude, the AI that helped write it) when you pass it on.

This is for anyone who wants to build the tapes from source,
change them, or check how they work. To test a machine you only need the `.cas` files in
`cassettes/` (or the `.xex` files in `disks/`) and the [user guide](USER-GUIDE.md).

## Authorship

The author has programmed 6502 machine language and assembler since
childhood. Even so, the code, tools and documents here are, for now, 100%
written by AI (Claude, by Anthropic). The author directs the work, reviews it
and tests it on hardware: a MiSTer Atari800 core so far.

## Environment

The tapes were built and tested with:

| What | Version | Notes |
|---|---|---|
| Windows 11 | | any OS with Python and MADS works |
| [MADS](https://github.com/tebe6502/Mad-Assembler) (Mad-Assembler) | 2.1.9 | put `mads.exe` in `tools/bin/` (not in git) |
| Python | 3.12 | |
| [py65](https://github.com/mnaberez/py65) | 1.x | `pip install py65`: the 6502 core in the simulator |
| [Pillow](https://python-pillow.org/) | 13 | `pip install pillow`: only for the documentation pictures |
| MiSTer Atari800 core | | the hardware tests so far |

## Building

```
python tools/build.py              # every tape, disk file and the cartridge: build/ (all output), cassettes/, disks/ and carts/ (the releases)
python tools/build.py --nodeploy   # the same, without copying the changed tapes to the MiSTer share
python tools/build.py --fault 2,5  # extra builds with a stuck bit 5 in bank 2, to hear a fail code
python tools/build.py --fast       # skip the $55/$AA march pass (quicker runs); build/ only, the releases aren't touched
```

The version is `VERSION` in `tools/build.py`. It goes into every release
file's name (`cassettes/diag-...-v0.4.cas`; `build/` keeps the plain names,
which the simulator examples below use) and onto every title bar
(`screen.asm`'s header). A build removes the release files of other
versions.

Every build copies the release tapes that changed to the share
(`SHARE` in `tools/build.py`, the MiSTer core's `_diag` folder), so a new
build can be tried on the MiSTer at once. A copy that fails (the share
offline, or a tape in use) prints `NOT deployed` and the build goes on.
FAST and fault builds are never copied.

`tools/build.py` holds the list of tapes (`TAPES`) and the share path
(`SHARE`). Each tape that needs more than 8K has `NEEDPG`, the RAM it needs
in pages ($40 = 16K, $80 = 32K). Its boot code compares that with the OS's
RAMTOP ($6A) before it touches anything else, and halts below it (red
border, the low tone on and off). So every tape runs on any machine with
at least its RAM, and stops clearly on a smaller one. Some tapes need more than a plain assemble:
- The one-load RAM tapes, 16k (`build_one16`) and 32k+ (`build_one32`):
  tape 1's stage 1 (ONE16) with stage 2 and, for 32k+, the system tests,
  inserted into the same image at the addresses they were built for, all
  sharing stage 1's BSS page. Stage 2 tests stage 1's RAM page by page
  (`src/common/pagetest.asm`). The addresses depend on the sizes and not
  the other way round, so a few rounds settle them.
- The 16K+ memory test (`build_bounce`): a relocation bitmap, made by
  assembling at $0800 and at $0C00. The build then proves it, byte for
  byte, against the code assembled at both addresses the second copy can
  go to.
- The two-stage tapes: `tools/mkcas.py` writes each stage as its own file on
  the tape, with an end-of-file record after each.

### Disk files

`XEXES` in `tools/build.py` lists them: the 32k+ tape and `diag-memtest`,
built again by the same builders with `XEX=1` and wrapped by
`tools/mkxex.py`. XEX changes only the title bar and leaves out NEEDPG;
everything it changes is under `.ifdef XEX`, so the tapes build
byte-identical (check: `git status cassettes/` shows nothing after a
build). The image still runs at $0800, where DOS lives while the file
loads, so the file has three parts (`src/disk/xexwrap.asm`):
1. the guard at $2000 with INITAD: RAMTOP below the need, or MEMLO above
   $2000, shows one line and halts (red border, the low tone on and off);
   else it returns and the load goes on;
2. the image (with its checksum, as on tape) at $2000, over the guard;
3. the mover just past the image with RUNAD: interrupts off, the image
   copied down to $0800, COLDST = 1 (RESET then starts the machine from
   cold: DOS is gone), and a jump to $0806, the cassette boot's entry.

The design and its reasons: `Atari-diag-disk-scope.md`.

### The cartridge

`carts/diag-cart.car` is an AtariMax 128K (`.car` type 41: 16 banks of 8K
at $A000-$BFFF; a write to $D500+n selects bank n, $D510 switches the
cartridge off). The tests run from ROM, so they need 8K of RAM and no
loading. `build.py`'s `build_car` assembles three code banks with `ROM=1`
and `tools/mkcar.py` packs them (`src/cart/romsum.asm` has the layout):

- **Bank 0, the RAM test:** `tape1/main.asm` with `stage2.asm` in the same
  image, as the one-load 16k tape, at $A000. `boot.asm`'s ROM variant
  doesn't change its own code: low RAM page 0 by fixed addresses, pages
  1-7 through a pointer, then the bank's checksum.
- **Banks 1 and 2, the system tests:** `system/main.asm` twice, with tests
  1-3 and 4-7. Both have the menu and list all seven; a test in the other
  bank is a thunk that sets `XREQ` and switches (`OTHER`). The results
  screen is always bank 1's (it has the ROM names).
- **From bank 3:** the long memory test's boot image, 31 pages to a bank.
  `src/cart/ldmem.asm` (bank 2) copies it to $0800 from a loop in low RAM,
  switches the cartridge off and starts it, as the old cartridge did.

BSS is one page of RAM at $0800 shared by all the banks, so results travel
with a bank switch. Every bank ends with the same 32 bytes (mkcar's
`TAIL`): the power-on jump to bank 0's $A000, the bank's sum at $BFEE, the
switch at $BFF0 (`sta $D500,x` / `jmp $A003`: the instruction after the
write comes from the new bank, which holds the same bytes) and the
cartridge header. Each code bank starts `jmp cold` / `jmp warm`.

Code that only one format can use is left out of the others with `.ifdef
ROM`, `XEX`, `ONE16`, `ONE32` and the `WANT_*` defines.

### The shared library (lib.asm) and one-load images

`src/common/lib.asm` is the code every program shares: the reporter
(`report.asm`), the text screen (`screen.asm`, with the title-bar name from
`name.asm`), the machine line (`info.asm`) and the RAM test engine
(`ramtest.asm`). The macros and constants they define are in `defs.asm`,
which every assembly includes.

A one-load image (the 16k RAM tape, the 32k+ tape and disk file, the
cartridge's RAM bank) has the library once, in stage 1 (`SHLIB`). Its
later parts (stage 2, the system tests) are separate assemblies: build.py
writes `build/shlib.asm` from stage 1's label table, every label between
`LIBBEG` and `LIBEND` except the branch labels inside routines (`xx_yy`),
and those parts include it instead of the modules. What the parts do
differently, the reporter decides at run time: `SYSMODE` (the system tests:
a beep code only for the ROMs and the RAM) and `REDRAWV` (the screen OPTION
brings back), which each part sets as it starts. The standalone programs
(the 8k tapes, the 16k system tape, the controls tape, the memory test,
the cartridge's system banks) include `lib.asm` itself, with the same
defines as before.

### A system tape's part two (diag-8k-05-av)

The GTIA test's second page (`src/system/t_gtia2.asm`, the display modes)
doesn't fit the 8K sound and video tape, so that tape (`GPART2`) has it as
a part two: `src/system/gpart2.asm`, the next file on the tape. After page
1, part one reads it with `common/loader.asm` (as tape 1 reads its stage 2;
`SYSPART`: no RAM size check, a failure goes to `p2fail`, START tries
again, SELECT ends test 7 without it) into its own RAM at `P2AT`, which
is its `LOAD`: the boot code and the tests are done with by then, and the
test list (`tlist.asm`) is moved after the library for this tape. It
enters it at `P2AT+6`. Part two may reach `TESTEND` (past the boot's
display code, also done with); it checks that itself. It uses part one's library, test 7's
`gwave` and `gans` (kept in `common.asm`, outside the overwritten tests),
and `tend`: build.py writes their addresses to `build/part1.asm` from part
one's label table (the `PART1` list).

### The ROM test's self-check

The ROM test also checks the program it is part of (`selfchk`, item 6).
A tape or disk file with the ROM test (`SELFCRC`: the 8k ROM tape, the 16k
system tape; and the 32k+ image, from tape 1's `ONE32`) ends in the image
sum and then 4 more bytes, `CRCFIX`. `mkcas.py`'s `patch_boot` puts there
the CRC32 of the image from `CRCAT` up to them, as it is in RAM once the
boot has run (the page operands boot.asm changes as it runs, its sum loop
and low RAM test, at their final values), so at run time the CRC of
`CRCAT` to the end leaves the register at the CRC32 residue, $DEBB20E3,
whatever the program: there is no per-build constant in the code.
`CRCAT` is `LOAD` for a tape on its own, and `PAYAT` for the 32k+ image
(stage 1 below it holds the live BSS page; stage 2, the system tests and
the long test's copy above it don't change). The boot sum loop leaves out
everything from `CKSUM` on. On the cartridge `mkcar.py` stores each code
bank's CRC32 of $A000-$BEFF at $BFF6 (spare tail bytes; a code bank's code
must stay below $BF00), and the ROM test switches each bank in from a
routine in low RAM (`bk_src`) to compare.

BASCRC (`src/basic/bascrc.bas`) is the check for a BASIC cartridge, which
the programs don't read: `tools/mkbasic.py` makes it an ATASCII listing
(`disks/bascrc.lst`) and a tape for `ENTER "C:"` (`cassettes/diag-bascrc`:
the cassette handler's $FC/$FA/$FE records with 3 s gaps, as the handler
stops the motor between records when BASIC reads that way).
`src/basic/bascrc.asm` is the same check as a disk file
(`disks/diag-bascrc.xex`, MADS `opt h+`, at $2000): it prints through the
OS screen editor and returns to DOS.

### 130XE banks and the 32k+ image

Stage 2 tests a 130XE's extended banks by switching them in at
$4000-$7FFF, so the code it runs and the BSS page it uses must be below
$4000. The 32k+ image keeps its BSS page inside the image, right after
stage 1 and the library (about $1500), shared by all three parts: the page
is zeros in the image, boot.asm's checksum skips it (it is in use by then;
mkcas.py sums its zeros), and stage 2's page test covers it with the rest
of the image, $0800 up to `TSTART`, which for ONE32 is the image's end.
The system tests' data (`T3D`, 96 bytes) is in zero page, $A0-$FF.

`sim.py --xejunk` fills the extended RAM with random bytes, as real RAM is
at power-on. Without it the banks start as zeros, and the old fault read
zeros and got through.

`tools/gen_kbmap.py` regenerates `src/system/kbmap.asm`, the keyboard map.

## Source layout

| Path | What |
|---|---|
| `src/common/` | shared code: boot (alive, checksum, low RAM test, size probe), display checks, the beep and flash reporter, the text screen, the RAM tests, XL/XE RAM, the stage loader |
| `src/tape1/` | the RAM tape: stage 1, and stage 2 (relocated test, RAM under the OS, 130XE banks) |
| `src/tape2/` | the memory test (one source, two builds: `diag-8k-memtest` with OWNTEST and NOXL, `diag-memtest` with BOUNCE) |
| `src/disk/` | the disk files' guard and mover (`xexwrap.asm`) |
| `src/cart/` | the cartridge's bank layout and checksum (`romsum.asm`) and the long memory test's loader (`ldmem.asm`) |
| `src/system/` | the system tests: `main.asm` builds a tape from the tests that `WANT_*` defines pick; one file per test (`t_rom`, `t_kb`, `t_con`, `t_joy`, `t_pad`, `t_pok`, `t_gtia`); `common.asm` has the test flow and the menu |
| `tools/` | build, CAS writer, simulator, keyboard map, documentation pictures |
| `cassettes/` | the release tapes |
| `disks/` | the release disk files |
| `carts/` | the release cartridge |
| `Atari-diag-cassette-scope.md` | the design: constraints, the feedback code, memory use, the ROM table, open items |
| `Atari-diag-disk-scope.md` | the disk port's design |

## The simulator

`tools/sim.py` runs a tape on a cycle-timed 6502 (py65), with 114 cycles a
scan line and a floating bus. It models:
- the cassette boot, and later stages read through a stand-in for the OS's
  SIOV
- a `.xex` loaded as DOS loads it: segment by segment, INITAD after a
  segment that sets it, RUNAD at the end; `--memlo` sets MEMLO (default
  $1CFC, DOS 2.5)
- a `.car` (AtariMax 128K): the OS's cold start runs it, RAMTOP stops at
  $A000, and `--pick START:1` (or `SELECT:1`) presses that key at the menu;
  the end report lists the bank switches; `--con START:52` presses a console
  key at any time (e.g. START at the 32k+ summary)
- RAMTOP ($6A) as the OS sizes it at power-on: `--ram`, capped at $A000
  with `--basic`
- RAM faults: stuck bits (`--stuck`), flaky bits (`--flaky`), mirrored banks
  (`--mirror`), and 130XE bank aliasing
- XL/XE banking, the RAM under the OS, the 130XE banks, the self-test ROM
- the VBI, the keyboard, console keys, joysticks and paddles, and POKEY's
  interrupt latches
- real OS and BASIC ROMs (`--osrom`, `--basic`), or made-up ROM bytes
  without them. `--forge` gives the made-up 400/800 OS chips chosen CRC32s,
  to test the ROM names.

It doesn't model ANTIC running a display list from memory that changes
under it: the screen picture always comes from the display list the program
set up. So a fault where ANTIC goes astray (as the 32k+ ROM test once did,
with the self-test ROM switched in over its screen) only shows on the
MiSTer or real hardware.

It prints the screen as text, decodes the beep code, and can save the screen
as a picture. `--auto` answers the prompts as a person would; `--menuwalk`
runs the menu's tests one by one.

```
python tools/sim.py build/diag-8k-03-input.cas --auto --until 90
python tools/sim.py build/diag-8k-01-ram.cas --stuck 2:5:1 --until 200
python tools/sim.py build/diag-32k-xl-xe.cas --xl --auto --until 900
python tools/sim.py disks/diag-32k-xl-xe.xex --ram 0x4000 --until 4 --snap 3.5   # the guard
```

A run takes minutes: py65 is pure Python. `tools/docshots.py` runs its
scenarios in parallel, one process each.

## Documentation pictures

`python tools/docshots.py` runs the simulator on the release tapes and saves
the screens in `docs/img/`. It needs real ROMs (`--sysroms`) for the font and
the ROM names, and the MiSTer core's palette file (`--palette`, `ntsc.act`),
so the colors are the core's. Neither is in this repository.

Each scenario in `RUNS` takes a picture a set time after some text first
shows on screen. A trigger that starts with `^` must be at the start of a
screen row: the RAM tapes' page test shows the program's own pages,
strings and all, in the top rows, which would trip a plain match. `ANNOT`
holds the numbered callouts; `--annotate` redraws them without running the
simulator. The raw screens go to `docs/img/raw/` (not in git).

## Attributions

- **ROM identification:** the CRC32 table combines these sources. The
  design doc (section 10a) records how they cross-check.
  - the [atari800 emulator](https://github.com/atari800/atari800)'s
    `src/sysrom.c`, for whole images
  - [MAME](https://github.com/mamedev/mame)'s `src/mame/atari/atari400.cpp`,
    per chip
  - Freddy Offenga's *Atari 8-bit Operating Systems* (OSROMS.TXT v3.3), for
    dates, systems and part numbers
- **Hardware facts** (memory map, banking, registers) come from general
  Atari knowledge, not yet checked line by line against a book. Checking
  them against *Mapping the Atari* is an open item.
- **AspeQt** (Fatih Aygün and contributors) for cassette playback over
  SIO2PC.
- **MADS** by Tomasz Biela (Tebe); **py65** by Mike Naberezny.
- The tapes contain no Atari ROM code. The simulator and the documentation
  pictures used the author's own ROM files, which are not distributed here.
