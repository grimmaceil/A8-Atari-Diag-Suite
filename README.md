# A8 Atari Diag Suite

By **Michael Grimm**, written with Claude (Anthropic's AI). Free to use,
copy, change and share under the [MIT license](LICENSE); please keep the
credit when you pass it on.

Diagnostics for every Atari 8-bit computer: the 400, 800, 1200XL, 600XL,
800XL, 65XE, 800XE, 130XE and XE Game System. They test the RAM, the
ROMs, the keyboard, the console keys, the joystick and paddle ports, the
sound chip (POKEY) and the video chips (GTIA and ANTIC), and there is a
long memory test (burn-in) for faults that come and go.

It reports by **border colour and beeps** first, so it works even when the
picture doesn't. Text appears on screen once the screen itself has been
checked. Every result waits for you, for as long as you like, except the
RAM summary where the ROM test comes next: it plays its code three times
and goes on by itself, so a machine left alone runs on to the ROM test.

![The boot disk's menu](docs/img/disk-01-menu.png)

## Ways to run it

All of them show the same tests, screens, colours and beeps. **The
cartridge is the best test:** it runs from its own ROM, so it needs the
least RAM and nothing loads: plug it in and switch on. It takes an
AtariMax flash cartridge (the 128K one or the 8 Mbit MaxFlash), which you
may have already. The disks and the cassettes are the free ways, and the
way in when the cartridge port itself is bad: **the boot disk** is the
most convenient of them; the disk set has one test to a disk, for a
machine the boot disk can't get far on; the cassettes need no disk drive
at all.

| | File | Needs | What it is |
|---|---|---|---|
| **Cartridge** | `carts/diag-cart.car` (AtariMax 128K), `carts/diag-cart-1mbit.bin` (the same, raw, for the 1 Mbit MaxFlash), `carts/diag-cart-8mbit.bin` (8 Mbit MaxFlash, a raw 1 MB image) | any Atari (8K); an AtariMax flash cartridge | the best test: a dead test first that needs no RAM at all, then every test on one menu, run from its own ROM: no loading, and it works when the RAM is too sick to load a program into |
| **Dead test on its own** | `carts/diag-deadtest.car` (standard 8K), `carts/diag-deadtest.rom` (raw 8K, for an EPROM) | any Atari; any 8K cartridge | the dead test alone: the RAM tested with no RAM, its screen and beeps |
| **Boot disk** | `disks/diag-disk.atr` | any Atari (8K) with a disk drive or an SIO adapter (SIO2PC, SIO2SD, FujiNet) | the most convenient free way: the cartridge's menu from a disk you boot: no DOS; each test loads as you pick it; the long test and the "hello" with 16K |
| **Disk set** | `disk-set/diag-8k-01-ram.atr` to `diag-8k-06-video.atr`, `diag-8k-memtest.atr` | any Atari (8K) with a disk drive or an SIO adapter | the 8k tapes as disks, the same programs: one test to a disk, no menu, no DOS. With 16K or more the RAM disk tests the rest by itself, the sound disk adds the "hello", and the memtest disk runs `diag-16k-memtest` |
| **Memory test disk** | `disks/diag-16k-memtest.atr` | 16K; a disk drive or an SIO adapter | boots straight into the long memory test (`diag-16k-memtest`) |
| **BASCRC disk** | `disks/diag-bascrc.atr` | the BASIC cartridge in (or an XL/XE's built-in BASIC); a disk drive or an SIO adapter | boots to the BASIC check on its own (BASCRC), no DOS; on it for DOS too: `BASCRC.XEX`, the same check, and `BASCRC.LST`, the BASIC listing |
| **Cassette** | the 8k set: `diag-8k-01-ram` to `diag-8k-06-video` | 8K: every Atari | six small tapes, about 2 minutes each; long test `diag-8k-memtest` (400/800) |
| | the 16k set: `diag-16k-01-ram`, `diag-16k-02-system`, `diag-16k-03-hello` | 16K | about 2.5-3.5 minutes each; long test `diag-16k-memtest` |
| | `diag-32k-xl-xe` | 32K | one tape, about 5 minutes: the RAM test, then every test with the menu |
| | `diag-controls` | 16K | keyboard, joysticks and paddles only: goes with Atari's SALT disks, no test harness needed |
| | `diag-bascrc` | BASIC cartridge in | BASCRC as a BASIC listing (`ENTER "C:"`); also on the BASCRC disk as `BASCRC.LST`, for `ENTER "D:"` |

A cassette boot needs only the computer, its OS and the first few K of
RAM, so the tapes still load on a machine too sick to boot a disk. Tape is
slow (about 3K a minute), so they come in sets by RAM size: the more RAM,
the fewer tapes.

Version 0.15. Every file has its version in its name
(`diag-disk-v0.15.atr`) and every screen shows it at the right of the
title bar (`V0.15`). The names here leave the `-v0.15` out.

## Get started

1. Pick a way: the cartridge if you have a flash cartridge (the best:
   nothing to load); otherwise the boot disk if you have a disk drive or
   an SIO adapter (any Atari with 8K or more); otherwise the tapes for the
   machine's RAM (a machine that won't get through its own set: the 8k
   set). A tape that needs more RAM than the machine has stops at
   once: red border, a low tone on and off.
2. Load it: plug the cartridge in and switch on; for the boot disk, put
   it in drive 1 (or mount it as D1:) and switch on; for a tape, hold
   START, switch on, start the tape and press a key when it beeps. With a
   disk or a tape, take any cartridge out, BASIC too: the 8K of RAM under
   it can't be tested while it's in (a 48K 800 shows `RAM 40K`; the RAM
   test says `CART IN WAY`), and out, it can't be the cause of a fault. Check a BASIC cartridge on its own
   with BASCRC (its own disk or tape).
3. Watch and listen: green is good, red plus beeps is a fault. Long beeps
   say where (the RAM bank or the test), short beeps say what (the data
   bit or the item).

Keys at every result, each with a console key and a keyboard key so one
dead key never traps you: **R** re-test (where there is no menu to pick
the test from again), **T** or SELECT the tones again, **F** or OPTION
full-screen flashes, any other key (START, a joystick button) goes on.
**S** skips the RAM test on the boot disk, the cartridge and the 32k+
tape. With no keyboard, a joystick in port 1 or 2 stands in for the
console keys on every screen: fire = START, down = SELECT, up = OPTION. A
stuck joystick (a short) gets three "pew" beeps and orange flashes at
switch-on, and is then ignored: only a new press counts.

**Dirty contacts cause a lot of "faults".** An unpaid recommendation from
the author: DeoxIT contact cleaner (CAIG Laboratories) on the cartridge
port, the cartridge's own contacts, the SIO and joystick connectors, and
an 800's RAM and OS board edges. Clean, reseat, and test again before
blaming a chip.

**[The user guide](docs/USER-GUIDE.md)** explains every screen, the colours
and beeps, loading from a disk drive or a PC, and what to do when something
fails. It has a table of every test and the files that have it.

## Status

Tried on a real 800 and a real 800XL over SIO2PC with AspeQt: the boot
disk, and the executables (`.xex`) up to 0.11. The joystick and paddle
ports get their real test there. The cartridge on an 8 Mbit MaxFlash in a
real 48K 800: every test, straight from power-on; its dead test (0.15)
in that 800 (with its first RAM board out too: the fault, round after
round) and in a real 800XL. Every format has also
run on the author's development set-up, the MiSTer's Atari800 core, as a
400/800 and as an XL/XE (64K, and a 128K 130XE). Not tried yet: a
physical disk drive, the 128K AtariMax cartridge on a real machine, and
the cassettes on a real machine. Reports from other machines are
welcome.

## New in 0.15 (2026-11-20)

- **The dead test:** the cartridge starts in the OS's diagnostic mode,
  before any RAM is used, and tests the machine with no RAM at all: the
  RAM ($0000-$9FFF, zero page and the stack on their own lines), every
  OS chip (named, or `NOT THERE` when pulled), ANTIC, GTIA, POKEY and the
  PIA, the keys live. Its own font and screen, every result in colour,
  bit boxes and the beep code, and on the 8 Mbit cartridge spoken
  ("bank two bit four bad"). A pass goes straight on to the tests as
  before. Also on its own, for any 8K cartridge or an EPROM.
- **The 1 Mbit MaxFlash:** `carts/diag-cart-1mbit.bin` is the AtariMax
  128K cartridge as a raw image, which Maxflash Cartridge Studio loads
  (it takes `.bin`, not `.car`): Cartridge, Program, Maxflash 1Mbit Flash
  Cartridge. Not tried on a real one yet.

## New in 0.14 (2026-11-19)

- **A cartridge in the way:** a cartridge (BASIC or any other) switches
  off the 8K of RAM under it, so with one in, the RAM test can't test it
  all. It now says so: white flashes and a sound like typing, then it
  tests the RAM it can reach, and with no fault it never says PASS: bank
  3 and the menu's line 0 say `CART IN WAY`. Take the cartridge out to
  test all of the RAM.
- **The cartridge on the 8 Mbit MaxFlash:** `carts/diag-cart-8mbit.bin`
  is a raw 1 MB image for Maxflash Cartridge Studio's Cartridge, Program:
  the cartridge holds only the diag tests and starts them at power-on, no
  Maxflash menu. Tried in a real 800: every test, and the 8K under the
  cartridge tested (48K shown).
- **Fixes from a code review of 0.13:** test 1 on a 400/800 with 40K or
  less and an empty slot could take the empty bus for a cartridge (`BASIC
  UNKNOWN`); the long memory test could show false bank 8 errors on a
  130XE whose screen had moved to $7C00, and could crash on a 16K 600XL.

Every version, in full: [CHANGELOG.md](CHANGELOG.md).

## For developers

Everything is built from source with the MADS assembler and a few Python
tools; a cycle-timed simulator runs the programs without an Atari.
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) covers the environment,
building, the source layout, the simulator, how each format is put
together, the rules the code keeps (byte budgets, no timeouts, two keys for
everything) and the lessons learned along the way.
[Atari-diag-cassette-scope.md](docs/design/Atari-diag-cassette-scope.md)
is the design and the ROM table;
[Atari-diag-boot-disk-scope.md](docs/design/Atari-diag-boot-disk-scope.md)
the boot disk's, and
[Atari-diag-disk-scope.md](docs/design/Atari-diag-disk-scope.md) the disk
set's.

Contributions are welcome: issues and pull requests on GitHub are the way
to reach the author (email isn't checked). A report from real hardware is
as useful as code: say which machine, OS and RAM, which file, and what the
screen and the beeps said.

## Credits

- **Michael Grimm:** the author. He directs the work, reviews it and tests
  it on hardware, and wrote BASCRC, the BASIC cartridge check.
- **Claude** (Anthropic's AI): wrote the code, the tools and the
  documents, under his direction.
- **Other people's work** this builds on (details in
  [DEVELOPMENT.md](docs/DEVELOPMENT.md#attributions)):
  - [MADS](https://github.com/tebe6502/Mad-Assembler), the assembler, by
    Tomasz Biela (Tebe);
  - [py65](https://github.com/mnaberez/py65), the 6502 core in the
    simulator, by Mike Naberezny; [Pillow](https://python-pillow.org/) for
    the pictures;
  - the ROM tables: the [atari800](https://github.com/atari800/atari800)
    emulator, [MAME](https://github.com/mamedev/mame) and Freddy Offenga's
    *Atari 8-bit Operating Systems* (OSROMS.TXT);
  - the "hello" recording: `En-us-hello.ogg` by Dvortygirl, Wikimedia
    Commons, public domain;
  - the [MiSTer Atari800 core](https://github.com/MiSTer-devel/Atari800_MiSTer)
    and [AspeQt](https://sourceforge.net/projects/aspeqt/), which the
    testing relies on;
  - prior art: Atari's SALT and Super SALT diagnostic disks, and Sys-Check.

No Atari ROM code is included. The simulator and the pictures used the
author's own ROM files, which are not distributed here.

## Authorship

The author has programmed 6502 machine language and assembler since
childhood. Even so, all of the code and documents here are, for now, 100%
written by AI (Claude, by Anthropic). The author directs the work, reviews
it and tests it on hardware.
