#!/usr/bin/env python3
"""A cartridge over RAM, and the slot read, in the simulator (tools/sim.py).

  python tools/carttest.py            every check
  python tools/carttest.py rom-dmabus only these

Each check runs a built image (build/) with the real OS ROM and looks at the
screen every 2 s, as disktest.py does: each text must have been seen by its
time ('!text': never seen by then). Event checks count the writes of a value
to a register (the simulator's --events log) between two times.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / 'build'
TOOLS = ROOT / 'tools'
ROMS = Path('//TRUENAS/Media/games/ATARI800/_sysroms')
OS800 = ROMS / 'Atari 400-800 OS rev B NTSC - CRC 0E86D61D.rom'
OSXL = ROMS / 'Atari XL-XE OS rev 2 - 800XL 65XE 130XE - 1983-05-10 - CRC 1F9CD270.rom'
BASIC = ROMS / 'BASIC - Revision A.rom'
LINES_PER_S = 15700
STEP = 2
CART_T = 30                     # s: the 8k RAM tape's results are up by then (13 s)

# name: (image in build/, simulator options ('@BASIC': the BASIC ROM),
#        [(time s, text) | (after s, time s, text) |
#         ('ev', from s, to s, register, value, 'min'|'max', count)])
CHECKS = {
    # test 1 on a 40K 800 with nothing in the slot, the bus reading $00
    # while the screen is on: BASIC NONE, not UNKNOWN (review item 2)
    'rom-dmabus': ('diag-8k-02-rom.cas', ['--ram', '0xA000', '--dmabus', '--auto'],
                   [(38, 'BASIC      NONE'), (38, '!BASIC      unknown')]),
    # a real BASIC cartridge is still read: a 400/800, an XL/XE's slot
    'rom-cart800': ('diag-8k-02-rom.cas', ['--basic', '@BASIC', '--auto'],
                    [(38, 'BASIC      REV A'), (38, 'RAM 40K')]),
    'rom-slotxl': ('diag-8k-02-rom.cas', ['--xl', '--basic', '@BASIC', '--slot', '--auto'],
                   [(38, 'BASIC      REV A'), (38, 'RAM 56K')]),
    'rom-builtin': ('diag-8k-02-rom.cas', ['--xl', '--basic', '@BASIC', '--auto'],
                    [(38, 'BASIC      REV A'), (38, 'RAM 64K')]),

    # the long test on a 130XE whose screen fell back to $7C00 ($2800-$3FFF
    # bad): only the injected B1 fault, no B8 (review item 1). Slow: ~4 min.
    'mem-xe-scr7c': ('diag-16k-memtest.cas', ['--xe', '--stuck', '2800-4000:1:1'],
                     [(198, 'PASSES 1'), (198, 'B1 D0'), (198, '!B8 ')]),
    # the long test on a 16K 600XL (no RAM under the OS): it runs (item 3)
    'mem-600xl': ('diag-16k-memtest.cas', ['--xl', '--ram', '0x4000'],
                  [(60, 'PASSES 1'), (60, '!B4 ')]),

    # the RAM test with a cartridge over RAM (a 48K 800, BASIC in): the
    # warning (nine white clicks) before the test, bank 3 CART IN WAY, the
    # line, and never the green charge (C_GREEN, C_GFLASH)
    'ram8k-cart800': ('diag-8k-01-ram.cas', ['--basic', '@BASIC'],
                      [('ev', 0, 6, 0xD01A, 0x0E, 'min', 9),
                       ('ev', 0, 6, 0xD201, 0x0F, 'min', 9),
                       (CART_T, 'BANK 3 $8000-$BFFF  CART IN WAY'),
                       (CART_T, 'CARTRIDGE IN: $A000-$BFFF NOT TESTED'),
                       ('ev', 0, CART_T, 0xD01A, 0xCC, 'max', 0)]),
    # nothing hidden: no warning, and the RAM passes
    'ram8k-32kcart': ('diag-8k-01-ram.cas', ['--ram', '0x8000', '--basic', '@BASIC'],
                      [('ev', 0, CART_T, 0xD01A, 0x0E, 'max', 0),
                       (CART_T, 'ALL RAM PASSED')]),
    'ram8k-40k': ('diag-8k-01-ram.cas', ['--ram', '0xA000', '--dmabus'],
                  [('ev', 0, CART_T, 0xD01A, 0x0E, 'max', 0),
                   (CART_T, 'ALL RAM PASSED')]),
    'ram8k-builtin': ('diag-8k-01-ram.cas', ['--xl', '--basic', '@BASIC'],
                      [('ev', 0, CART_T, 0xD01A, 0x0E, 'max', 0),
                       (CART_T, 'ALL RAM PASSED')]),
    # the diag cartridge (TRIG3 = 1 while it is in): no warning
    'diagcart': ('diag-cart.car', ['--xl'],
                 [('ev', 0, CART_T, 0xD01A, 0x0E, 'max', 0),
                  (CART_T, '!CART IN WAY')]),
}


def sim(image, args, end):
    """Run the simulator: ({time: screen text}, [(line, reg, value)], stdout)."""
    xl = '--xl' in args or '--xe' in args
    with tempfile.TemporaryDirectory() as tmp:
        ev = Path(tmp) / 'ev.txt'
        cmd = [sys.executable, str(TOOLS / 'sim.py'), str(BUILD / image),
               *[str(BASIC) if x == '@BASIC' else x for x in args],
               '--osrom', str(OSXL if xl else OS800), '--events', str(ev),
               '--snap', ','.join(str(t) for t in range(STEP, end + 1, STEP)),
               '--until', str(end + 0.5), '--seconds', '9999']
        out = subprocess.run(cmd, capture_output=True, text=True).stdout
        events = [tuple(int(x, 16) if i else int(x) for i, x in enumerate(ln.split()))
                  for ln in ev.read_text().splitlines()] if ev.exists() else []
    screens, cur = {}, None
    for line in out.splitlines():
        if line.startswith('--- screen at '):
            cur = float(line.split()[3])
            screens[cur] = line + '\n'
        elif cur is not None:
            screens[cur] += line + '\n'
    return screens, events, out


def main():
    names = sys.argv[1:] or list(CHECKS)
    bad = 0
    for name in names:
        image, args, want = CHECKS[name]
        texts = [w if len(w) == 3 else (0, *w) for w in want if w[0] != 'ev']
        evs = [w for w in want if w[0] == 'ev']
        end = max([t for _, t, _ in texts] + [w[2] for w in evs])
        screens, events, out = sim(image, args, end)
        seen = lambda t0, t, text: any(text in sc for at, sc in screens.items() if t0 < at <= t)
        miss = [f'by {t} s: {"seen" if text.startswith("!") else "never"} {text!r}'
                for t0, t, text in texts
                if (seen(t0, t, text[1:]) if text.startswith('!') else not seen(t0, t, text))]
        for _, t0, t1, reg, val, op, n in evs:
            c = sum(1 for ln, r, v in events
                    if r == reg and v == val and t0 * LINES_PER_S <= ln < t1 * LINES_PER_S)
            if (c < n) if op == 'min' else (c > n):
                miss.append(f'{t0}-{t1} s: ${reg:04X} = ${val:02X} written {c} times '
                            f'({op} {n})')
        print(f'{name}: {"PASS" if not miss else "FAIL"}')
        for m in miss:
            bad += 1
            print(' ', m)
        if miss:
            last = max(screens, default=None)
            print(screens.get(last) or out[-2000:])
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
