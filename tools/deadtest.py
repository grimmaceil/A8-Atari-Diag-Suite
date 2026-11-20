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

CHECKS = {}


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
    old42()
    sys.exit(1 if carttest.run(CHECKS, args) else 0)


if __name__ == '__main__':
    main()
