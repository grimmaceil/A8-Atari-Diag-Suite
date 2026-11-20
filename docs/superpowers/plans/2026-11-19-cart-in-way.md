# 0.14: CART IN WAY, and the code review fixes: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** With a cartridge over RAM, the RAM test warns (white flashes, a
typing sound), tests what it can reach, and never passes without a fault
found; plus review fixes 1, 2 and 3; as version 0.14, local.

**Architecture:** Stage 1 of the RAM test (tape1/main.asm) detects the
cartridge once after the RAM is sized and sets a flag in the shared
results page (BSS); every later result (stage 1's results on the 8k tape,
stage 2's summary, the system tests' line 0, results page and final code)
reads the flag. The warning and the no-fault ending live in report.asm, so
the shared library carries them to every part of a one-load image.

**Tech Stack:** 6502 assembly (MADS), Python 3 tools (build.py, sim.py on
py65, disktest.py, docshots.py).

**Spec:** `docs/superpowers/specs/2026-11-19-cart-in-way-design.md`

## Global Constraints

- Text, exactly: `CART IN WAY` (bank 3's status and line 0's) and
  `CARTRIDGE IN: $A000-$BFFF NOT TESTED` (the results' extra line).
- White = `C_WHITE = $0E`; the typing click = AUDC1 `$0F` (noise, volume 15),
  AUDF1 `$04`, 80 scan lines with the border white, then a gap with the
  border black and AUDC1 off; the gaps, in 256-line units: 5, 3, 8, 4, 3,
  10, 5, 3, 6 (nine clicks, about 0.8 s).
- A fault always wins: red and beeps, `FAIL`, as now.
- Not in: the diag cartridge (ROM builds), the boot disk's RAM8, the long
  memory test, review item 4.
- No byte-shaving of tested code. Each format carries only code it can run.
  Report every build's net size change (build/*.bin) at the end.
- Builds during work: `python tools/build.py --nodeploy`. Only the last
  build deploys to `_diag`.
- Commit locally after each task (noreply author, the attribution lines);
  never push.
- Never run test 7 (GTIA/ANTIC) in the simulator; never retake its
  pictures.

## Review Focus

1. **The diag cartridge itself** (TRIG3 = 1 on an XL/XE while it's in): no
   warning, no `CART IN WAY`: the ROM builds leave the check out. Test in
   Task 4.
2. **An XL/XE with its built-in BASIC on at boot and no cartridge:** the
   boot switches BASIC out and the RAM reaches $C000: no warning. Test in
   Task 4.
3. **A fault and a cartridge together:** FAIL, red and beeps, not CART IN
   WAY. Test in Task 5.
4. **S pressed with a cartridge in:** line 0 says `SKIPPED` (SKIPRAM wins).
   Test in Task 6.
5. **R at the summary (the RAM test again):** `again` clears BSS, the
   check runs again: the warning again and the same result. Test in
   Task 5.

---

### Task 1: Simulator options, version 0.14, size baseline

**Files:**
- Modify: `tools/sim.py` (the bus read at ~line 195, TRIG3 at ~line 132,
  options at ~line 723, RAMTOP at ~line 857)
- Modify: `tools/build.py:38` (`VERSION = '0.14'`)

**Interfaces:**
- Produces: `sim.py --slot` (with `--basic`: the ROM is a cartridge in the
  slot, on an XL/XE too: TRIG3 reads 1, PORTB bit 1 can't switch it out);
  `sim.py --dmabus` (400/800: an empty address at $A000-$BFFF reads $00
  while DMACTL is nonzero, its high byte while DMACTL is 0: the review's
  hypothesis for item 2).
- Produces: `C:/Users/grimm/AppData/Local/Temp/claude/67b4515142abea82/39f2b632-c215-4b69-9ac5-98b1c4c1f8c1/scratchpad/sizes-0.13.txt`
  (each build/*.bin and its size, before any code change).

- [ ] **Step 1: Record the size baseline** (before the version change: the
  build is still 0.13)

Run: `python tools/build.py --nodeploy`, then write `name size` for every
`build/*.bin` to the scratchpad file above.
Expected: the build exits 0; `git status` shows no release file changed.

- [ ] **Step 2: Add `--slot` and `--dmabus` to sim.py**

`--slot`: in the TRIG3 read, an XL/XE returns 1 also when `self.slot`; in
the $A000-$BFFF read, `self.basic` answers when `not self.xl or self.slot
or not pb & 0x02`. `--dmabus`: in the floating-bus return for $A000-$BFFF,
return 0 when `self.dmabus and self.regs.get(0xD400, 0)`, else `a >> 8`.
Both documented in the module docstring.

- [ ] **Step 3: Show the item 2 bug with --dmabus** (the failing test for
  Task 2)

Run: `python tools/sim.py build/diag-8k-02-rom.cas --ram 0xA000 --dmabus --auto --until 60 --snap 59`
Expected: the BASIC line reads `UNKNOWN` (no cartridge is in: the bug).
Without `--dmabus` the same run shows `BASIC  NONE`.

- [ ] **Step 4: Check --slot**

Run: `python tools/sim.py build/diag-8k-02-rom.cas --xl --basic "//TRUENAS/Media/games/ATARI800/_sysroms/BASIC - Revision A.rom" --slot --auto --until 60 --snap 59`
Expected: `REV A` on the BASIC line, and `RAM 40K` on the FOUND line (the
slot hides $A000-$BFFF).

- [ ] **Step 5: Version 0.14, build, commit**

Set `VERSION = '0.14'`; `python tools/build.py --nodeploy`; expect the
build to write `-v0.14` files. Commit `tools/sim.py tools/build.py` and the
rebuilt release files: "v0.14: sim --slot and --dmabus; version 0.14".

---

### Task 2: The slot check, and review fix 2 (test 1 on a 400/800)

**Files:**
- Create: `src/common/slotrom.asm`
- Modify: `src/system/t_rom.asm:339` (basread, the 400/800 path)

**Interfaces:**
- Produces: `slotrom` (subroutine). Out: C set = a cartridge is in (every
  one of 8 reads of $BFFC returned $00); C clear = not. Writes DMACTL = 0
  and leaves it 0 (the caller turns ANTIC back on). Uses A, X, Y. The
  reads are spaced: a WSYNC between them, and a different number of cycles
  after each WSYNC (X counts down from 8), so no two land at the same point
  of a scan line.

- [ ] **Step 1: The failing test:** Task 1 Step 3 (BASIC `UNKNOWN` with
  `--dmabus`, no cartridge).

- [ ] **Step 2: Write `slotrom` in src/common/slotrom.asm**

- [ ] **Step 3: basread uses it.** The 400/800 path keeps `RAMTOP < $A1`,
  then `jsr slotrom` in place of `lda $BFFC / bne br_no` (C clear:
  `br_no`), then `lda #$22 / sta DMACTL` (scr_on's value) before the CRC.
  `icl '../common/slotrom.asm'` once in system/main.asm, only in builds
  with WANT_ROM and not ROM (the cartridge has its own basread). In the
  32k+ image the system part may share stage 1's copy through the library
  instead of carrying a second one: the builder's call, by size.

- [ ] **Step 4: Run the test again**

Run: Task 1 Step 3's command.
Expected: `BASIC  NONE`.
Run: `python tools/sim.py build/diag-8k-02-rom.cas --basic "//TRUENAS/Media/games/ATARI800/_sysroms/BASIC - Revision A.rom" --auto --until 60 --snap 59`
Expected: `REV A` (a real cartridge is still read).

- [ ] **Step 5: Build, note the size change of the ROM builds, commit**
  "v0.14: test 1 reads the slot with ANTIC off, eight times (review 2)".

---

### Task 3: Review fixes 1 and 3 (src/common/xlram.asm)

**Files:**
- Modify: `src/common/xlram.asm:283-289` (xebanks, the long test's
  refresh wait), `src/common/xlram.asm:46-62` (osout)

**Interfaces:** none new.

- [ ] **Step 1: Fix 1.** `jsr xemain` right before `jsr rwait` (inside
  the `.ifdef XSWEEP` block): main RAM in at $4000-$7FFF while the wait
  prints its progress.

- [ ] **Step 2: Fix 3.** In osout, move `lda #$40 / sta NMIEN` from before
  the two `ramat` probes to after them (just before `inc OSRAM`); osin
  already turns NMI back on when a probe fails. Net 0 bytes.

- [ ] **Step 3: Test fix 1 (in the background: minutes of real time)**

Run: `python tools/sim.py build/diag-16k-memtest.cas --xe --stuck 3C00-4000:1:1 --until 300 --snap 100,200,299 --seconds 9999`
Expected: the screen block falls back to $7C00; after the first pass the
log shows the injected bank 1 fault and no bank 8 (B8) errors.

- [ ] **Step 4: Test fix 3**

Run: `python tools/sim.py build/diag-16k-memtest.cas --xl --ram 0x4000 --until 120 --snap 119 --seconds 9999`
Expected: the test runs passes (`PASSES` counting up), no crash.

- [ ] **Step 5: Build, commit** "v0.14: the long test's 130XE refresh
  wait in main RAM; NMI only once RAM under the OS is found (review 1, 3)".

---

### Task 4: Stage 1: detect, warn, and the 8k tape's own results

**Files:**
- Modify: `src/common/vars.asm` (`CARTIN`), `src/common/hw.asm`
  (`C_WHITE`), `src/common/report.asm` (`typing`, `cartend`),
  `src/tape1/main.asm` (`CARTRAM`, `cartchk`, results, `final`)
- Uses: `src/common/slotrom.asm` (Task 2)

**Interfaces:**
- Produces: `CARTIN = BADMASK+$0F` (vars.asm): nonzero = a cartridge hides
  RAM. Cleared with BSS at boot and by `again`; no other code writes
  BADMASK+$0F.
- Produces: `CARTRAM` (define, tape1/main.asm and stage2.asm): not ROM, and
  ONE16 or not DISK (so: 8k-01-ram, dset-ram, 16k-01-ram, 32k-xl-xe,
  disk-ram16; not cart-ram, not disk-ram8).
- Produces: `typing` (report.asm, `.ifdef CARTRAM`, so in the library):
  the nine clicks of the Global Constraints, the border white on each.
  Needs ANTIC off for the whole screen to flash (the border alone with the
  text screen on: still visible). Leaves AUDC1 off and COLBK black.
- Produces: `cartend` (report.asm, `.ifdef CARTRAM`): the no-fault ending
  with a cartridge in. As `pass` in every way (arm; once, or twice at the
  end; the hold rounds; T/SELECT again, F/OPTION, R, AUTON counting down to
  `jmp (CONTVEC)`), except: `typing` in place of the charge, `C_WHITE` in
  place of `C_GREEN` as the hold colour, and no long flash per bank.
- Produces: `s_cartway` = `CART IN WAY`, `s_cartln` =
  `CARTRIDGE IN: $A000-$BFFF NOT TESTED` (report.asm, with typing).

- [ ] **Step 1: The failing test**

Run: `python tools/sim.py build/diag-8k-01-ram.cas --basic "//TRUENAS/Media/games/ATARI800/_sysroms/BASIC - Revision A.rom" --until 90 --snap 89 --events <scratchpad>/ev1.txt`
Expected now: bank 3 says `PASS` and the result is the green charge (the
gap this task closes).

- [ ] **Step 2: Add CARTIN, C_WHITE, typing, cartend, the strings.**

- [ ] **Step 3: `cartchk` in tape1/main.asm** (`.ifdef CARTRAM`), called
  once after `skipchk` (and after the BACKMK way back, so a return from the
  long test doesn't warn) and before `jsr ramscreen`: if RAMTOP = $A0 and
  (MACHINE nonzero: TRIG3 bit 0 = 1; MACHINE 0: `jsr slotrom` C set), set
  CARTIN and `jsr typing`. DMACTL is left 0 for ramscreen to turn on.

- [ ] **Step 4: The 8k tape's stage 1 results** (`.ifndef ONE16`,
  `.ifndef DISK`): bank 3's status `CART IN WAY` when CARTIN and BADMASK+3
  is 0; `s_cartln` on the row after the bank lines; at `final`, no fault
  and CARTIN: `jmp cartend` in place of `jmp pass`.

- [ ] **Step 5: Run the tests**

Step 1's command. Expected: ev1.txt has nine writes of $0E to COLBK
($D01A) and of $0F to AUDC1 ($D201) before the first `TESTING BANK`;
the snap shows `BANK 3 $8000-$BFFF  CART IN WAY` and `CARTRIDGE IN:
$A000-$BFFF NOT TESTED`; COLBK never $C8 (green) after the results.
No-warning runs (no $0E on COLBK, bank 3 `PASS` or `NONE`):
- `--ram 0x8000 --basic ...` (32K with a cartridge: nothing hidden)
- `--ram 0xA000 --dmabus` (40K, no cartridge, the bus reading $00)
- `--xl --basic ...` without `--slot` (Review Focus 2: built-in BASIC)
- `python tools/sim.py build/diag-cart.car --xl --until 60 --snap 59`
  (Review Focus 1: the diag cartridge: no warning, 64K, PASS)

- [ ] **Step 6: Build; check the 8k tape's stage 1 still ends below $1C00
  with its BSS page** (add an `.error` like RAM8's if the build has none);
  commit "v0.14: the RAM test sees a cartridge over RAM: white, typing,
  CART IN WAY".

---

### Task 5: Stage 2's summary and ending

**Files:**
- Modify: `src/tape1/stage2.asm` (`CARTRAM` define; summary's bank lines
  ~379-430; `fin` ~274)

**Interfaces:**
- Consumes: `CARTIN`, `cartend`, `s_cartway`, `s_cartln` (Task 4).

- [ ] **Step 1: The failing test**

Run: `python tools/sim.py build/diag-16k-01-ram.cas --basic "<BASIC>" --until 120 --snap 119`
Expected now: the summary says `PASS` for bank 3 and plays the charge.

- [ ] **Step 2: The summary:** bank 3's status `CART IN WAY` at SCOL when
  CARTIN and BADMASK+3 is 0; `s_cartln` on the next free row (SROW).
  `fin`: no fault and CARTIN: `jmp cartend`.

- [ ] **Step 3: Run the tests**

Step 1's command. Expected: `CART IN WAY` on bank 3, the extra line, white
and typing at the end (events), no green.
- XL: the same with `--xl --slot`: `CART IN WAY`; bank 4 (under the OS)
  still tested and `PASS`.
- Review Focus 3: add `--stuck 2:5:0`: `FAIL`, red and beeps (COLBK $34),
  no `CART IN WAY` ending.
- Review Focus 5: `--kb` R (KBCODE $28) at the summary: the RAM test
  runs again, the warning plays again (a second run of nine $0E writes),
  the same summary.

- [ ] **Step 4: Build, commit** "v0.14: stage 2's summary: CART IN WAY,
  never a pass with a cartridge in".

---

### Task 6: The menu: line 0, the results page, the final code

**Files:**
- Modify: `src/system/main.asm` (`CARTSYS` define),
  `src/system/common.asm` (line 0 ~835, results page ~957, `final` ~517,
  the strings ~1110)
- Modify: `tools/disktest.py` (a `cartway` check)

**Interfaces:**
- Consumes: `CARTIN` (Task 4).
- Produces: `CARTSYS` (define): SKIPKEY and not ROM (the 32k+ tape's
  system part, the boot disk's pieces).

- [ ] **Step 1: The failing test:** a `cartway` check in disktest.py:
  `['--xl', '--basic', BASIC, '--slot', '--auto']`, expecting line 0's
  status `CART IN WAY` by the menu (about 110 s).

Run: `python tools/disktest.py cartway`
Expected: FAIL (line 0 says `PASS`).

- [ ] **Step 2: line 0 and the results page:** the order SKIPRAM
  (`SKIPPED`), then BADMASK+8 (`FAIL`), then CARTIN (`CART IN WAY`), then
  `PASS`. `final`: no fault, CARTIN set: `partial` (as SKIPRAM).

- [ ] **Step 3: Run the tests**

`python tools/disktest.py cartway`: PASS. `python tools/disktest.py`:
every check passes. The 32k+ tape, `--xl --basic <BASIC> --slot --auto
--walk 8`: the results page shows `CART IN WAY` on line 0 and the yellow
partial ending (COLBK $1C). Review Focus 4: the boot disk with `--kb
BE:2:8` (CTRL+S) and `--slot`: line 0 `SKIPPED`.

- [ ] **Step 4: Build; the boot disk's pieces still fit (the build's
  `.error`s), commit** "v0.14: the menu's line 0 and results: CART IN
  WAY, a partial result".

---

### Task 7: Documents, pictures, the release build

**Files:**
- Modify: `README.md`, `CHANGELOG.md`, `docs/USER-GUIDE.md`,
  `docs/DEVELOPMENT.md`, `docs/design/*.md`, `tools/docshots.py`
  (COLORS: `('white', 0x0E, 'a cartridge in the way: the RAM under it
  can\'t be tested, with a "typing" sound')`), `docs/img/*`

- [ ] **Step 1: The texts.** README: version 0.14, "New in 0.14"
  (CART IN WAY; review fixes); CHANGELOG.md: 0.14 entry. Guide: the RAM
  test's results and summary (`CART IN WAY`, the extra line, the ending),
  the colours and sounds (white, typing), line 0's statuses and the final
  code, BASIC cartridges (the RAM test now says so), `-v0.14` names.
  DEVELOPMENT: sim `--slot`, `--dmabus`; `CARTIN`; the review fixes.
  Design docs: the RAM test's results; the boot disk's line 0.
- [ ] **Step 2: The pictures:** `python tools/docshots.py` for every
  picture but test 7's (title bars at V0.14), and the white swatch. Check
  each against the guide's text. A new picture of the RAM summary with
  CART IN WAY only if the guide's text needs it to be clear.
- [ ] **Step 3: Check:** every doc link resolves; grep for `0.13` names
  where 0.14 is meant, and for `PASS` claims a cartridge breaks.
- [ ] **Step 4: The release build, deployed:** `python tools/build.py`;
  list `_diag` (the v0.13 files left as they are unless Mike says).
- [ ] **Step 5: Sizes:** each build/*.bin against sizes-0.13.txt, the net
  change per build, for the report to Mike.
- [ ] **Step 6: Commit** "v0.14: documents and pictures"; memory notes
  (project-status, next-session) brought up to date. No push.
