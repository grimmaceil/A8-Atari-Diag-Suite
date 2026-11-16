# A8 Atari Diag Suite

Free to use, copy and share. Please credit **Michael Grimm** (and
Claude, the AI that helped write it) when you pass it on.

Diagnostics for every Atari 8-bit computer, on cassette, disk and
cartridge: the 400, 800, 1200XL,
600XL, 800XL, 65XE, 800XE, 130XE and XE Game System. Load one like
any cassette program and it tests the machine: RAM, ROMs, keyboard, console
keys, joysticks, paddles, sound and video, plus a memory test (burn-in) for faults that
come and go.

It reports by **border colour and beeps** first, so it works even when the
picture doesn't. Text appears on screen once the screen itself has been
checked.

**Why cassette:** a cassette boot needs the least of the machine: no disk
drive, no DOS, just the computer, its OS and the first few K of RAM. So it
runs on an 8K Atari 400 and on machines too sick to boot a disk. Tape is
slow (about 3K a minute), so there are three sets, by RAM size: the more
RAM, the fewer tapes. Each set works on every machine with at least that
much RAM, newer models included. With a disk drive, the 32k+ tape and the
memory test also come as **disk files** (`.xex`, in `disks/`) that load in
seconds. All of it is also on one **cartridge** (in `carts/`): plug it in,
switch on, pick a test.

Version 0.9. Every file has its version in its name
(`diag-32k-xl-xe-v0.9.xex`) and every screen shows it at the right of the
title bar (`V0.9`), so you can tell which one you are running. The names
below leave the `-v0.9` out.

![The menu](docs/img/system-01-menu.png)

## Get started

1. Pick the tapes by RAM: the biggest set the machine has the RAM for.

   | RAM | Tapes (in `cassettes/`) |
   |---|---|
   | 8K or more (every Atari) | the 8k set: `diag-8k-01-ram` to `diag-8k-06-video`, about 2 min each; long test `diag-8k-memtest` |
   | 16K or more | the 16k set: `diag-16k-01-ram`, `diag-16k-02-system`, about 3.5 min each; long test `diag-16k-memtest`; the sampled sound test `diag-16k-03-hello` |
   | 32K or more (an 800 with 32K-48K, any 64K or 128K XL/XE) | the 32k+ tape: `diag-32k-xl-xe`, one tape, about 6 min; long test `diag-16k-memtest` |
   | keyboard, joysticks, paddles only (16K or more) | `diag-controls`: no test harness needed; goes with Atari's SALT disks |
   | with a disk drive or a MiSTer: 32K or more | `disks/diag-32k-xl-xe.xex`: everything in one file; the long test: `disks/diag-16k-memtest.xex` (16K) |
   | a MiSTer, or an AtariMax 128K flash cartridge: any machine, 8K or more | `carts/diag-cart.car`: every test, run from ROM, with the menu; the long test from its line 8 (16K) |
   | a BASIC cartridge (400/800, 1200XL) | BASCRC: `disks/diag-bascrc.xex` (from DOS, 16K), or as a BASIC program: `cassettes/diag-bascrc.cas` (`ENTER "C:"`), `disks/bascrc.lst` (`ENTER "D:"`); see the user guide |

   A machine that won't get through its own set: use the 8k set. A tape
   that needs more RAM than the machine has stops at once: red border, a
   low tone on and off.

2. Take out any cartridge, then load the first tape: hold START, switch the
   machine on, start the tape and press a key when it beeps. You can
   use a MiSTer, a PC with a USB-SIO cable and AspeQt, or a real cassette.
3. Watch and listen: green is good, red plus beeps is a fault. Long beeps
   say where (RAM bank or test number), short beeps say what (data bit or
   item).

**[The user guide](docs/USER-GUIDE.md)** explains every screen, the colours
and beeps, loading from a PC, and what to do when something fails.

## Versions

- **0.9** (2026-11-15)
  - The end of a tape without a menu (the 8k tapes, `diag-16k-03-hello`,
    `diag-controls`): no more `START = AGAIN`. The last test's screen
    stays up with a line for each test on the tape and what to load next
    (`TEST COMPLETE. NEXT: DIAG-8K-03-INPUT`), and nothing needs a press.
    The last test goes straight there, without its own result pause.
    `diag-16k-01-ram`, and `diag-8k-01-ram` on an 8K machine, end the same
    way.
  - A fail now plays "impending doom" (C4, C4, F#3, the tritone) before
    its beep code, instead of the sad trombone, and every failed test plays
    it, at the test and at the end.
  - GTIA test, page 2: every display mode on one screen (ANTIC 6, 7, the
    bitmaps 8, A, B, D, F with a wave drawn in each, and GTIA's 9, 10, 11),
    a line wiggling sideways (HSCROL) and the question bobbing (VSCROL);
    item 2.
  - The ATARI word scrolls right to left; each letter rides the wave on its
    own counter, as in 0.8. The hue bands are 4 lines (from 5), and the
    word sits in the middle of the space that leaves.
  - Page 2 of test 7 (`7 VIDEO MODES`) is clearer: a label line above
    each mode, even colour bars in the bitmaps (no waves), the GTIA bands
    apart, a line that slides and one that moves up and down, and the
    question still.
  - The final result when nothing failed but not every test ran (skipped,
    or not run from the menu): steady yellow and the start-up chirp, not
    the green double charge.
  - Keys at every result: T or SELECT the tones again, F or OPTION
    full-screen flashes, any other key goes on (at the end of a tape
    without a menu: the tones). R re-tests where there is no menu to pick
    the test again from: the RAM and ROM tapes and the memory tests. In the
    user guide's first section.
  - S skips the RAM test on the 32k+ tape and the disk file too, as on the
    cartridge; X no longer skips the ROM test (the console key test keeps
    it).
  - The 8k sound and video tape is two tapes, `diag-8k-05-sound` and
    `diag-8k-06-video`, each one load (no part two), so R can run every
    test again. The 8k tapes carry only their own tests' names.
  - "hello": the cartridge's recording everywhere (15.7 kHz, seven plays);
    `diag-16k-03-hello` loads in 3.5 min. The disk file no longer carries
    the long memory test (it could never come back to the menu): that is
    `diag-16k-memtest.xex`, and the tape `diag-16k-memtest` (was
    `diag-memtest`).
  - The memory test's summary shows the passes done again; R restarts it.
  - The keyboard test ends on any console key. The Atari key shows the
    logo on every machine. `diag-8k-01-ram` shows the main RAM (48K on an
    XL/XE) until part 2 tests the rest.
  - Test 7 is named GTIA/ANTIC (its page 2 is mostly ANTIC's modes).
  - Prompts say ANY KEY where any key goes on (`ANY KEY = GO ON`,
    `ANY KEY = MENU`), so a dead START or key isn't a dead end. The
    paddle test's first step and the 8k av tape's part two retry now take
    any key too, not only START.
  - "hello" on the disk file and the hello tape: all seven plays, as on
    the cartridge (the two-voice ones too), from a recording at half the
    rate played twice as fast: a squeaky "hello".
  - Long memory test: the count is passes done (0 in the first). A key
    shows `ENDING AFTER THIS PASS`; the summary shows the time, not a pass
    count.
  - The menu's results say `MENU IN 2 S` and `ANY KEY = MENU` when one test
    was run from the menu, not `NEXT TEST`.
  - ROM test: a self-check line. The tape or disk file checks its own copy
    in RAM by CRC32, and the cartridge checks each of its program banks
    against a CRC32 stored in it (item 6). The 400/800 cartridge reading
    is gone: a BASIC cartridge is checked by BASCRC, a short BASIC program
    (`diag-bascrc` tape, `bascrc.lst`, and `diag-bascrc.xex`, the same
    check in machine code). The XL/XE's built-in BASIC is
    still checked, and one that matches no revision is now a fault.
- **0.8** (2026-11-15)
  - The 400 set is now the 8k set: `diag-8k-01-ram` to `diag-8k-05-av` and
    `diag-8k-memtest`. It runs on any Atari, tells a 400/800 from an XL/XE
    and tests every RAM bank the machine has.
  - Sounds: a pass plays the first four notes of the "charge" fanfare
    (twice for the final pass); a fail plays a sad trombone (two long
    falling notes) before its beep code.
  - The disk file loads on 32K again (0.7 needed 34K): its "hello" is now
    4 bits, a quarter of the bytes, played on the four voices and the
    speaker. The cartridge keeps its 15.7 kHz version and the two-voice
    plays.
  - `diag-16k-03-hello`: the sampled sound test on its own tape (too big
    for 8K).
  - GTIA test: the sixteen colour bands are bigger (5 lines, from 3) and
    the gray steps smaller (3 lines, from 7). The ATARI letters snake: each
    rides the wave a little behind the one before, on every version (the
    wave is a 16-byte quarter table).
- **0.7** (2026-11-14)
  - The ROM test runs by itself only at power on; the RAM test run from
    the menu comes back to the menu. The RAM summary waits for START.
  - S skips the RAM test (cartridge), X skips the ROM test (cartridge,
    disk file, 32k+ tape) and the console key test. A tap counts any time,
    from switching on.
  - "hello" plays with the screen off, at a steady rate: a sample every
    scan line on the cartridge (15.7 kHz, in a bank of its own), every
    other line on the disk. 0.5 and 0.6 played it with the screen on,
    which made the samples late and uneven. The recording is prepared
    properly now (`tools/mkhello.py`, with a preview to listen to on a PC).
  - GTIA test: on the cartridge the ATARI sprites bounce as well as scroll.
  - A tap of START right as a result appeared could be missed; fixed.
  - Smaller: the code every part shares (the beep reporter, the screen,
    the machine line, the RAM test engine) is now in the one-load images
    once instead of two or three times. The 32k+ program is 13.5K (was
    16.5K) and fits below $4000; the 16k RAM tape is 6K (was 8K); the
    cartridge's RAM bank has 2K more room. Screen rows and the GTIA rainbow
    are worked out instead of looked up, and the system tests keep their
    data in zero page.
- **0.6** (2026-11-14)
  - After the RAM test the ROM test runs by itself, then the menu. On the
    cartridge CTRL+X during the RAM test goes straight to the menu.
  - Menu: 8 is the results, 9 the long memory test. Re-running the RAM
    test (0) keeps the other tests' results.
  - The long memory test returns to the cartridge's menu (START at its
    summary).
  - The disk file `diag-32k-xl-xe.xex` now holds the long memory test too
    (menu line 9) and the sampled "hello"; it needs 34K.
  - "hello" also plays on two voices at once, for twice the levels.
  - CTRL+X skips the console key test. A tap of START is no longer missed
    now and then at a result screen.
  - The results screen explains the numbers after FAIL; the guide lists
    every test's items.
- **0.5** (2026-11-14)
  - The cartridge runs from ROM: it needs 8K of RAM, not 32K, and works on
    a machine whose RAM can't hold a program. Power on goes straight into
    the RAM test; the START/SELECT start screen is gone. Only the long
    memory test (menu line 8) copies itself to RAM. The RAM test also tests
    the 8K under the cartridge (it switches itself off for a moment), so a
    48K machine shows as 48K.
  - CTRL+S skips the first RAM test on the cartridge (a tap any time
    during it).
  - The cartridge's ROM test also checks an XL/XE's built-in BASIC (it
    switches itself off to read it), and its POKEY test plays a sampled
    "hello" on each voice and the console speaker (item 7).
  - One menu, numbered in order: 0 RAM, 1 ROMs, 2 keyboard, 3 console
    keys, 4 joysticks, 5 paddles, 6 POKEY, 7 GTIA (and 8, the long memory
    test, on the cartridge). Joysticks, paddles and POKEY changed numbers.
  - No video check screen. The RAM result is the first screen, and START
    there says the picture can be read.
  - Beep codes only for the RAM and the ROMs, in different pitches. Other
    tests show their result: a jingle for a pass, one low beep for a fail.
  - Keyboard test: the key click sounds on the console speaker and POKEY.
  - POKEY test: each voice plays a scale, then noise.
  - Keyboard test: on a 400/800 the Atari logo key shows as `/|\`, not INV.
  - GTIA test: ramps and sprites on one screen, one question.
  - ROM test: the cartridge slot is named only for BASIC A, B and C; the
    diagnostic cartridge names itself.
  - The 16K and 32K images are smaller (an unused results screen removed).
- **0.4** (2026-11-14)
  - Fixed: a real 800 could be taken for an XL/XE. The test looked at what
    `$C000` reads, where a 400/800 has nothing, and an idle bus can read
    back anything. Then the ROM test compared the OS with the XL/XE tables
    (`UNKNOWN`, with sums that changed from run to run) and only joystick
    and paddle ports 1-2 were tested. The machine is now told apart by the
    direction of the PIA's port B, which the OS sets: outputs on an XL/XE,
    inputs on a 400/800.
  - Quieter once the picture is confirmed (a key at the video check; on
    the tapes without one, the display checks passing). A fault's beep code
    plays once, then the border stays steady red and silent, and SELECT
    plays the code again. The border doesn't flash while the text is up.
    The end of a tape stays green and silent. The memory test doesn't beep
    after each pass. Without a confirmed picture, and with full-screen
    flashes (OPTION), everything is as before.
  - A key now counts between the beeps of a code, not only in the pause
    after it.
  - The menu no longer blanks the screen when the highlight moves.
  - POKEY test: a new item 7, noise. After the four voices, voice 1 plays
    as a hiss; a POKEY whose polynomial counter is dead plays the pure
    tones but not this.
  - The version is in every file name and on every title bar.
  - Fixed: the 130XE check left a wrong byte at `$4000` in the 32k+
    tape, disk file and cartridge (one wrong character in the GTIA test).
  - Fixed: the tapes without a RAM test accepted a screen block with a bit
    stuck through all of it, and showed garbled text.
  - Fixed: with no working screen block, the console key test wrote its
    text over page zero and crashed.
  - The cartridge menu: too little RAM for one program shows the message
    and comes back to the menu, so the other can still be picked.
  - The video check shows all 64 characters, normal and inverse.
  - `diag-8k-memtest` no longer shows the character ROM sum (no room in
    8K); `diag-8k-01-ram` shows it.
- **0.3** (2026-11-08)
  - Fixed: on a 130XE the 32k+ tape and `diag-32k-xl-xe.xex` crashed as
    the RAM test went from the RAM under the OS to extended bank 5. Their
    stage 2 kept its working storage at $4F00, inside the $4000-$7FFF
    window that a 130XE bank switch takes over, so switching in bank 5 lost
    it. That storage now sits in low RAM ($0600). The same mistake made
    their FOUND line say `RAM 64K` on a 130XE; it now says 128K. The other
    tapes and `diag-memtest.xex` are byte for byte the same as 0.2.
  - The cartridge, `carts/diag-cart.car` (AtariMax 128K, `.car` type 41):
    START runs the 32k+ tests (RAM, ROMs, keyboard, console keys,
    joysticks, paddles, sound, video), SELECT the long memory test. The
    title bars say CART.
- **0.2** (2026-11-08)
  - Disk files: `diag-32k-xl-xe.xex` (32K) and `diag-memtest.xex` (16K),
    for DOS 2.0S/2.5, MyDOS, the MiSTer's XEX loader, AspeQt and FujiNet.
    The same tests as their tapes; the title bar says XEX. A machine with
    too little RAM, or a DOS in the way, gets a plain message before the
    file loads.
  - The tapes are unchanged (byte for byte the same as 0.1.2).
- **0.1.2** (2026-11-08)
  - Every tape that needs more than 8K checks the RAM first. On a machine
    with too little it stops at once, with a red border and a low tone on
    and off, instead of giving a meaningless code.
  - The documents pick tapes by RAM, for every Atari 8-bit model.
  - The leftover code of the old 48k+ tape is gone (the other tapes are
    unchanged by that).
- **0.1.1** (2026-11-08)
  - The 16k RAM tape and the 32k+ tape (it replaces the 48k+ tape) are one
    load each, and test their own RAM too. The 32k+ menu has `0 RAM TEST
    AGAIN`.
  - The machine's real RAM is reported (64K on an 800XL, 128K on a 130XE),
    a plugged-in cartridge shows as `CART IN`, and XL/XE BASIC is switched
    off for the RAM test.
  - Every screen's title bar names the tape; the `FOUND:` line below it is
    what the tape detected.
  - GTIA test: the word ATARI in players and missiles, scrolling, with a
    display-list-interrupt rainbow.
  - New `diag-controls` tape: keyboard, joysticks and paddles only.
  - At the end of a tape, START runs the tests again; the ROM test waits for
    a key so you can read it; the summaries name the next tape.
  - The burn-in is renamed the memory test (`diag-memtest`,
    `diag-8k-memtest`).
  - Fixed: the keyboard test's stray lines on the INV key; a scrambled
    screen in the 32k+ tape's ROM test on the XL/XE.
- **0.1** (2026-11-07): the first release.

## For developers

[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) covers building from source, the
simulator, the source layout and the attributions. The design notes are in
[Atari-diag-cassette-scope.md](Atari-diag-cassette-scope.md).

## Authorship and status

The author has programmed 6502 machine language and assembler since
childhood. Even so, all of the code and documents here are, for now, 100%
written by AI (Claude, by Anthropic). The author directs the work, reviews
it and tests it on hardware.

Tested on a MiSTer Atari800 core and in the project's
simulator; not yet on a real 400, 800, XL or XE. Issues and pull requests
are the way to reach the author; email is not checked.
