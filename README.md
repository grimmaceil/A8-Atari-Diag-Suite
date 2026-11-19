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

All of them show the same tests, screens, colours and beeps. **Start with
the boot disk**, the most convenient; **the cartridge** needs no loading
at all, so it works when the RAM is too sick to load a program. The disk
set and the cassettes are for a machine too sick for those, and need the
least of it. All but the cartridge cost nothing, and they are the way in
when the cartridge port itself is bad.

| | File | Needs | What it is |
|---|---|---|---|
| **Boot disk** | `disks/diag-disk.atr` | any Atari (8K) with a disk drive or an SIO adapter (SIO2PC, SIO2SD, FujiNet) | the cartridge's menu from a disk you boot: no DOS; each test loads as you pick it; the long test and the "hello" with 16K |
| **Cartridge** | `carts/diag-cart.car` | any Atari (8K); an AtariMax 128K flash cartridge | every test on one menu, run from ROM: no loading, and it works when the RAM is too sick to load a program into |
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

Version 0.13. Every file has its version in its name
(`diag-disk-v0.13.atr`) and every screen shows it at the right of the
title bar (`V0.13`). The names here leave the `-v0.13` out.

## Get started

1. Pick a way: the boot disk if you have a disk drive or an SIO adapter
   (any Atari with 8K or more); the cartridge if you have a flash
   cartridge, or the RAM is too sick to load anything; otherwise the tapes
   for the machine's RAM (a machine that won't get through its own set:
   the 8k set). A tape that needs more RAM than the machine has stops at
   once: red border, a low tone on and off.
2. Take out any cartridge but BASIC, and load it: for the boot disk, put
   it in drive 1 (or mount it as D1:) and switch on; for a tape, hold
   START, switch on, start the tape and press a key when it beeps. BASIC
   can stay in: the ROM test (test 1) then checks it too, but the 8K of
   RAM under it can't be tested (a 48K 800 shows `RAM 40K`), so take it
   out to test all the RAM.
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

Tried on a real 800 and a real 800XL with the executables (`.xex`, up to
0.11) over an SIO adapter, where the joystick and paddle ports get their
real test. Every format, the boot disk included, has also run on the
author's development set-up, the MiSTer's Atari800 core, as a 400/800 and
as an XL/XE (64K, and a 128K 130XE). Not tried on a real machine yet: the
boot disk, the cartridge and the cassettes. Reports from other machines
are welcome.

## New in 0.13 (2026-11-19)

- **The disk set** (`disk-set/`): the 8k tapes as disks, one test to a
  disk, for a machine the boot disk can't get far on.
- **The long memory test on a disk of its own**
  (`disks/diag-16k-memtest.atr`).
- **The ROM test checks a BASIC cartridge** (rev A, B or C), as it does an
  XL/XE's built-in BASIC.
- **The long memory test is one march** over all the RAM (16K and up),
  the RAM under an XL/XE's OS included, in place of a march per bank and
  an address test; and **it checks the refresh:** once a pass the screen
  goes off and the RAM is left alone for 5 seconds, twice.
- `diag-16k-03-hello` is the whole sound test; the "hello" is packed to
  half its size; the paddle test has no fast scan (it can't read
  paddles); the video modes page's `VSCROL` line moves a scan line at a
  time. BASCRC stays, on its disk and its tape.

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
