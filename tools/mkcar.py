#!/usr/bin/env python3
"""Build the cartridge: an AtariMax 128K (.car type 41), 16 banks of 8K at
$A000-$BFFF; or with --raw8m, the same programs on the 8 Mbit MaxFlash
(128 banks: the code banks built with CART8M, romsum.asm), as the raw 1 MB
image its flasher writes (Maxflash Cartridge Studio: Cartridge, Program)
and a .car of type 75 for the simulator. The tests run from ROM
(src/cart/romsum.asm has the layout):

  the code banks    one program each, assembled at $A000 (build.py):
                    0 the RAM test, 1 and 2 the system tests and the menu
  the next banks    the long memory test's boot image (the same kind
                    mkcas.py wraps as a tape), DATAPG pages to a bank; the
                    menu's loader copies it to RAM (src/cart/ldmem.asm)
  then              data banks (--data): one file each, from $A000, read
                    while that bank is switched in (src/cart/hello.asm)
  then              the dead test's banks (--deadbank, from --dead-at:
                    src/deadtest/main.asm), each a whole program at $A000
  every bank        the same 32-byte tail at $BFE0 (all 128 on the 8 Mbit:
                    it powers up in bank 0, or bank 127 on older ones): the
                    power-on jump to bank 0, the bank's sum, the bank
                    switch (XBANK), a code bank's CRC32 ($A000-$BEFF, for
                    the ROM test's self-check) and the cartridge header
"""
import argparse
import struct
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mkcas import patch_boot   # noqa: E402

BANK = 0x2000
NBANKS = 16
TAILAT = 0x1FE0                # $BFE0
CODEMAX = 0x1F00               # a code bank's code: $A000-$BEFF, which its
CRCAT = 0x1FF6                 # CRC32 at $BFF6 covers (t_rom.asm's selfchk)
DATAPG = 0x1F                  # image pages in a data bank ($A000-$BEFF)
CARTYPE = 41                   # AtariMax 128K
CARTYPE8M = 75                 # AtariMax 1 MB (the 8 Mbit MaxFlash), new
NBANKS8M = 128
TAIL = bytes([0xA2, 0x00,              # $BFE0  ldx #0
              0x9D, 0x00, 0xD5,        #        sta $D500,x   (bank 0)
              0x4C, 0x00, 0xA0,        #        jmp $A000     its cold start
              0x60,                    # $BFE8  rts           (the OS's init)
              0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
              0x00, 0x00,              # $BFEE  the bank's sum
              0x9D, 0x00, 0xD5,        # $BFF0  sta $D500,x   XBANK
              0x4C, 0x03, 0xA0,        #        jmp $A003     the warm entry
              0xFF, 0xFF, 0xFF, 0xFF,  # $BFF6  a code bank: the CRC32 of $A000-$BEFF
              0xE0, 0xBF,              # $BFFA  run address
              0x00,                    # $BFFC  a cartridge is in
              0x04,                    # $BFFD  start it, no disk boot
              0xE8, 0xBF])             # $BFFE  init address
assert len(TAIL) == BANK - TAILAT


def tail(deadbk, dead):
    """The tail with the dead test (the plan's table): $BFE8 selects the
    dead test's first bank and jumps to its cold start, which the OS's diag
    jump reaches from every bank but the dead ones; those carry an ordinary
    header whose init is the rts at $A006, so the OS's cold start after
    the hand-over runs bank 0 as it always has."""
    t = bytearray(TAIL)
    t[0x08:0x0E] = bytes([0x8D, deadbk, 0xD5, 0x4C, 0x00, 0xA0])   # sta $D500+n, jmp $A000
    t[0x1D:0x20] = bytes([0x04, 0x06, 0xA0]) if dead else bytes([0x80, 0xE8, 0xBF])
    return bytes(t)


def std8k(car, rom, path):
    """The standalone dead test: one 8K bank, a diag header at $BFFA, no
    bank switching: a .car of type 1 (standard 8K) and the raw 8K."""
    code = Path(path).read_bytes()
    if len(code) > CODEMAX:
        sys.exit(f'{path}: {len(code)} bytes, the standalone holds {CODEMAX}')
    b = bytearray(code + b'\xff' * (BANK - len(code)))
    b[0x1FFA:0x2000] = bytes([0x00, 0xA0, 0x00, 0x80, 0x00, 0xA0])
    Path(rom).write_bytes(b)
    head = b'CART' + struct.pack('>II', 1, sum(b) & 0xFFFFFFFF) + bytes(4)
    Path(car).write_bytes(head + b)
    print(f'{car}: the standalone dead test, {len(code)} bytes of {CODEMAX}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('car')
    ap.add_argument('--bank', action='append', metavar='BIN',
                    help='a code bank, assembled at $A000 (in bank order)')
    ap.add_argument('--mem', nargs=2, metavar=('BIN', 'LAB'))
    ap.add_argument('--data', action='append', default=[], metavar='BIN',
                    help='a data bank, after the memory test')
    ap.add_argument('--data-at', type=int, help='the bank the first --data must land in')
    ap.add_argument('--raw8m', metavar='BIN', help='the 8 Mbit MaxFlash: 128 banks, this raw '
                    'image too (the .car is then type 75)')
    ap.add_argument('--deadbank', action='append', default=[], metavar='BIN',
                    help="a dead test bank, assembled at $A000 (in bank order)")
    ap.add_argument('--dead-at', type=int, help='the bank the first --deadbank must land in')
    ap.add_argument('--std8k', metavar='ROM', help='the standalone dead test: the .car (type '
                    '1) and this raw 8K, from the one --deadbank')
    a = ap.parse_args()
    if a.std8k:
        std8k(a.car, a.std8k, a.deadbank[0])
        return
    if not a.bank or not a.mem:
        sys.exit('--bank and --mem are needed')
    nbanks = NBANKS8M if a.raw8m else NBANKS

    banks = []
    for path in a.bank:
        code = Path(path).read_bytes()
        if len(code) > CODEMAX:
            sys.exit(f'{path}: {len(code)} bytes, a code bank holds {CODEMAX}')
        banks.append(bytearray(code + b'\xff' * (TAILAT - len(code))))
    ncode = len(banks)
    img, nrec, load, s = patch_boot(*a.mem)
    if load != 0x0800:
        sys.exit('the memory test must run at $0800')
    img += bytes(-len(img) % 256)
    membk = len(banks)
    for i in range(0, len(img), DATAPG * 256):
        part = img[i:i + DATAPG * 256]
        banks.append(bytearray(part + b'\xff' * (TAILAT - len(part))))
    if a.data and a.data_at is not None and a.data_at != len(banks):
        sys.exit(f'the first data bank is {len(banks)}, the code was built for {a.data_at}')
    for path in a.data:
        d = Path(path).read_bytes()
        if len(d) > TAILAT:
            sys.exit(f'{path}: {len(d)} bytes, a bank holds {TAILAT}')
        banks.append(bytearray(d + b'\xff' * (TAILAT - len(d))))
    deadbk = len(banks)
    if a.deadbank and a.dead_at is not None and a.dead_at != deadbk:
        sys.exit(f'the first dead bank is {deadbk}, the code was built for {a.dead_at}')
    for path in a.deadbank:
        code = Path(path).read_bytes()
        if len(code) > CODEMAX:
            sys.exit(f'{path}: {len(code)} bytes, a dead bank holds {CODEMAX}')
        banks.append(bytearray(code + b'\xff' * (TAILAT - len(code))))
    dead = range(deadbk, deadbk + len(a.deadbank))
    if len(banks) > NBANKS:            # (the code addresses banks 0-15 only)
        sys.exit('the programs do not fit in the cartridge')
    while len(banks) < nbanks:
        banks.append(bytearray(b'\xff' * TAILAT))
    for i, b in enumerate(banks):
        b += tail(deadbk, i in dead) if a.deadbank else TAIL
        if i < ncode or i in dead:
            b[CRCAT:CRCAT + 4] = struct.pack('<I', zlib.crc32(bytes(b[:CODEMAX])))
        sm = sum(b) & 0xFFFF           # (the sum's own two bytes are 0 here)
        b[0x1FEE:0x1FF0] = struct.pack('<H', sm)

    rom = b''.join(bytes(b) for b in banks)
    head = b'CART' + struct.pack('>II', CARTYPE8M if a.raw8m else CARTYPE,
                                 sum(rom) & 0xFFFFFFFF) + bytes(4)
    open(a.car, 'wb').write(head + rom)
    if a.raw8m:
        open(a.raw8m, 'wb').write(rom)
    kind = '8 Mbit MaxFlash (1 MB raw)' if a.raw8m else 'AtariMax 128K'
    print(f'{a.raw8m or a.car}: {kind}, code banks 0-{membk - 1} ('
          + ', '.join(f'{len(Path(p).read_bytes())} bytes' for p in a.bank)
          + f' of {CODEMAX}), memtest {len(img) // 256} pages from bank {membk}'
          + ''.join(f', {Path(p).name} in bank {membk + -(-len(img) // 256 // DATAPG) + i}'
                    for i, p in enumerate(a.data)))


if __name__ == '__main__':
    main()
