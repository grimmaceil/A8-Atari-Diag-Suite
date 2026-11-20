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

    # stage B, the RAM test with no RAM: its results as the simulator saw
    # them at the hand-over (sim.py's dead: line): DDRA bank 1, DDRB bank
    # 2, S bank 3 ($FF: no RAM); PACTL/PBCTL $38 with bit 0 set ($39) for a
    # bad zero page / stack page; portb: every value written to PORTB
    'b-good': ('diag-cart-8mbit.car', [], [('out', 'ddra=$00 ddrb=$00 s=$00 pactl=$38 pbctl=$38')]),
    'b-b2d4': ('diag-cart-8mbit.car', ['--stuck', '2:5:0'],
               [('out', 'ddra=$00 ddrb=$10 s=$00 pactl=$38 pbctl=$38')]),
    'b-16k': ('diag-cart-8mbit.car', ['--ram', '0x4000'],
              [('out', 'ddra=$00 ddrb=$FF s=$FF pactl=$38 pbctl=$38')]),
    'b-noram': ('diag-cart-8mbit.car', ['--ram', '0'],
                [('out', 'ddra=$FF ddrb=$FF s=$FF pactl=$39 pbctl=$39')]),
    'b-hole1': ('diag-cart-8mbit.car', ['--hole', '0000-4000'],
                [('out', 'ddra=$FF ddrb=$00 s=$00 pactl=$39 pbctl=$39')]),
    'b-zp': ('diag-cart-8mbit.car', ['--stuck', '0000-0100:4:1'],
             [('out', 'ddra=$08 ddrb=$00 s=$00 pactl=$39 pbctl=$38')]),
    'b-stack': ('diag-cart-8mbit.car', ['--stuck', '0100-0200:1:0'],
                [('out', 'ddra=$01 ddrb=$00 s=$00 pactl=$38 pbctl=$39')]),
    'b-mirror': ('diag-cart-8mbit.car', ['--mirror'], [('out', 'dead: '), ('out', '!s=$00 ')]),
    'b-xe': ('diag-cart-8mbit.car', ['--xe', '--xejunk'],
             [('out', 'ddra=$00 ddrb=$00 s=$00 pactl=$38 pbctl=$38 portb=FF')]),
    'b-std': ('diag-deadtest.car', ['--stuck', '2:5:0'],
              [('out', 'ddra=$00 ddrb=$10 s=$00 pactl=$38 pbctl=$38')]),

    # the show bank: each row's line chosen by the display-list pointer,
    # bit boxes (player 0 written directly: GRAFP0 $D00D), the verdict,
    # START to go on from a fault
    'show-pass': ('diag-cart-8mbit.car', [],
                  [(4, 'BANK 1 $0000-$3FFF  OK'), (4, 'BANK 2 $4000-$7FFF  OK'),
                   (4, 'BANK 3 $8000-$9FFF  OK'), (4, 'ZERO PAGE  OK'), (4, 'STACK      OK'),
                   (4, 'DEAD TEST -- PASS'), (40, FOUND48)]),
    'show-b2d4': ('diag-cart-8mbit.car', ['--stuck', '2:5:0'],
                  [(4, 'BANK 2 $4000-$7FFF  BAD'), (4, 'DEAD TEST -- FAULT'),
                   (4, 'START=GO ON  SELECT=TONES  OPTION=FLASH'),
                   ('ev', 2, 6, 0xD00D, 0x10, 'min', 1), (30, '!FOUND:')]),
    'show-b2d4-start': ('diag-cart-8mbit.car', ['--stuck', '2:5:0', '--con', 'START:10'],
                        [(4, 'DEAD TEST -- FAULT'), (45, 'FOUND: 400/800')]),
    'show-16k': ('diag-cart-8mbit.car', ['--ram', '0x4000'],
                 [(4, 'BANK 2 $4000-$7FFF  NO RAM'), (4, 'BANK 3 $8000-$9FFF  NO RAM'),
                  (4, 'DEAD TEST -- PASS')]),
    'show-noram': ('diag-cart-8mbit.car', ['--ram', '0'],
                   [(4, 'BANK 1 $0000-$3FFF  NO RAM'), (4, 'ZERO PAGE  BAD'),
                    (4, 'STACK      BAD'), (4, 'DEAD TEST -- FAULT')]),
    'show-std': ('diag-deadtest.car', ['--stuck', '2:5:0'],
                 [(4, 'BANK 2 $4000-$7FFF  BAD'), (4, 'DEAD TEST -- FAULT'), (20, '!FOUND:')]),
    'show-mixed': ('diag-cart-8mbit.car', ['--hole', '0000-4000', '--stuck', '2:5:0',
                                           '--hole', '8000-A000'],
                   [(4, 'BANK 1 $0000-$3FFF  NO RAM'), (4, 'BANK 2 $4000-$7FFF  BAD'),
                    (4, 'BANK 3 $8000-$9FFF  NO RAM'), ('ev', 2, 6, 0xD00D, 0x10, 'min', 1)]),

    # the beep codes (AUDF1: report.asm's F_LONG 72, F_SHORT 35, the charge
    # F_J0-F_J3 81 60 47 40): bank 2, D4: two long beeps, five short, in the
    # first round (doom first; the round is ~9 s)
    'beep-b2d4': ('diag-cart-8mbit.car', ['--stuck', '2:5:0'],
                  [('ev', 2, 12, 0xD200, 72, 'min', 2), ('ev', 2, 12, 0xD200, 72, 'max', 2),
                   ('ev', 2, 12, 0xD200, 35, 'min', 5), ('ev', 2, 12, 0xD200, 35, 'max', 5)]),
    'beep-pass': ('diag-cart-8mbit.car', [],
                  [('ev', 1, 5, 0xD200, 81, 'min', 1), ('ev', 1, 5, 0xD200, 60, 'min', 1),
                   ('ev', 1, 5, 0xD200, 47, 'min', 1), ('ev', 1, 5, 0xD200, 40, 'min', 1),
                   (40, FOUND48)]),
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


SIZES = {'imp': 1, 'acc': 1, 'imm': 2, 'zpg': 2, 'zpx': 2, 'zpy': 2, 'inx': 2, 'iny': 2,
         'rel': 2, 'abs': 3, 'abx': 3, 'aby': 3, 'ind': 3}
STACKOPS = {0x00: 'BRK', 0x08: 'PHP', 0x20: 'JSR', 0x28: 'PLP', 0x40: 'RTI', 0x48: 'PHA',
            0x60: 'RTS', 0x68: 'PLA'}


def static():
    """Stage B (SBBEG-SBEND in bank 5) uses no stack, no zero-page or
    indirect addressing, no unknown opcode, and reads nothing at
    $C000-$FFFF but the chips ($D000-$D7FF): every instruction, in order."""
    from py65.devices.mpu6502 import MPU
    lab = {}
    for line in open(BUILD / 'dead5.lab', encoding='latin-1'):
        p = line.split()
        if len(p) == 3:
            lab[p[2].upper()] = int(p[1], 16)
    code = (BUILD / 'dead5.bin').read_bytes()
    table = MPU().disassemble
    pc, n, bad = lab['SBBEG'], 0, []
    while pc < lab['SBEND']:
        op = code[pc - 0xA000]
        mnem, mode = table[op]
        size = SIZES[mode]
        arg = int.from_bytes(code[pc - 0xA000 + 1:pc - 0xA000 + size], 'little')
        why = (STACKOPS.get(op) or ('an unknown opcode' if mnem == '???' else None)
               or (f'{mode} addressing' if mode in ('zpg', 'zpx', 'zpy', 'inx', 'iny', 'ind')
                   else None)
               or ('an OS ROM read' if mode in ('abs', 'abx', 'aby') and arg >= 0xC000
                   and not 0xD000 <= arg < 0xD800 and mnem not in ('STA', 'STX', 'STY', 'JMP')
                   else None))
        if why:
            bad.append(f'${pc:04X} {mnem} ${arg:04X}: {why}')
        n += 1
        pc += size
    print(f'stage B: {n} instructions, ${lab["SBBEG"]:04X}-${lab["SBEND"] - 1:04X}: '
          f'{"PASS" if not bad else "FAIL"}')
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
    if '--static' in args:
        sys.exit(1 if static() else 0)
    if '--layout' in args:
        n = layout((BUILD / 'diag-cart-8mbit.bin').read_bytes(), 'diag-cart-8mbit.bin')
        n += layout((BUILD / 'diag-cart.car').read_bytes()[16:], 'diag-cart.car')
        sys.exit(1 if n else 0)
    old42()
    sys.exit(1 if carttest.run(CHECKS, args, step=0.5) else 0)


if __name__ == '__main__':
    main()
