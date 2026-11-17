# A8 Atari Diag Suite, the boot disk: scope and design

By **Michael Grimm**, written with Claude (Anthropic's AI). MIT license
(see [LICENSE](LICENSE)).

Status: design, 2026-11-16, not built yet. The disk files (`.xex`) have
their own document, [Atari-diag-disk-scope.md](Atari-diag-disk-scope.md).
This disk reverses two calls made there: it is a bootable `.atr`, and it
runs on an 8K machine.

## 1. What this is, and why

One disk image, `diag-disk-v0.9.atr`, that you boot by switching on with
it in drive 1. No DOS. It runs the whole suite the way the cartridge does,
on any Atari with a disk drive: 400, 800, XL or XE, 8K of RAM or more.

Mike, 2026-11-16: the 8k tapes showed the tests can be split into small
pieces; a disk can hold all the pieces and chain them ("a boot sequence
between programs ram > rom > menu > other, each piece as a separate file
on the same disk"), and the RAM test should be one part, as the long RAM
test already is. The cartridge is still the best way; this is the free
way for anyone with a drive, an SIO adapter or a MiSTer, and a way to
test a machine whose cartridge port is bad. Mike can test it himself on
the real 800 and 800XL over his SIO adapter, which plays disks but not
tapes.

## 2. What the user sees

1. Switch on with the disk in drive 1 (no cartridge, or one that lets the
   disk boot). Nothing to hold: on an XL/XE the program switches BASIC out
   itself.
2. The RAM test: green and a chirp, then yellow while it tests. One part:
   it tests its own RAM too (section 5). Its summary plays its code three
   times and goes on by itself, as on the cartridge.
3. The ROM test loads and runs, and waits on its result.
4. The menu, the cartridge's: `0 RAM` to `7 GTIA/ANTIC`, all in order,
   `8` the results and the final code, `9` the long RAM test. The same
   keys, joystick included.
5. Picking a test loads its piece (a few seconds on an 810); when it ends,
   the menu loads again with the result on its line.
6. No picture (the display checks fail): no menu; all the tests run in
   order, beeps and border only, as on the other formats.

While a piece loads, row 23 says `LOADING...` and the border holds steady.

## 3. Goals, non-goals, anti-goals

**Goals**
- Boots on every Atari 8-bit with a disk drive and 8K or more.
- The same tests, screens, beep codes, menu numbers and keys as the
  cartridge.
- The RAM test is one part on every machine and tests the RAM it runs in.
- Results travel from piece to piece; the results page and the final code
  cover everything that ran.
- One single-density image (90K): every drive reads it (810, 1050, XF551),
  as do the MiSTer and SIO adapters.

**Non-goals**
- No DOS on the disk, and the pieces are not DOS files (section 7).
- No enhanced or double density.
- No new tests. No change to the tapes, the cartridge or the `.xex` files
  (they stay, for loading from DOS).

**Anti-goals** (a failure even if the tests run)
- A load that fails silently or hangs: every disk error must show (border,
  tone and text) and let the user try again.
- A piece that runs after loading wrong: each one checks its own sum first.
- A disk that needs 16K to show anything on an 8K machine.

## 4. The memory: what fits where

Measured from the builds, 2026-11-16.

| RAM | 8K machine | Use |
|---|---|---|
| $0000-$07FF | 2K | low RAM: the OS, the stack, the boot loader in page 7 (tested first, non-destructively: every byte put back) |
| $0800-$08FF | one page | the shared results page (BSS), as on the cartridge |
| $0900-$1BFF | **4.75K** | the piece that is running |
| $1C00-$1FFF | 1K | the screen (the disk's RAM pieces look for it from $1C00 up, never just above themselves as a tape does, so no later piece loads over it; on a bigger machine it may sit higher) |

So a piece that must run on 8K is at most 4.75K, the same room the 8k
tapes have ($0800-$1AFF there, with the results page after the program).
The 8k tapes today: ROM 4.5K (270 bytes free), input 4.75K (137 free),
ports 4K, sound 3.75K, video 4.5K. A disk piece doesn't do the power-on
work (the low RAM test, the display checks: about 770 bytes); the RAM
piece did that once. That pays for the disk loader each piece carries
(about 150 bytes) and its entry from the other pieces.

The menu is about 770 bytes with its strings. It doesn't fit beside
every test, so it is a piece of its own; the cost is a short load back to
the menu after each test (about 2.5K, two or three seconds on an 810).

## 5. The RAM test, in one part

Yes, it can be one part, the way the long test does it: every page of the
program's own RAM is copied into the screen (already tested), tested
(March C- and address-in-page), and put back, by a small copy of the
page test in low RAM (`common/pagetest.asm`). There are two RAM pieces,
and the boot loader loads the one that fits the machine (by RAMTOP):

- **RAM-16K and up** (`RAM16`): the one-load 16k RAM tape's program
  (`diag-16k-01-ram`, tape 1 with `ONE16`), already one part: the RAM
  above it, its own RAM page by page, the RAM under the XL/XE OS and the
  130XE's banks, then the summary. Built for the disk: at $0900 with the
  results page at $0800 (about $0900-$21FF).
- **RAM-8K** (`RAM8`): for machines under 16K, which are only ever a 400
  or 800, so it leaves out the XL/XE parts. Tape 1's stage 1 with the page
  test of its own RAM in place of the tape loader: about 4.6K, in the
  4.75K.

The summary goes on to the ROM test by itself after three codes (the
cartridge's rule). Menu line 0 loads the RAM piece again with the other
tests' results kept, as the cartridge does.

## 6. The pieces

Every piece loads at $0900 and ends by $1BFF unless it says otherwise.

| Piece | What | Needs | About |
|---|---|---|---|
| boot | sectors 1-2, at $0700: picks and loads the RAM piece | 8K | 256 bytes |
| `RAM8` | RAM test, one part, 400/800 under 16K | 8K | 4.6K |
| `RAM16` | RAM test, one part, everything else | 16K | 6.25K, to $21FF |
| `ROM` | test 1, and the results page (it has the ROM names, as on the cartridge) | 8K | 4.5K |
| `MENU` | the menu | 8K | 2.5K |
| `INPUT` | tests 2 and 3, keyboard and console keys | 8K | 4.5K |
| `PORTS` | tests 4 and 5, joysticks and paddles | 8K | 3.5K |
| `SOUND` | test 6, POKEY; with 16K or more it also loads `HELLO` for item 7 | 8K | 3.5K |
| `HELLO` | the "hello" recording (7.25K of data) | 16K | 7.25K, above $2000 |
| `VIDEO` | test 7, GTIA/ANTIC | 8K | 4.5K |
| `MEM` | the long RAM test (`diag-16k-memtest`'s program) | 16K | 7K |

About 50K in all, of the disk's 90K.

## 7. The disk

- `.atr`, single density: 720 sectors of 128 bytes, 16-byte ATR header.
- Sectors 1-2: the boot (OS boot header: flags 0, two sectors, load
  $0700, init: an `rts`). The OS loads them and calls $0706.
- From sector 3 on: each piece in a run of whole sectors, one after
  another. A table of each piece's first sector and sector count is
  written by the build into every piece and the boot (its size is fixed,
  so the build settles in two rounds, as `build_one32` does now).
- No DOS directory: the disk is for booting. A DOS would see an empty disk
  and could write over it. (A directory listing the pieces as files could
  be added later if wanted.)

## 8. Loading a piece

**The boot** (page 7, loaded by the OS with everything running): reads
RAMTOP, loads `RAM8` or `RAM16` to $0900 with the OS's SIO (`SIOV`, unit
1, command `R`), and jumps to its power-on entry. The RAM test's low RAM
test runs over page 7 too and puts it back.

**The chain loader** (`common/dload.asm`, in every piece): page 7 is not
safe for long (test 7's sprites and the long test's log use pages 4-7),
so each piece copies its loader to page 7 when it needs it and jumps
there, as the tape's stage-2 loader does: it turns the VBI and IRQ back
on with the OS shadow registers set so the screen stays as it is, reads
the piece's sectors to $0900 on, turns interrupts off and jumps to the
piece's entry with `XREQ` saying why it was loaded.

**A disk error** (the OS's SIO gives up after its own retries): red
border, the low end tone on and off, and on row 23 `DISK ERROR $nn. A KEY
TRIES AGAIN`; any key, START or fire reads the piece again. The message
and the wait are in the loader itself (the piece that called it is being
overwritten).

**The sum:** every piece ends in its 16-bit sum (as a tape image does).
Its entry checks it before anything else; a wrong sum is the
image-checksum fail every format has (`LOADERR`: long tone 1, then the
end tone).

## 9. What travels between pieces

- The results page at $0800 (BSS), as the cartridge's: `BADMASK`, `MRUN`,
  the menu's line and mode, `STASH`/`KEEP`, `XREQ`, the machine, the RAM
  size, the screen's page, `DISPOK`/`VIDEOOK`, the ROM test's sums.
- Zero page $A0-$FF (the tests' data: the ROM test's results for the
  results page). The OS's SIO doesn't touch it.
- `XREQ`, as on the cartridge: 0 the menu, 1-7 that test, 8 the long
  test, 9 the results; and one more, the power-on hand-over from the RAM
  piece (its RAM faults become test 0's items; then the ROM test, then
  the menu, as `CHAIN` does on the 32k+ image).

The system pieces are `system/main.asm` built with a `DISK` define, the
way the cartridge's banks are built with `ROM`: a warm entry, `XREQ`, a
table of which piece holds each test (where the cartridge has `OTHER`),
and the loader where the cartridge has `XBANK`.

## 10. The long test and "hello"

- **Line 9, the long RAM test,** needs 16K, as on the cartridge (the line
  says `NEEDS 16K` below that). It loads over everything, results page
  included. A key at its end does what the cartridge's does: it loads the
  RAM piece's power-on entry with a "back from the long test" mark, which
  does the start-up work again (low RAM, the display checks) but not the
  RAM test, and goes to the menu, the earlier results gone.
- **Item 7 of the POKEY test** ("hello") needs 16K for its 7.25K
  recording; with less it is left out, as on the 8k sound tape.

## 11. Building and checking it

- `tools/build.py`: the pieces, then `tools/mkatr.py` (new) lays them out
  and writes the image to `disks/`; deployed to the MiSTer share like the
  other files.
- `tools/sim.py`: boots an `.atr` (the OS boot of sectors 1-2) and serves
  disk reads through its `SIOV` stand-in, so a run can go power-on, RAM,
  ROM, menu, a test and back.
- Checked in the simulator once each: 8K and 64K XL boots, a menu pick
  and back, all in order, a disk error. Mike does the rest on the MiSTer
  and the real 800 and 800XL (and test 7, which is his).

## 12. Calls made for this design (Claude's, for Mike to check)

1. Single density only.
2. The pieces are runs of sectors, not DOS files, and the disk has no
   directory.
3. The results page moves to $0800 and pieces load at $0900 (the
   cartridge's layout), so `RAM16`, which is bigger than 4.75K, can load
   again from the menu without overwriting the results.
4. The menu is its own piece: a short load after every test.
5. Two RAM pieces, picked by RAM size, each one part.
6. The results page lives in the ROM piece (it has the ROM names).
7. The long test needs 16K and clears the other results, as on the
   cartridge.
8. The `.xex` files stay as they are.
9. Title bar `DIAG-DISK`, file `disks/diag-disk-v0.9.atr`, version 0.9.
