# Which RAM chip holds which data bit

Research for the dead test's chip names (design: the 0.15 dead test,
"Decided with Mike", item 2). Nothing here is in the code yet: a table goes
in only once it is confirmed, by Mike's own boards or by two sources that
agree. Until then the dead test and the suite name the bank and the bit.

Every machine here uses DRAM one bit wide (4116 on the 800's boards, 4164
on the XL/XE): eight chips to a bank, one per data bit, so a bad bit in a
bank points at one chip.

## Atari 800: 8K and 16K RAM boards (Z5xx)

Source: *Atari 400/800 Home Computer Field Service Manual* (1982), Section
3, Table 3-3 "Defective RAM Identified" (p. 3-15), read from the archive.org
OCR text (the table came through a machine summary of that text, not a
verbatim read). The same table appears again in Section 5 (Table 5-2,
p. 5-39) with designators that OCR mangled (Z3xx), so it can't serve as the
second source. **Status: unconfirmed.**

| Data bit | 8K board | 16K board |
|---|---|---|
| D0 | Z512 | Z512 |
| D1 | Z511 | Z511 |
| D2 | Z510 | Z510 |
| D3 | Z508 | Z509 |
| D4 | Z509 | Z508 |
| D5 | Z507 | Z507 |
| D6 | Z505 | Z506 |
| D7 | Z506 | Z505 |

The two boards differ for D3/D4 and D6/D7, as the table gives them; that
is worth the most care when checking.

To confirm: the scan's pages 3-15 (the table) and 2-18 to 2-21 (the 8K and
16K boards' silkscreens and schematics: Figures 2-13 to 2-16), or Mike's
boards: the silkscreen labels next to each chip, and which data line each
one's pin 14 (DOUT) and pin 2 (DIN) go to.

## Not found yet

- **The 400's RAM** (on its main board): the field service manual's 400
  sections came through OCR unreadable; no mapping.
- **The 800XL and 130XE** (64K on the board, eight 4164s; the 130XE's 64K
  more): the 800XL service manual on archive.org couldn't be reached
  (connection refused); no mapping yet.
- **The 1981 System Service Manual** (the second source for the 800): the
  same, couldn't be reached.

## When a table is confirmed

The dead test's text lines (src/deadtest/text.txt) get a chip name per bank
row variant ("BANK 1 $0000-$3FFF  BAD   CHIP Z508") on the 400/800, chosen
by the lowest bad bit as the beeps are. The 16K and 8K boards need telling
apart; the dead test can't see which board is in a slot, so the line would
name both where they differ, or the guide carries the table.
