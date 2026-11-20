# A8 Atari Diag Suite, the disk set: scope and design

By **Michael Grimm**, written with Claude (Anthropic's AI). MIT license
(see [LICENSE](../../LICENSE)).

Status at 0.14 (2026-11-19): built, and checked in the simulator on 8K
and on 16K and up. The boot disk has its own design,
[Atari-diag-boot-disk-scope.md](Atari-diag-boot-disk-scope.md); how the
code is put together is in [docs/DEVELOPMENT.md](../DEVELOPMENT.md).

---

## 1. Why

The boot disk is the most convenient free way (the cartridge is the best
test): one disk, the cartridge's menu, each test loaded as it is picked. But it starts with the RAM test
and keeps loading pieces from the disk as you go, so a machine that is
sick enough may not get far on it. The disk set gives such a machine more
ways in (Mike: "in the case of failures they have more options that
should be helpful"): the 8k tapes as disks, one test to a disk. Each loads
once and runs only its own test, as a tape does, so a keyboard or a
joystick can still be tested when something else is failing.

## 2. The rules

- **Only disks are added.** Every other release file stays byte for byte
  as it was (Mike: "the others should be binary same and we are only
  adding disks").
- **Named like the tapes,** and holding the tapes' own programs byte for
  byte, so the title bars and the `NEXT:` lines name the disks too. Two
  strings still say tape: test 1's self-check line (`DIAG TAPE`) on the
  ROM disk, and the video disk's `LAST 8K TAPE`; only the RAM disk is
  rebuilt (`DSKLD`: `NOT ON DISK`).
- **No DOS, no cartridge:** switch on with the disk in drive 1 (or
  mounted as D1:). A BASIC cartridge left in does no harm, as for a tape:
  the OS boots the disk before it would start the cartridge (the
  documents say to take it out all the same).
- **Needs 8K,** as the 8k tapes do. With 16K or more, three disks do more
  than their tapes (section 3).

## 3. The disks

`disk-set/`:

| Disk | 8K | 16K and up |
|---|---|---|
| `diag-8k-01-ram.atr` | the RAM test, then `16K ONLY. NEXT: DIAG-8K-02-ROM`, as the tape | after its result a key goes on to part 2, read from the same disk by itself: the RAM part 1 sat in, and an XL/XE's extras |
| `diag-8k-02-rom.atr` | the ROM test (1) | the same |
| `diag-8k-03-input.atr` | keyboard and console keys (2, 3) | the same |
| `diag-8k-04-ports.atr` | joysticks and paddles (4, 5) | the same |
| `diag-8k-05-sound.atr` | POKEY (6), without the "hello" | POKEY with the sampled "hello" (item 7), as on the boot disk |
| `diag-8k-06-video.atr` | GTIA/ANTIC (7) | the same |
| `diag-8k-memtest.atr` | `diag-8k-memtest` (400/800) | `diag-16k-memtest` instead (its title bar says so): all the RAM, an XL/XE's too, and the refresh check |

`disks/` also holds two single-purpose disks, built the same way:
- `diag-16k-memtest.atr`: boots straight into `diag-16k-memtest`.
- `diag-bascrc.atr`: boots straight into BASCRC, the BASIC check in
  machine code, and is a DOS 2 disk too (`BASCRC.XEX`, `BASCRC.LST`); see
  DEVELOPMENT.md.

## 4. How a tape program boots from a disk

The OS's disk boot reads the same 6-byte header as its cassette boot
(flags, sector count, load address, init), loads that many sectors to the
load address and calls load+6. So a tape's program boots from sector 1
unchanged: `mkatr.cas_image` takes it from the tape file (the data of its
$FC records, as many as the header counts) and `mkatr.plain` writes it
from sector 1. The program sets the machine up itself (POKEY, ANTIC, the
motor), as it does after a tape load.

## 5. The RAM disk's part 2

`diag-8k-01-ram` has two parts on tape: part 1 boots, and on 16K and up
reads part 2 through the OS's SIOV, record by record. On the disk, part 1
is built with `DSKLD`: `common/loader.asm` reads part 2 from the sectors
after its own instead (from sector `(IMGEND-LOAD)/128+1`), a sector at a
time into the cassette buffer, and the rest of the loader runs as for the
tape. Part 2 itself is the tape's, byte for byte (`build_diskset` stops if
it isn't). Where the tape's part 1 says `NOT ON TAPE` (what it read isn't
part 2), the disk's says `NOT ON DISK`.

## 6. The two-program disks

`diag-8k-05-sound` and `diag-8k-memtest` carry two programs each: the 8k
tape's, and a 16K one. Sectors 1-4 are a boot of their own
(`src/disk/setboot.asm`, loaded by the OS to $0600-$07FF): it reads the RAM
the OS found (RAMTOP, $6A), takes the first program under 16K and the
second from 16K up, and loads it with the boot disk's loader (`dload.asm`
with `DLBOOT`: one way, no screen), which enters it at $0806 as the OS
does from tape. The two programs' places come from `build/settab.asm`
(`mkatr.settab`), as the boot disk's come from `disktab.asm`.

- The 16K sound program is `system` with `HELLO16`: the sound test with
  the recording in the image (`SAMPLED`), as `diag-16k-03-hello`, but named
  as the 8k sound tape.
- The 16K memtest is `diag-16k-memtest`'s program.

A sector that won't read in this boot turns the screen red with a low
tone; a key, START or fire tries again. A disk that won't boot at all gets
the OS's `BOOT ERROR`, and the OS tries again.

## 7. Build

`build.py`'s `build_diskset` (after the tapes, which it reads):
`mkatr.plain` for the one-program disks, `mkatr.choice` for the two-program
ones (the boot, then both programs), the RAM disk's part 1 built again
with `DSKLD` (and `NORAMK`, as the tape's part 1). Every build deploys the
changed disks to `_diag` with the rest.

## 8. Before 0.12: the executables

From 0.2 to 0.11 this file was the design of the executables (`.xex`):
`diag-32k-xl-xe.xex`, `diag-16k-memtest.xex` and, from 0.9,
`diag-bascrc.xex`, for DOS or a loader. They needed DOS and 32K (16K for
the memory test and BASCRC). The boot disk (0.10) does what they did with
no DOS and on 8K, so they went in 0.12: the long memory test and BASCRC
got disks of their own. Their design is this file at the tag `v0.11`.
