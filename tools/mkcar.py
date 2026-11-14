#!/usr/bin/env python3
"""Build the cartridge: an AtariMax 128K (.car type 41) holding the 32k
diag image and the memory test's (the same kind of boot image mkcas.py
wraps as a tape), with the menu and loader of src/cart/cart.asm at
STUB-$BFFF in every bank.

  bank n, $A000-STUB-1   DATAPG pages of the images, the diag's from bank 0,
                         the memory test's from the next free bank
  bank n, STUB-$BFFF     the menu, the loader and the cartridge header
  banks not needed       $FF, then the menu
"""
import argparse
import struct
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mkcas import patch_boot   # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
MADS = ROOT / 'tools' / 'bin' / 'mads.exe'
STUB = 0xB800
DATAPG = (STUB - 0xA000) // 256
NBANKS = 16
CARTYPE = 41                   # AtariMax 128K


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('car')
    ap.add_argument('--diag', nargs=2, metavar=('BIN', 'LAB'), required=True)
    ap.add_argument('--mem', nargs=2, metavar=('BIN', 'LAB'), required=True)
    ap.add_argument('--version', default='0.0', help='MAJOR.MINOR, shown on the menu')
    a = ap.parse_args()

    imgs = []
    for bl in (a.diag, a.mem):
        img, nrec, load, s = patch_boot(*bl)
        if load != 0x0800:
            sys.exit('an image must run at $0800')
        imgs.append(img + bytes(-len(img) % 256))
    data = bytearray(b'\xff' * (NBANKS * DATAPG * 256))
    vmaj, vmin = a.version.split('.')
    defs, bank = {'VMAJ': vmaj, 'VMIN': vmin}, 0
    for img, tag in zip(imgs, ('DIAG', 'MEM')):
        npg = len(img) // 256
        defs[f'{tag}BK'], defs[f'{tag}PG'] = bank, npg
        data[bank * DATAPG * 256:bank * DATAPG * 256 + len(img)] = img
        bank += -(-npg // DATAPG)
    if bank > NBANKS:
        sys.exit('the images do not fit in the cartridge')

    out = str(Path(a.car).resolve())[:-4]
    args = [str(MADS), 'cart.asm', f'-o:{out}.stub.bin', f'-l:{out}.stub.lst',
            f'-d:STUB=${STUB:04X}', f'-d:DATAPG={DATAPG}'] + [f'-d:{k}={v}' for k, v in defs.items()]
    r = subprocess.run(args, cwd=ROOT / 'src' / 'cart', capture_output=True, text=True)
    if r.returncode:
        sys.exit('cart.asm:\n' + r.stdout + r.stderr)
    stub = Path(f'{out}.stub.bin').read_bytes()
    if len(stub) != 0xC000 - STUB:
        sys.exit(f'cart.asm: {len(stub)} bytes, expected {0xC000 - STUB}')

    rom = b''.join(bytes(data[b * DATAPG * 256:(b + 1) * DATAPG * 256]) + stub
                   for b in range(NBANKS))
    head = b'CART' + struct.pack('>II', CARTYPE, sum(rom) & 0xFFFFFFFF) + bytes(4)
    open(a.car, 'wb').write(head + rom)
    print(f'{a.car}: AtariMax 128K, diag {defs["DIAGPG"]} pages from bank {defs["DIAGBK"]}, '
          f'memtest {defs["MEMPG"]} pages from bank {defs["MEMBK"]}, banks used {bank} of {NBANKS}')


if __name__ == '__main__':
    main()
