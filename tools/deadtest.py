#!/usr/bin/env python3
"""The dead test in the simulator (tools/sim.py), as carttest.py checks the
rest of the cartridge.

  python tools/deadtest.py            every check
  python tools/deadtest.py b-good     only these
  python tools/deadtest.py --static   stage B's code: no stack, zero page
                                      or indirect use, no OS ROM reads
  python tools/deadtest.py --layout   every bank's tail in the 8 Mbit image

Checks run images in build/ with the real OS ROM, as carttest.py does
(the same check format, carttest.run). build/scratch/old42.car is the 8
Mbit image as an older 8 Mbit cartridge (.car type 42: it powers up in
bank 127), made before the checks run.
"""
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import carttest   # noqa: E402

BUILD = carttest.BUILD
SCRATCH = BUILD / 'scratch'

FOUND48 = 'FOUND: 400/800  RAM 48K'
CHECKS = {
    # the diag start: every bank's tail leads to the dead test, which hands
    # over to the suite (its RAM test's FOUND line), on each cartridge
    'skel-8m': ('diag-cart-8mbit.car', [], [(1, '#dead#test'), (40, FOUND48)]),
    'skel-old8m': ('scratch/old42.car', [], [(1, '#dead#test'), (40, FOUND48)]),
    'skel-128k': ('diag-cart.car', [], [(1, '#dead#test'), (40, FOUND48)]),
    # the standalone 8K: no suite to hand over to
    'skel-std': ('diag-deadtest.car', ['--ram', '0'], [(1, '#dead#test'), (20, '!FOUND:')]),
}

TAIL_RUN = bytes.fromhex('A2009D00D54C00A0')     # $BFE0: bank 0's cold start
TAIL_DIAG = bytes.fromhex('8D05D54C00A0')        # $BFE8: sta $D505, jmp $A000
TAIL_XBANK = bytes.fromhex('9D00D54C03A0')       # $BFF0
HEAD_SUITE = bytes.fromhex('E0BF0080E8BF')       # $BFFA: run, in, diag, init $BFE8
HEAD_DEAD = bytes.fromhex('E0BF000406A0')        # dead banks: ordinary, init $A006


def layout(raw, name):
    """Every bank's tail as the plan's table says; the dead banks (from bank
    5: jmp at $A000 and $A003, rts at $A006) carry the ordinary header and a
    right CRC32, every other bank the diag header; every sum right."""
    import zlib
    bad = []
    banks = [raw[i:i + 0x2000] for i in range(0, len(raw), 0x2000)]
    dead = [i for i, b in enumerate(banks)
            if i >= 5 and b[0] == 0x4C and b[3] == 0x4C and b[6] == 0x60]
    if not dead or dead != list(range(5, 5 + len(dead))):
        bad.append(f'dead banks {dead}: want a run from bank 5')
    for i, b in enumerate(banks):
        want = HEAD_DEAD if i in dead else HEAD_SUITE
        for at, exp in ((0x1FE0, TAIL_RUN), (0x1FE8, TAIL_DIAG), (0x1FF0, TAIL_XBANK),
                        (0x1FFA, want)):
            if b[at:at + len(exp)] != exp:
                bad.append(f'bank {i} ${0xA000 + at:04X}: {b[at:at + len(exp)].hex()} != {exp.hex()}')
        if (sum(b) - b[0x1FEE] - b[0x1FEF]) & 0xFFFF != b[0x1FEE] | b[0x1FEF] << 8:
            bad.append(f'bank {i}: sum wrong')
        if (i < 3 or i in dead) and struct.unpack('<I', b[0x1FF6:0x1FFA])[0] != zlib.crc32(b[:0x1F00]):
            bad.append(f'bank {i}: CRC32 wrong')
    print(f'{name}: {len(banks)} banks, dead banks {dead[0] if dead else "-"}-'
          f'{dead[-1] if dead else "-"}: {"PASS" if not bad else "FAIL"}')
    for m in bad[:20]:
        print(' ', m)
    return len(bad)


def old42():
    """build/scratch/old42.car: the 8 Mbit .car (type 75) as type 42."""
    src = BUILD / 'diag-cart-8mbit.car'
    if not src.exists():
        return
    raw = bytearray(src.read_bytes())
    raw[4:8] = struct.pack('>I', 42)
    SCRATCH.mkdir(exist_ok=True)
    (SCRATCH / 'old42.car').write_bytes(raw)


def main():
    args = sys.argv[1:]
    if '--layout' in args:
        n = layout((BUILD / 'diag-cart-8mbit.bin').read_bytes(), 'diag-cart-8mbit.bin')
        n += layout((BUILD / 'diag-cart.car').read_bytes()[16:], 'diag-cart.car')
        sys.exit(1 if n else 0)
    old42()
    sys.exit(1 if carttest.run(CHECKS, args, step=0.5) else 0)


if __name__ == '__main__':
    main()
