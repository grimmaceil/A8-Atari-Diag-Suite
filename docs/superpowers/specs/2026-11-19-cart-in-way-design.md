# 0.14: CART IN WAY, and the code review fixes

Short design, approved by Mike in conversation on 2026-11-19. Built as
version 0.14, locally; pushed only after he has tested it and says push.

## Why

A cartridge switches off the 8K of RAM it sits over ($A000-$BFFF), and
nothing can switch a plain cartridge (BASIC, a game) out again: a 400/800
has no control for it, and an XL/XE only switches its own built-in BASIC.
So a 48K 800 with BASIC in passes the RAM test today as if all its RAM was
good, when 8K of it was never touched. Mike: warn, test what can be
reached, and "never pass or fail without an actual failure". The documents
already say to take every cartridge out and to check BASIC with BASCRC
(v0.13 docs, d1242dd).

Along with it, the three fixes from the v0.13 code review that Mike chose
("do 1 2 3, leave 4").

## Goals

1. **Detect** a cartridge over RAM, once, after the RAM test has sized the
   RAM itself (boot.asm's probe): the RAM stops at $A000 (RAMTOP = $A0)
   and a cartridge is there.
   - XL/XE: TRIG3 ($D013) bit 0 = 1 (the slot's RD5).
   - 400/800: $BFFC reads 0. An empty address reads whatever is left on
     the bus, so read it several times, spaced apart, with ANTIC's DMA off
     (the boot's probe runs with it off), and count a cartridge only if
     every read is 0. (DMA off alone isn't enough: ANTIC's refresh cycles
     go on.)
   - A 40K 800 with a cartridge in also counts (nothing is hidden there,
     but the program can't tell): accepted, the advice is the same.
2. **Warn** at once: **white flashes and a "typing" sound** (Mike's
   choice: short noise clicks in an uneven rhythm, like keys being
   typed), about a second, then the test goes on by itself. Unlike every
   other signal: not red (a fault), not green (a pass), not orange and
   "pew" (a stuck joystick), not yellow (testing, or partial).
3. **Test what can be reached**, as now. A real fault is reported as now:
   red and beeps.
4. **No fault found: never PASS.**
   - The RAM results: bank 3's line says `CART IN WAY` instead of `PASS`,
     and a line `CARTRIDGE IN: $A000-$BFFF NOT TESTED`.
   - The result's code: the white flashes and the typing again, instead of
     the green charge (one long flash per bank). It goes on by itself
     where it does now (AUTON) and keeps the keys (T, F, R, any other).
5. **The menu and the results page** (boot disk, 32k+ tape): line 0 says
   `CART IN WAY` (FAIL when a fault was found: a fault wins), and the
   final code is the existing "partial" one (none failed, not all ran:
   steady yellow and one chirp).
6. **Code review fixes:**
   1. `src/common/xlram.asm` (xebanks, the long test's refresh wait): `jsr
      xemain` before `jsr rwait`, so the wait's progress text lands in
      main RAM, not in extended bank 3 (a 130XE whose boot screen fell back
      to $7C00 showed false B8 errors).
   2. `src/system/t_rom.asm` (basread, 400/800): read $BFFC as in goal 1
      (DMA off, several reads, all 0), so an empty slot on a 400/800 with
      40K or less isn't taken for a cartridge (a false `BASIC UNKNOWN`,
      item 2).
   3. `src/common/xlram.asm` (osout, the long test on a 16K 600XL): the
      clock's NMI (`NMIEN = $40`) only after both probes have found RAM
      under the OS; until then it stays off (osin turns it back on on the
      way out).
7. **Version 0.14**, and the documents: the colours and sounds table (white
   and the typing), the RAM test's results, line 0, the final code, the
   README's "New in 0.14", CHANGELOG.md, DEVELOPMENT, the design docs.

## Non-goals

- The diag cartridge: it switches itself off and tests the RAM under it
  already (cart/undercart.asm).
- The boot disk's 8K RAM piece (RAM8): it only runs under 16K, where the
  RAM never reaches $A000.
- The long memory test (line 9, the memtest tapes and disks): unchanged.
  `diag-8k-memtest` has no bytes free.
- Review item 4 (the font's place while the march skips the screen block;
  the refresh wait's own loop): left as they are.

## Anti-goals

- The warning must not sound or look like a fault (see the stuck joystick:
  a signal, not an alarm).
- No PASS, anywhere, while a cartridge hides RAM.
- No byte-shaving of tested code to make room; each format carries only
  code it can run. Report the net size change of every build.

## Constraints

- Room: stage 2 must end below $3800; boot disk pieces below $1C00 (ROM
  has about 180 bytes free, MENU about 1250); the cartridge's banks have
  room (it gets the system tests' part only). The 8k RAM tape's stage 1
  must be checked first.
- No timeouts after boot except where a result already goes on by itself
  (AUTON); two keys for everything.

## Approaches

- **A flag, set once, read by every result (chosen).** Stage 1 sets a byte
  in the shared results page (BSS) when it detects the cartridge; stage
  1's results (the 8k tape), stage 2's summary and the system tests' line
  0, results page and final code read it. The "partial" ending already
  exists in the system tests.
- **Count it as a fault in bank 3** (rejected): the beep code would say
  bank 3's RAM is bad, and Mike: never fail without an actual failure.
- **Skip the RAM test with a cartridge in** (rejected by Mike): faults in
  the RAM below the cartridge would go unseen; "run what you can".

## Decided by Mike

White flashes and a typing sound; `CART IN WAY`; run what can be reached;
never pass or fail without an actual failure; review fixes 1, 2 and 3, not
4; version 0.14, local until he tests it.

## My calls (Claude's), for him to check

- The no-fault ending of the RAM results is the same white and typing as
  the warning (not the yellow "partial").
- The results line `CARTRIDGE IN: $A000-$BFFF NOT TESTED`.
- The 40K 800 with a cartridge gets the warning too.
- The 400/800 check: several spaced reads of $BFFC with DMA off, all 0.
- The menu's final code with a cartridge in is the existing "partial".

## Left to the builder

- Which BSS byte holds the flag (free in the shared results page, cleared
  at boot, and set again by `again`, which runs the detection again).
- Where the warning and its sound live (shared with the stuck joystick's
  pattern: registers only, or a tone-table entry in report.asm), and the
  typing's rhythm.
- How many reads, and how far apart.
