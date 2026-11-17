#!/usr/bin/env python3
"""The boot disk's checks, run in the simulator (tools/sim.py).

  python tools/disktest.py            every check
  python tools/disktest.py stub err   only these

Each check boots a disk image with some simulator options and looks at the
screen (and the border colour) every 2 s: each text must have been seen by
its time. A failed check prints the last screen before that time. The plumbing checks use a stand-in
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
    # third code), to the menu's piece and the ROM test
    'ram16': (real_disk, ['--xl', '--key', '12'],
              [(30, '|LEFT ALONE, IT GOES ON AFTER 3 CODES'), (30, '#diag-disk#'),
               (75, '#1#roms#')]),
    # power-on: RAM, the menu's piece, the ROM test's piece (the simulator's
    # made-up ROMs fail it), and back to the menu with its result
    'menu': (real_disk, ['--xl', '--auto'], [(110, '|START=RUN'), (110, ' 1 ROMS  ')]),
    # START on each highlighted line in turn, as a person would: each test's
    # piece loads, runs, and the menu comes back with its line set (test 7
    # is Mike's: the walk ends there)
    'walk': (real_disk, ['--xl', '--auto'],
             [(400, ' 2 KEYBOARD         PASS'), (400, ' 3 CONSOLE KEYS     PASS'),
              (400, ' 4 JOYSTICKS        PASS'), (400, ' 5 PADDLES          PASS'),
              (400, ' 6 POKEY            PASS')]),
    # ALL, in order across the pieces: 1 to 6, then test 7's piece (Mike's
    # test: the simulator stops there)
    'all': (real_disk, ['--xl', '--auto', '--menuall'],
            [(400, 'TEST 6 PASS'), (400, '#7#gtia/antic#')]),
    # an 8K 400/800: RAM8, one part (its own RAM page by page), then the
    # menu and a test, with the screen at $1C00, above every piece
    'ram8': (real_disk, ['--ram', '0x2000', '--auto'],
             [(150, '|OWN RAM $0800-$'), (150, 'ALL RAM PASSED'),
              (150, '|LEFT ALONE, IT GOES ON AFTER 3 CODES'),
              (400, ' 2 KEYBOARD         PASS')]),
    # a stuck bit in RAM8's own RAM (the results page: a byte RAM8 doesn't
    # use; one in its code fails the image sum first, as on tape): its line
    # fails, D2, and the code is bank 1
    'ram8bad': (real_disk, ['--ram', '0x2000', '--stuck', '08D7-08D8:3:1'],
                [(150, 'fail:#see#the#code'), (150, 'D2')]),
    # 8 on the menu: the results page, in the ROM test's piece
    'results': (real_disk, ['--xl', '--auto', '--walk', '8'],
                [(150, '|NUMBERS AFTER FAIL = FAILED ITEMS')]),
}


STEP = 2


def main():
    names = sys.argv[1:] or list(CHECKS)
    bad = 0
    for name in names:
        make, args, want = CHECKS[name]
        image = make()
        end = max(t for t, _ in want)
        screens, out = sim(image, args, list(range(STEP, end + 1, STEP)))
        seen = lambda t, text: any(text in sc for at, sc in screens.items() if at <= t)
        miss = [(t, text) for t, text in want if not seen(t, text)]
        print(f'{name}: {"PASS" if not miss else "FAIL"}')
        for t, text in miss:
            bad += 1
            last = max((at for at in screens if at <= t), default=None)
            print(f'  by {t} s: never {text!r}; the screen at {last} s:')
            print(screens.get(last) or out[-2000:])
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
