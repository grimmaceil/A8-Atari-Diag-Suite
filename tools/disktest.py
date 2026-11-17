#!/usr/bin/env python3
"""The boot disk's checks, run in the simulator (tools/sim.py).

  python tools/disktest.py            every check
  python tools/disktest.py stub err   only these

Each check boots a disk image with some simulator options and looks at the
screen (and the border colour) at given times: text that must be there.
A failed check prints the screen it saw. The plumbing checks use a stand-in
piece (tools/disktest/stub.asm); the others the real disk from build/.
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / 'build'
TOOLS = ROOT / 'tools'
sys.path.insert(0, str(TOOLS))


def stub_disk():
    """build/disktest-stub.atr: the real boot, the stub as both RAM pieces."""
    import build
    stub = BUILD / 'disktest-stub'
    build.mads('../tools/disktest', 'stub.asm', stub, {})
    return build.make_disk(BUILD / 'disktest-stub.atr',
                           {'RAM8': Path(f'{stub}.bin'), 'RAM16': Path(f'{stub}.bin')})


def real_disk():
    """build/diag-disk-fast.atr: the boot disk, FAST (no slow patterns)."""
    import build
    return build.build_disk(True)


def sim(image, args, snaps):
    """Run the simulator; {time: screen text} for each snapshot time."""
    out = subprocess.run([sys.executable, str(TOOLS / 'sim.py'), str(image), *args,
                          '--snap', ','.join(str(t) for t in snaps),
                          '--until', str(max(snaps) + 0.5), '--seconds', '9999'],
                         capture_output=True, text=True).stdout
    screens, cur = {}, None
    for line in out.splitlines():
        if line.startswith('--- screen at '):
            cur = float(line.split()[3])
            screens[cur] = line + '\n'
        elif cur is not None:
            screens[cur] += line + '\n'
    return screens, out


# name: (image maker, simulator options, [(time s, text that must be on the
# screen or its header line)])
CHECKS = {
    # the boot loads the RAM piece for this machine and enters it
    'stub': (stub_disk, ['--ram', '0xC000'], [(3, 'COLBK $C8')]),
    'stub8k': (stub_disk, ['--ram', '0x2000'], [(3, 'COLBK $C8')]),
    # a sector that won't read: red, the message, and a key reads it again
    'err': (stub_disk, ['--ram', '0xC000', '--diskerr', '6:2', '--key', '4,6'],
            [(3, 'COLBK $34'), (8, 'COLBK $C8')]),
    # 16K and up: the one-part RAM test, its summary goes on by itself (the
    # third code), to the menu's piece
    'ram16': (real_disk, ['--xl', '--key', '12'],
              [(30, '|LEFT ALONE, IT GOES ON AFTER 3 CODES'), (30, '#diag-disk#'),
               (75, '|DISK ERROR. A KEY TRIES AGAIN')]),
}


def main():
    names = sys.argv[1:] or list(CHECKS)
    bad = 0
    for name in names:
        make, args, want = CHECKS[name]
        image = make()
        screens, out = sim(image, args, [t for t, _ in want])
        miss = [(t, text) for t, text in want if text not in screens.get(float(t), '')]
        print(f'{name}: {"PASS" if not miss else "FAIL"}')
        for t, text in miss:
            bad += 1
            print(f'  at {t} s: no {text!r}; the screen:')
            print(screens.get(float(t)) or out[-2000:])
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
