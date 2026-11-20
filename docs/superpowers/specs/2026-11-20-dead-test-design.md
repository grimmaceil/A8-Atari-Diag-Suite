# The dead test: a diag-mode cartridge piece that needs no RAM

Design, 2026-11-20. For v0.15 (built locally; pushed only on Mike's word).

## Intent

Mike wants the cartridge to start in **diagnostic mode** (the cartridge
header's diag flag) and run a **dead test** before anything else: a test
that works with no working RAM at all, with its own font, and that uses no
RAM, no zero page, no stack and no OS ROM routines until it has proven the
memory it would use. He will verify it on his real 800 by pulling the RAM
boards (and OS chips) one by one.

Why: the cartridge is the suite's "best test" because it runs from ROM, but
today it still starts after the OS has set the machine up, which needs
working RAM (zero page, stack, page 2-3 vectors) and all three OS chips. A
machine with a dead first RAM board, or a dead OS chip, never reaches our
code. The dead test closes that gap: it runs on a machine that can't run
anything else, and says what is wrong.

## What it does

1. **Power-on:** the OS jumps to the cartridge before it reads RAM or sets
   up any chip (checked in all seven OS ROMs, see Facts). The dead test
   sets every hardware register itself (interrupts off, NMIEN 0, GTIA,
   POKEY, PIA), and shows a screen whose display list, text and font are
   all in the cartridge ROM.
2. **The RAM test, with no RAM (stage B):** every page from $0000 to $9FFF
   (zero page and the stack page first in the order of results, as they
   matter most), using only the CPU's registers. Each bank's bad data bits
   are collected, not just the first fault. Banks as the suite numbers
   them: bank 1 $0000-$3FFF, bank 2 $4000-$7FFF, bank 3 $8000-$9FFF (the
   cartridge covers $A000-$BFFF; the suite tests that 8K under itself
   later). A bank where nothing reads back at all is **no RAM there**, not
   a fault (a 16K machine is normal).
3. **The OS ROM chips (stage A), only when bank 1 passed:** zero page and
   the stack are now proven, so the dead test uses them: a CRC32 of each
   OS chip (400/800: $D800, $E000, $F000; XL/XE: the 16K image), named
   from the known-ROM table where it matches, and the result screen moves
   to RAM so it can print numbers.
4. **The result:**
   - Every bank good (or absent above the first good ones) and the ROMs
     read: a short pass signal, then the dead test starts the OS cold with
     its own bank (non-diag header) in, and **the suite runs exactly as
     today**.
   - A fault: it stays on the result, flashing and beeping its code,
     forever (no timeouts, as everywhere in the suite). **START** goes on
     to the OS and the suite anyway (the suite needs only 8K: a bad bank 2
     or 3 still lets it run; with bank 1 bad it likely won't get far).
   - No RAM in bank 1 is a fault (nothing else can run); no RAM in bank 2
     or 3 is neutral.
5. **Standalone:** the same 8K is also released on its own as a plain 8K
   cartridge (for an EPROM or any flash cartridge without a menu). There it
   has no suite to hand over to: it stays on its result, pass or fail.

### The screen (sketch)

```
 DEAD TEST                         V0.15
 BANK 1  $0000-$3FFF   OK
 BANK 2  $4000-$7FFF   BAD
         D7 D6 D5 D4 D3 D2 D1 D0
         .  .  .  ## .  .  .  .
 BANK 3  $8000-$9FFF   NO RAM
 OS ROM  $D800 $E000 $F000  (stage A)
```

The text lines are fixed ROM text; which line shows where is picked by
pointing ANTIC at ROM display lists (one per outcome, or per row). The bit
boxes are players drawn by the CPU writing GRAFPn directly, no P/M DMA,
timed by VCOUNT/WSYNC; the row colour (green good, red bad, neutral no RAM)
is written per row the same way. Exact layout is the builder's; the suite's
colours and words (OK, BAD, the D7-D0 order) are kept.

### Sound

The suite's beep codes: long beeps for the bank, short beeps for the bit
(the lowest bad bit, as the suite does), fail tone first; the pass jingle
on a pass. Timed by loops and VCOUNT, no RAM.

## Goals

- Starts and shows its screen with **no RAM installed** and with only the
  OS chip that holds the reset path (rev B: the $F000 chip; rev A: also
  $E000, which holds rev A's reset vector).
- Stage B uses no RAM, zero page, stack, or OS ROM routine or data (the
  OS font included).
- Finds and names bad data bits per bank; tells "no RAM" from "bad RAM".
- Hands over to the existing suite with no change to the suite's
  behaviour on a good machine (beyond the dead test's few seconds first).
- One 8K bank; the same bytes in the AtariMax images and the standalone
  8K cartridge.

## Non-goals

- Replacing the suite's RAM test: the dead test is a quick pattern test
  to get a sick machine diagnosed; the suite's march tests, the RAM under
  the OS and the cartridge, the 130XE banks and the long test stay where
  they are.
- RAM under the OS on an XL/XE ($C000-$FFFF) in the dead test (v1).
- Starting without the OS chip that holds the reset path: impossible. The
  6502 reads its reset vector from $FFFC, in the OS ROM, and the jump to
  a diag cartridge is OS code; Mike's notes item 6 ("test with motherboard
  OS ROM disabled") can only mean the other chips.
- The A8PicoCart and other menu cartridges: their menu runs on the Atari
  first and needs working RAM, so they can carry the suite (`diag-cart.car`,
  type 41, is on the A8PicoCart's list) but can't start a dead test.

## Anti-goals

- A dead test that reads RAM it hasn't just proven (stage B) or hasn't
  proven at all (stage A).
- A missing board above bank 1 reported as a fault in red (a 16K or 32K
  machine is fine): neutral, as the suite's friendly signals are.
- Anything that changes the suite's own results or screens on a machine
  with good RAM.

## Facts it rests on (checked 2026-11-20)

- **OS rev B** ($F125 reset): `SEI, LDA #0, STA $08, CLD, LDX #$FF, TXS,
  JSR $F23F`; $F23F: `LDA $BFFC / BNE` (a cartridge?), `INC $BFFC / LDA
  $BFFC / BNE` (ROM, not RAM), `LDA $BFFD / BPL / JMP ($BFFE)`. Before the
  jump: one zero-page write and the JSR's two stack bytes, never read
  back; no chip register written yet (the register clear, $F277, comes
  after). The RESET key: NMI $E791 -> $E474 -> $F11B (reads COLDST, $0244)
  -> $F12A -> the same JSR: RESET lands on the dead test too.
- **XL/XE OS** ($C2AA reset): a delay loop, a read of $033D-$033F (the
  warm-start magic), `JSR $C471`: TRIG3 bit 0, $BFFC = 0, $BFFD bit 7 ->
  `JMP ($BFFE)`. Every path through the magic check reaches $C471.
- **All seven OS ROMs** on the share (400/800 rev A and B, 1200XL, 600XL,
  800XL/130XE rev 2, 800XE rev 3, XEGS rev 4) have the `JMP ($BFFE)` diag
  jump. Rev A's reset vector is $E477 (in the $E000 chip).
- ANTIC fetches display lists, text and fonts from cartridge ROM like any
  memory; mode 2's font base is 1K-aligned (chars 0-63 are all the dead
  test needs: 512 bytes; the other half can hold code or data).
- Storage that isn't RAM: A, X, Y; the stack pointer S (TXS/TSX, as long
  as nothing pushes); the V and D flags; and the PIA's two data direction
  registers, readable and writable at $D300/$D301 with PACTL/PBCTL bit 2
  = 0. With the output registers set to $FF first, a DDR's value changes
  nothing outside (an output driving 1 = an input pulled up): on the XL/XE
  PORTB stays $FF (OS in, BASIC and self-test out, 130XE main RAM). That's
  24 bits besides the CPU registers.
- Without RAM, the 6502 can only address a page through an instruction
  that names it (absolute or absolute,X/Y): every page tested needs its
  own instructions. One X loop over the 256 bytes of a page, unrolled
  across all 160 pages, costs ~5 bytes a page to write and ~13 to check
  and collect: about 3K for $0000-$9FFF.

## Approaches considered

- **A. Prove zero page and stack, then use them.** Small stage 1 with
  registers only; normal 6502 code after.
- **B. No RAM at any point.** Registers (and the PIA DDRs) only;
  unrolled per-page code; no CRCs, since a CRC needs memory.
- **C. Fold it into the cartridge's existing RAM test (bank 0).** That code
  expects the OS's set-up; it would need re-plumbing. Ruled out.

**Mike's pick: B and A together.** The whole RAM test is B (no RAM, ever);
only after bank 1 (zero page and stack) has passed does the dead test use
them, for the extras that need memory (A): the OS ROM CRCs and a RAM text
screen for numbers.

## How it fits the cartridge (decided)

- **Its own 8K bank** (`src/deadtest/`, assembled at $A000), after the
  suite's banks (bank 5 today: after the RAM test, the two system banks,
  the long test's image and the "hello"). The suite's bank numbers don't
  move.
- **Every other bank's tail** gets the diag header: $BFFD = $80, $BFFE ->
  a stub in the tail that only uses registers (`ldx #DEADBK / sta $D500,x
  / jmp` the dead test). Whichever bank the cartridge powers up in (0, or
  127 on an older 8 Mbit), the OS's diag check finds the flag and the stub
  goes to the dead test.
- **The dead test's own bank** has today's header ($BFFD = $04, run
  address -> the tail's jump to bank 0's cold start). To hand over it
  keeps its bank in and jumps through the reset vector: the OS's cold
  start sees an ordinary cartridge and the suite starts as it does now.
- **RESET in the suite** goes back through the dead test (every suite bank
  carries the flag): the same as a power-on, a few seconds longer. (The
  long test's loader switches the cartridge off, as today.)
- **The files:** `carts/diag-cart-v0.15.car` and
  `carts/diag-cart-8mbit-v0.15.bin` with the dead test in front;
  `carts/diag-deadtest-v0.15.car` (type 1, standard 8K) and a raw 8K
  `.rom` for an EPROM. One source, a define per output, as the 8 Mbit
  build already does.
- The ROM test's self-check (test 1) covers the dead test's bank too, so
  its code and data stay in $A000-$BEFF like the other code banks (the
  CRC32 at $BFF6 covers that range).
- **The standalone build** has no bank-switch writes at all ($D5xx): its
  header is $BFFD = $80 with $BFFE pointing straight at the dead test.
- **Before the hand-over** the dead test clears $033D-$033F: the XL/XE
  OS takes those three bytes for its warm-start magic, and the RAM test
  has just filled them with patterns.
- **Version 0.15**, built locally and deployed to `_diag` for Mike's
  hardware test; pushed only on his word.

- **The RESET key on a machine with bad RAM:** the OS reaches the diag
  jump without reading RAM, but a VBI or DLI left enabled by the program
  that was running could fire in the few cycles before the dead test
  turns NMIs off (and during the XL OS's start-up delay), and the OS's
  NMI code uses RAM vectors. Power-on is the clean start (NMIEN is 0);
  the guide says so.

## Constraints

- One 8K bank: code, the 1K-aligned font, display lists, text lines, the
  32-byte tail.
- Stage B: no instruction that reads or writes RAM, the stack (no JSR,
  RTS, PHA, PLA, PHP, PLP, interrupts) or OS ROM; control flow by JMP and
  branches only.
- Results wait forever on a fault (no timeouts); START goes on.
- The suite's colours, words and beep scheme; a missing bank is neutral.
- Docs kept current with the change: the user
  guide gets a dead test section (and how to read a pulled-board result on
  an 800), README, CHANGELOG, DEVELOPMENT, the scope doc.

## Left to the builder (the plan)

- The register allocation for stage B (which bank's bits go in DDRA, DDRB
  or S; the phase counter), and the patterns: at least the byte's own
  address bits (in-page), their complement, and a per-page value (each
  page gets the base XOR its page number, so pages that alias each other
  are caught), so every bit is seen as 0 and as 1.
- How "no RAM" is told from "bad" (e.g. every bit wrong across the whole
  bank) on a 400/800 whose idle bus can read back what was last written.
- The display: one display list per outcome or rows chosen per frame; the
  player kernel; NTSC and PAL.
- The OS ROM CRC table for stage A: the same values as test 1's
  (`t_rom.asm`), carried in the dead test's own bank (stage A can't call
  into another bank's code).
- The simulator: start at ($BFFE) with no OS set-up; no RAM at all
  (`--ram 0`), a missing bank, the bus noise of an empty slot; checks in
  the style of `carttest.py`. The OS's own cold start after the hand-over
  likely can't run in the simulator: check that the dead test jumps
  through $FFFC with its own bank in, and leave the rest to the hardware
  test.
- The suite's checks still pass (`carttest.py`, the cartridge's runs in
  `disktest.py`).

## Mike's hardware test (what he'll do)

On the real 800 with the 8 Mbit MaxFlash: all boards in (pass, then the
suite); each RAM board pulled in turn, and none; a bit fault if he has a
board with one; the OS $D800 and $E000 chips pulled (rev B); the RESET
key after the hand-over.
