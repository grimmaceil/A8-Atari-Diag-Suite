#!/usr/bin/env python3
"""The boot disk's checks, run in the simulator (tools/sim.py).

  python tools/disktest.py            every check
  python tools/disktest.py stub err   only these

Each check boots a disk image with some simulator options and looks at the
screen (and the border colour) every 2 s: each text must have been seen by
its time ('!text': never seen by then). A failed check prints the last
screen before that time. The plumbing checks use a stand-in
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
# screen or its header line by then)]; (after s, time s, text): seen between)
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
    # 9 on the menu: the long test's piece; a key stops it, a key at its
    # summary goes back: the start-up again without the RAM test (line 0
    # SKIPPED), the menu
    'mem': (real_disk, ['--xl', '--auto', '--walk', '9', '--key', '150'],
            [(140, 'PASSES '), (400, ' 0 RAM              SKIPPED')]),
    # 8K: test 6 without the "hello" recording (it needs 16K)
    'hello8k': (real_disk, ['--ram', '0x2000', '--auto', '--walk', '6'],
                [(300, 'TEST 6 PASS'), (300, '!HELLO 7 TIMES')]),
    # 8 on the menu: the results page, in the ROM test's piece
    'results': (real_disk, ['--xl', '--auto', '--walk', '8'],
                [(150, '|NUMBERS AFTER FAIL = FAILED ITEMS')]),
    # a joystick button stuck from power-on (a short): it holds nothing up,
    # the keys still go on from the ROM test's result to the menu
    'stuckfire': (real_disk, ['--xl', '--auto', '--joy', 'FIRE:0:9999'],
                  [(110, '|START=RUN'), (110, ' 1 ROMS  ')]),
    # the stick as the console keys on a result screen too: up = OPTION,
    # the full-screen flashes (the ROM test's result waits from ~75 s)
    'stickup': (real_disk, ['--xl', '--key', '12', '--joy', 'UP:85:0.5'],
                [(80, '#1#roms#'), (85, 90, '(ANTIC DMA off)')]),
}


STEP = 2


def main():
    names = sys.argv[1:] or list(CHECKS)
    bad = 0
    for name in names:
        make, args, want = CHECKS[name]
        want = [w if len(w) == 3 else (0, *w) for w in want]   # (after, by, text)
        image = make()
        end = max(t for _, t, _ in want)
        screens, out = sim(image, args, list(range(STEP, end + 1, STEP)))
        seen = lambda t0, t, text: any(text in sc for at, sc in screens.items() if t0 < at <= t)
        miss = [(t, text) for t0, t, text in want
                if (seen(t0, t, text[1:]) if text.startswith('!') else not seen(t0, t, text))]
        mute = [ln for ln in out.splitlines() if ln.startswith('POKEY: voice')]
        print(f'{name}: {"PASS" if not miss and not mute else "FAIL"}')
        for ln in mute:                  # a voice the hardware would keep silent
            bad += 1
            print(' ', ln)
        for t, text in miss:
            bad += 1
            last = max((at for at in screens if at <= t), default=None)
            print(f'  by {t} s: {"seen" if text.startswith("!") else "never"} {text!r}; '
                  f'the screen at {last} s:')
            print(screens.get(last) or out[-2000:])
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
