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
