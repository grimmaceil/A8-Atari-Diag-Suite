#!/usr/bin/env python3
"""Build the cartridge: an AtariMax 128K (.car type 41), 16 banks of 8K at
$A000-$BFFF. The tests run from ROM (src/cart/romsum.asm has the layout):

  the code banks    one program each, assembled at $A000 (build.py):
                    0 the RAM test, 1 and 2 the system tests and the menu
  the next banks    the long memory test's boot image (the same kind
                    mkcas.py wraps as a tape), DATAPG pages to a bank; the
                    menu's loader copies it to RAM (src/cart/ldmem.asm)
  then              data banks (--data): one file each, from $A000, read
                    while that bank is switched in (src/cart/hello.asm)
  every bank        the same 32-byte tail at $BFE0: the power-on jump to
                    bank 0, the bank's sum, the bank switch (XBANK) and
                    the cartridge header
"""
import argparse
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mkcas import patch_boot   # noqa: E402

BANK = 0x2000
NBANKS = 16
TAILAT = 0x1FE0                # $BFE0
DATAPG = 0x1F                  # image pages in a data bank ($A000-$BEFF)
CARTYPE = 41                   # AtariMax 128K
TAIL = bytes([0xA2, 0x00,              # $BFE0  ldx #0
              0x9D, 0x00, 0xD5,        #        sta $D500,x   (bank 0)
              0x4C, 0x00, 0xA0,        #        jmp $A000     its cold start
              0x60,                    # $BFE8  rts           (the OS's init)
              0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
              0x00, 0x00,              # $BFEE  the bank's sum
              0x9D, 0x00, 0xD5,        # $BFF0  sta $D500,x   XBANK
              0x4C, 0x03, 0xA0,        #        jmp $A003     the warm entry
              0xFF, 0xFF, 0xFF, 0xFF,
              0xE0, 0xBF,              # $BFFA  run address
              0x00,                    # $BFFC  a cartridge is in
              0x04,                    # $BFFD  start it, no disk boot
              0xE8, 0xBF])             # $BFFE  init address
assert len(TAIL) == BANK - TAILAT


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('car')
    ap.add_argument('--bank', action='append', required=True, metavar='BIN',
                    help='a code bank, assembled at $A000 (in bank order)')
    ap.add_argument('--mem', nargs=2, metavar=('BIN', 'LAB'), required=True)
    ap.add_argument('--data', action='append', default=[], metavar='BIN',
                    help='a data bank, after the memory test')
    ap.add_argument('--data-at', type=int, help='the bank the first --data must land in')
    a = ap.parse_args()

    banks = []
    for path in a.bank:
        code = Path(path).read_bytes()
        if len(code) > TAILAT:
            sys.exit(f'{path}: {len(code)} bytes, a bank holds {TAILAT}')
        banks.append(bytearray(code + b'\xff' * (TAILAT - len(code))))
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
    if len(banks) > NBANKS:
        sys.exit('the programs do not fit in the cartridge')
    while len(banks) < NBANKS:
        banks.append(bytearray(b'\xff' * TAILAT))
    for b in banks:
        b += TAIL
        sm = sum(b) & 0xFFFF           # (the sum's own two bytes are 0 here)
        b[0x1FEE:0x1FF0] = struct.pack('<H', sm)

    rom = b''.join(bytes(b) for b in banks)
    head = b'CART' + struct.pack('>II', CARTYPE, sum(rom) & 0xFFFFFFFF) + bytes(4)
    open(a.car, 'wb').write(head + rom)
    print(f'{a.car}: AtariMax 128K, code banks 0-{membk - 1} ('
          + ', '.join(f'{len(Path(p).read_bytes())} bytes' for p in a.bank)
          + f' of {TAILAT}), memtest {len(img) // 256} pages from bank {membk}'
          + ''.join(f', {Path(p).name} in bank {membk + -(-len(img) // 256 // DATAPG) + i}'
                    for i, p in enumerate(a.data)))


if __name__ == '__main__':
    main()
