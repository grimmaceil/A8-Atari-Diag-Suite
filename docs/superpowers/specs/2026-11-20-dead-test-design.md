# The dead test: a diag-mode start that tells all it can, with no RAM

Design, 2026-11-20, revised the same day with Mike's clarifications. For
v0.15 (built locally; pushed only on Mike's word).

## Intent

Mike's goal: **find every way possible to get as much information as
possible about what works and what doesn't, and convey it to the user as
clearly as possible**, starting from a machine that may have no working
RAM at all.

The cartridge starts in **diagnostic mode** (the header's diag flag: the
OS jumps to the cartridge before it touches RAM). A **dead test** runs
first, using no RAM, no zero page, no stack and no OS ROM routine or data
(its own font), and tests everything it can that way. Then, all in one
go, it rolls on into the existing suite:

```
power on
  -> DEAD TEST: RAM, ROM chips, ANTIC/GTIA, POKEY, PIA, keys  (no RAM)
  -> DEAD TEST -- PASS    (or the faults, shown, beeped and spoken)
  -> the suite's RAM test -> its ROM test -> the menu      (as today)
```

Mike will verify it on his real 800 by pulling RAM boards and OS chips.

Why: the cartridge is the suite's "best test" because it runs from ROM,
but today it still starts after the OS has set the machine up, which
needs working RAM (zero page, stack, pages 2-3) and every OS chip. A
machine with a dead first RAM board or a dead OS chip never reaches our
code. The dead test closes that gap, and on a healthy machine it costs a
few seconds before the suite.

## Where it runs

| Cartridge | What it carries |
|---|---|
| **8 Mbit MaxFlash** (1 MB, 128 banks) | everything below: the full dead test, its screens across banks, spoken results, then the suite |
| **AtariMax 128K** (16 banks, 5 used by the suite) | the dead test in its 11 free banks: as much of the full one as fits (the plan sizes it; speech is the first thing to go) |
| **Standalone 8K** (a plain 8K cartridge or EPROM, `.car` type 1 + raw `.rom`) | the core dead test in one bank: RAM, ROM sums, bit boxes, beeps; no suite to hand over to, so it stays on its result |
| **A8PicoCart** | a separate, later project (see the end): our own firmware build from its source |

Mike: "we can increase the cart size too": the 8 Mbit version is the full
one; nothing in the suite has to shrink for it.

## The flow, in detail

### 1. Start (no RAM)

The OS jumps to the cartridge (see Facts). The dead test turns interrupts
off (SEI, NMIEN 0), sets every chip register itself (GTIA, POKEY, ANTIC,
PIA), and shows its first screen from ROM: display list, text and font
all in the cartridge. From here on nothing depends on the OS but its
reset path.

### 2. RAM, with no RAM (stage B)

Every page from $0000 to $9FFF, using only the CPU's registers and the
non-RAM storage listed in Facts. Results kept per bank (bank 1
$0000-$3FFF, bank 2 $4000-$7FFF, bank 3 $8000-$9FFF, as the suite numbers
them), and separately for **zero page** and **the stack page**, since
those two decide what else can run:

- each bank's bad data bits (all of them, not just the first fault);
- **no RAM** (nothing reads back) told apart from **bad**: no RAM in bank
  1 is a fault; in bank 2 or 3 it is neutral (a 16K or 32K machine);
- address faults: each page carries a value tied to its page number, so
  pages that alias each other are caught; the byte's own address bits
  catch faults inside a page.

On an XL/XE the 64K is soldered in and each data bit is one chip for all
of it: a bad bit names the chip outright (see the bit-to-chip tables,
decided item 2). The RAM under the OS and the 130XE banks are the suite's
(it runs right after); the dead test covers them only if the plan finds
room and storage for it (PORTB is then in use, so the DDRB trick below
needs care).

### 3. Using what passed (stage A)

The 6502 needs zero page only for pointer addressing ((zp),Y) and the
stack only for JSR/RTS and interrupts. **Neither is needed**: code that
names each page it reads (unrolled, as stage B is) and moves by JMP needs
no pointer and no stack, and any byte of proven-good RAM, **anywhere**,
can hold state through absolute addressing. So stage A takes the first
good page stage B found, wherever it is (zero page, or a page in bank 2
if bank 1 is dead), and uses it for:

- the state of the ROM CRCs (step 4);
- a **RAM text screen** (with any good 1K), so the results can show
  numbers: addresses, CRCs, counts;
- the dead test's own bookkeeping, so the later tests can be richer.

Zero page and the stack are used only once proven, and only where they
make something possible that otherwise isn't (nothing in this design
needs them).

### 4. The OS ROM chips

- **A CRC with no RAM at all:** the RAM results already fill the non-RAM
  storage (the PIA's direction registers and the stack pointer), so each
  OS chip gets a CRC-8, one register of state, with its table in the
  cartridge ROM, compared with a table of the known chips' CRC-8s
  (computed once from Mike's ROM dumps and committed as numbers, never
  the ROMs; revised in planning from the CRC-16 first written here).
- **With one good RAM page** (stage A): the full CRC32 of each chip, as
  test 1 shows it, named from the known-ROM table.
- 400/800: the $D800, $E000 and $F000 chips each; XL/XE: the 16K image
  (and its two 8K halves). A chip that reads as floating bus is **not
  there** (pulled), not just bad.

### 5. The other chips, dead-test style

What each can tell without RAM, using its own registers and the screen,
the same way the suite's tests do with RAM:

- **ANTIC:** VCOUNT runs and wraps (NTSC or PAL); WSYNC holds the CPU to
  the line; NMIST shows the VBI (polled, no interrupt); the display list
  runs (the screen itself, and the colour bars).
- **GTIA:** PAL/NTSC flag; the colour and luminance bars; player/missile
  collisions (players drawn by the CPU over the playfield, the collision
  registers read back: GTIA's logic checked with no RAM); TRIG0-3;
  CONSOL (START, SELECT, OPTION, and the console speaker).
- **POKEY:** RANDOM changes; the timers count (IRQST polled, no
  interrupt); SKSTAT; the keyboard (KBCODE, a key shown as it is
  pressed); the four voices (tones, the user listens); the pot lines
  (paddles: POT0-7 after a scan).
- **PIA:** the direction and data registers read back what was written
  (which also proves the storage trick); the joystick ports read.

Interactive parts (keys, joystick) wait for the user only after the
automatic part has shown its result, and are skipped by going on.

These checks keep their results in RAM, so they need one good page
(anywhere, stage A). With no good RAM at all there is nowhere to keep
them: the display, its colours and the sound are then the check of
ANTIC, GTIA and POKEY (if the result can be seen and heard, they work),
and the screen says the rest needs RAM.

### 6. The result: "DEAD TEST -- PASS", or the faults

- **Everything good** (or neutral): `DEAD TEST -- PASS`, the pass jingle,
  and it goes on by itself into the suite (the dead test keeps its own
  bank in, with an ordinary header, and starts the OS cold: the suite
  then runs exactly as today: its RAM test, its ROM test, the menu).
- **A fault:** the result stays, flashing and beeping (and speaking) its
  code, forever (no timeouts, as everywhere in the suite). **START** goes
  on to the suite anyway (it needs only 8K; with bank 1 bad it likely
  won't get far). SELECT replays the codes, OPTION flashes, as the suite's
  keys do (and the joystick stands in for them, as everywhere).

### 7. Into the suite

The suite's own RAM test (the "short RAM" test) then tests what the dead
test can't (the RAM under the cartridge and the OS, the 130XE banks,
march patterns), then the ROM test, then the menu: unchanged. The OS's
cold start clears RAM, so the dead test's results don't carry over; its
PASS screen is shown before the hand-over.

## How it tells the user

Every channel the machine has, so a fault gets through even when one
channel is broken:

1. **Text from ROM** (no RAM): every message the dead test can give is a
   ready-made 40-character line in the cartridge. ANTIC reads the screen
   and the font straight from the cartridge.
2. **Text chosen row by row:** each row has its variants (OK, BAD, NO
   RAM, ...) as ready-made lines, and the CPU picks one per row by
   rewriting ANTIC's display-list pointer between rows (timed by
   WSYNC/VCOUNT): every combination of results, from one bank, with no
   RAM, on the plain 8K cartridge too. (Revised in planning: switching
   the cartridge bank between rows, as first written here, does the same
   with more room; it stays in reserve for when one bank's lines run
   out.)
3. **Text from RAM**, once stage A has a good 1K: a normal text screen
   with numbers (addresses, CRCs), still in the dead test's own font.
4. **Bit boxes:** eight boxes for D7-D0 per bank, drawn by the CPU
   writing the player graphics registers directly on the right lines (no
   P/M DMA, no RAM); row colours (green good, red bad, neutral no RAM)
   set the same way.
5. **Colour of the whole screen and border**, as the suite: green good,
   red fault, yellow partial, white for a cartridge-related note.
6. **Beep codes**, as the suite: long beeps for the bank (or the chip
   number), short beeps for the bit (or the item); the fail tone first,
   the jingle on a pass.
7. **Spoken results** (8 Mbit): the dead test's pass and its errors,
   spoken: words played from the cartridge through POKEY with no RAM
   ("bank two, bit five, bad"; "ROM E-zero-zero-zero bad"; "dead test
   pass"), as the cartridge already plays its sampled "hello". For a
   machine whose screen or monitor is the trouble. Later, perhaps, the
   rest of the cartridge's results spoken too (not in 0.15).
8. **Chip names** where the bit-to-chip tables are known (decided item
   2): "BANK 1 BIT 3: CHIP Z5" instead of only "BANK 1 BIT 3".

### The screen (sketch)

```
 DEAD TEST                         V0.15
 ZERO PAGE  OK      STACK  OK
 BANK 1  $0000-$3FFF   OK
 BANK 2  $4000-$7FFF   BAD   D7 D6 D5 D4 D3 D2 D1 D0
                             .  .  .  ## .  .  .  .
 BANK 3  $8000-$9FFF   NO RAM
 OS ROM  $D800 OK  $E000 OK  $F000 OK  REV B
 ANTIC OK  GTIA OK  POKEY OK  PIA OK
 DEAD TEST -- FAULT: BANK 2 BIT 4
 START=GO ON  SELECT=TONES  OPTION=FLASH
```

Layout is the builder's; words and colours are the suite's.

## Facts it rests on (checked 2026-11-20)

- **OS rev B** ($F125 reset): `SEI, LDA #0, STA $08, CLD, LDX #$FF, TXS,
  JSR $F23F`; $F23F: `LDA $BFFC / BNE` (a cartridge?), `INC $BFFC / LDA
  $BFFC / BNE` (ROM, not RAM), `LDA $BFFD / BPL / JMP ($BFFE)`. Before
  the jump: one zero-page write and the JSR's two stack bytes, never read
  back; no chip register written yet (the clear at $F277 comes after).
  The RESET key: NMI $E791 -> $E474 -> $F11B (reads COLDST, $0244) ->
  $F12A -> the same JSR: RESET lands on the dead test too.
- **XL/XE OS** ($C2AA reset): a delay loop, a read of $033D-$033F (the
  warm-start magic), `JSR $C471`: TRIG3 bit 0, $BFFC = 0, $BFFD bit 7 ->
  `JMP ($BFFE)`. Every path through the magic check reaches $C471.
- **All seven OS ROMs** on the share (400/800 rev A and B, 1200XL, 600XL,
  800XL/130XE rev 2, 800XE rev 3, XEGS rev 4) have the diag jump. Rev
  A's reset vector is $E477, in the $E000 chip; rev B's is in $F000.
- **What must work for the dead test to start:** the CPU, the bus, the
  cartridge slot, and the OS chip holding the reset path (rev B: $F000;
  rev A: $E000 and $F000; XL/XE: the one OS chip). Nothing else: no RAM,
  no other OS chip. The 6502 reads its reset vector from $FFFC, in the
  OS ROM, and the diag jump is OS code, so a dead test can't start
  without that chip (Mike's notes, item 6, can only mean the others).
- ANTIC fetches display lists, text and fonts from cartridge ROM like any
  memory; mode 2's font base is 1K-aligned (chars 0-63 are all the dead
  test needs: 512 bytes; the other half can hold code or data). The font
  must sit at the same address in every bank that is switched in while
  the screen is drawn, as must the code that is running.
- **Storage that isn't RAM:** A, X, Y; the stack pointer S (TXS/TSX, as
  long as nothing pushes); the V and D flags; and the PIA's two data
  direction registers, readable and writable at $D300/$D301 with
  PACTL/PBCTL bit 2 = 0. With the output registers set to $FF first, a
  DDR's value changes nothing outside (an output driving 1 = an input
  pulled up): on the XL/XE PORTB stays $FF (OS in, BASIC and self-test
  out, 130XE main RAM). That's 24 bits besides the CPU registers.
- Without RAM, the 6502 can only address a page through an instruction
  that names it (absolute, absolute,X or absolute,Y): every page tested
  needs its own instructions. One X loop over a page's 256 bytes,
  unrolled across all 160 pages, costs ~5 bytes a page to write and ~13
  to check and collect: about 3K for $0000-$9FFF.
- POKEY plays samples with no RAM: a voice in volume-only mode (AUDC bit
  4) outputs its 4-bit volume; the cartridge's `hello` player does this
  at one sample per scan line with the screen off.
- The A8PicoCart's own menu runs on the Atari first and needs working
  RAM: it can carry the suite (`diag-cart.car`, type 41, is on its list)
  but not start a dead test, as it stands.

## Goals

- Starts, shows its screen, beeps and speaks with **no RAM installed**
  and only the OS chip that holds the reset path.
- Stage B uses no RAM, zero page, stack, or OS ROM routine or data (the
  OS font included); stage A uses only RAM stage B proved, anywhere.
- Per bank: bad bits, no RAM vs bad, address faults; zero page and stack
  on their own lines.
- Every OS chip checked (CRC-16 with no RAM, CRC32 with a good page),
  named, and "not there" told from "bad".
- ANTIC, GTIA, POKEY, PIA and the keys checked dead-test style.
- Every result on every channel: text, colour, boxes, beeps, speech.
- On a pass, one go into the suite with no change to the suite.

## Non-goals

- Replacing the suite's RAM test: the dead test gets a sick machine
  diagnosed; the suite's march tests, the RAM under the OS and the
  cartridge, the 130XE banks and the long test stay where they are.
- Changing the suite's flow after the hand-over (its ROM test still waits
  for a key, as now).
- Starting without the OS chip that holds the reset path (impossible).
- OS ROM images in the cartridge (copyrighted): only checksums.

## Anti-goals

- Reading RAM that hasn't just been proven.
- A missing board above bank 1 shown as a red fault (a 16K or 32K
  machine is fine): neutral, as the suite's friendly signals are.
- Anything that changes the suite's results or screens on a machine with
  good RAM, beyond the dead test's few seconds first.
- A message that only one channel carries.

## Approaches considered

- **A. Prove zero page and stack, then use them.** Small stage 1 with
  registers only; normal 6502 code after.
- **B. No RAM at any point.** Registers (and the PIA DDRs) only;
  unrolled per-page code.
- **C. Fold it into the cartridge's existing RAM test (bank 0).** That
  code expects the OS's set-up. Ruled out.

**Mike's pick: B and A together**, sharpened by his clarifications: the
whole RAM test is B; A then uses **any** RAM page B proved (not only zero
page and stack), and needs neither zero page nor the stack, since
unrolled code and JMPs do without them.

For conveying results, three layers, all used: ROM text lines (always),
rows chosen from any bank (the 1 MB room), and a RAM screen once a good
page exists; plus colours, boxes, beeps and speech on top.

## How it fits the cartridge (decided)

- **The dead test's banks** sit after the suite's (bank 5 on, today); the
  suite's bank numbers don't move. Each dead-test bank has the same code,
  font and display list at the same addresses, and its own text lines or
  sound.
- **Every other bank's tail** gets the diag header: $BFFD = $80, $BFFE ->
  a stub in the tail that only uses registers (`ldx #DEADBK / sta
  $D500,x / jmp` the dead test). Whichever bank the cartridge powers up in
  (0, or 127 on an older 8 Mbit), the OS's diag check finds the flag and
  the stub goes to the dead test.
- **The dead test's banks** have today's header ($BFFD = $04, run address
  -> the tail's jump to bank 0's cold start). To hand over it keeps one of
  them in, clears $033D-$033F (the XL/XE OS takes them for its warm-start
  magic, and the RAM test just filled them with patterns), and jumps
  through the reset vector: the OS's cold start sees an ordinary
  cartridge and the suite starts as it does now.
- **RESET in the suite** goes back through the dead test (every suite bank
  carries the flag): the same as a power-on, a few seconds longer. The
  long test's loader switches the cartridge off, as today.
- **The RESET key on a machine with bad RAM:** the OS reaches the diag
  jump without reading RAM, but a VBI or DLI left on by the program that
  was running could fire in the few cycles before the dead test turns
  NMIs off (and during the XL OS's start-up delay), and the OS's NMI code
  uses RAM vectors. Power-on is the clean start (NMIEN is 0); the guide
  says so.
- The ROM test's self-check (test 1) covers the dead-test banks too, so
  their code and data stay in $A000-$BEFF like the other code banks (the
  CRC32 at $BFF6 covers that range).
- **The standalone build** has no bank-switch writes at all ($D5xx): its
  header is $BFFD = $80 with $BFFE pointing straight at the dead test.
- **The files:** `carts/diag-cart-8mbit-v0.15.bin` and
  `carts/diag-cart-v0.15.car` with the dead test in front;
  `carts/diag-deadtest-v0.15.car` (type 1, standard 8K) and
  `carts/diag-deadtest-v0.15.rom` (raw 8K for an EPROM). One source, a
  define per output, as the 8 Mbit build already does.
- **Version 0.15**, built locally and deployed to `_diag` for Mike's
  hardware test; pushed only on his word.

## Constraints

- Stage B: no instruction that reads or writes RAM, the stack (no JSR,
  RTS, PHA, PLA, PHP, PLP, interrupts) or OS ROM; control flow by JMP and
  branches only. Stage A: RAM only where stage B proved it.
- Each dead-test bank: code, the 1K-aligned font, display list(s), its
  own lines or samples, the 32-byte tail, within $A000-$BEFF for the
  code-bank CRC.
- Results wait forever on a fault (no timeouts); START goes on.
- The suite's colours, words, keys and beep scheme; a missing bank is
  neutral.
- Docs kept current: a dead test section in the user guide (with how to
  read a pulled-board or pulled-chip result on an 800), README, CHANGELOG,
  DEVELOPMENT, the scope doc.

## Left to the builder (the plan)

- The register allocation for stage B (which bank's bits go in DDRA, DDRB
  or S; the pattern phase), and the patterns: at least the byte's own
  address bits (in-page), their complement, and a per-page value (each
  page gets the base XOR its page number), so every bit is seen as 0 and
  as 1.
- How "no RAM" is told from "bad" (e.g. every bit wrong across the whole
  bank) on a 400/800 whose idle bus can read back what was last written;
  how a pulled OS chip is told from a bad one.
- The display: display lists, the row-by-row bank kernel, the player
  boxes; NTSC and PAL; what the 128K and the standalone 8K drop.
- The CRC-16 polynomial and tables, and the table of known chips'
  CRC-16s: computed once from the ROM images Mike has (decided item 3)
  and committed as numbers, so the build never needs a ROM file.
- The words: the synthesizer's settings (speed, pitch), the packing, and
  how many banks the speech takes on the 8 Mbit.
- The order of the chip checks, and which are automatic and which wait
  for the user.
- The simulator: start at ($BFFE) with no OS set-up; no RAM at all, a
  missing bank, the bus noise of an empty slot, a pulled OS chip; PIA
  DDRA as well as DDRB; checks in the style of `carttest.py`. The
  row-by-row bank switching and the OS's cold start after the hand-over
  likely can't be seen in the simulator: check the bank writes' timing
  and that the dead test jumps through $FFFC with its own bank in, and
  leave the rest to the MiSTer and the hardware.
- The suite's checks still pass (`carttest.py`, the cartridge's runs in
  `disktest.py`).

## Decided with Mike (2026-11-20)

1. **Spoken words: yes**, in the dead test, for its pass and its errors
   (Mike: "then maybe later in the cart replace the rest of the
   results"). The word list is short: zero to nine, A to F, bank, bit,
   bad, OK, pass, fault, ROM, RAM, chip, dead test, no RAM, not there.
   The voice is my call: a speech synthesizer (espeak-ng, whose output is
   free to use; one clear, even voice for every word), each word made
   once, packed as the "hello" is (4-bit, a sample per scan line) and
   committed, so the build needs no synthesizer. The build takes WAV
   files, so a word can be swapped for a recording of Mike's later.
2. **Bit-to-chip tables:** I work them out from the boards' schematics in
   the 400/800 and 800XL service manuals (archive.org); Mike checks a
   name against his boards when a fault shows one. Only a table that is
   confirmed (by his boards, or by two sources that agree) goes in; until
   then the result names the bank and the bit, as the suite does.
3. **The CRC-16 of each known OS chip:** yes, computed once from the ROM
   images in Mike's `_sysroms` (they match the published CRC32s) and
   committed as numbers only, never the ROMs; a chip with no image gets
   its CRC32 only (stage A) until one turns up.

## A later project: the A8PicoCart

Mike: with the A8PicoCart "we would do the same thing and write directly
to the device and pull the project source and fix the 400/800
compatibility timing issue". That is firmware for the cartridge's own
microcontroller (from its open-source project), so that it serves our
image at power-on with no menu (and so can start the dead test) and works
on a 400/800. It is its own project with its own design, after this one.

## Mike's hardware test

On the real 800 with the 8 Mbit MaxFlash: all boards in (pass, then the
suite in one go); each RAM board pulled in turn, and none; a bit fault if
he has a board with one; the OS $D800 and $E000 chips pulled (rev B); a
monitor unplugged (beeps and speech alone); the RESET key after the
hand-over.
