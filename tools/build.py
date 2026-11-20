#!/usr/bin/env python3
"""Build the diag tapes, the disks and the cartridge: assemble with MADS,
wrap as .cas (mkcas.py), .atr (mkatr.py: build_disk, build_diskset, and
build_bascrc for BASCRC's) and .car (mkcar.py, CAR), optionally deploy.

  python tools/build.py                 normal tapes into build/
  python tools/build.py --fault 2,5     also tapes with an injected fault
                                        (0 = low RAM, 4 = under the XL OS,
                                        5-8 = 130XE, 9 = loader area)
  python tools/build.py --fault 2,5,3   ... only every 3rd burn-in pass
  python tools/build.py --fast          skip the slow test patterns
  python tools/build.py --nodeploy      don't copy the tapes to the MiSTer share
                                        (by default every build copies the
                                        release tapes there that changed)
"""
import argparse
import re
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
MADS = ROOT / 'tools' / 'bin' / 'mads.exe'
BUILD = ROOT / 'build'          # everything the assembler makes (not in git)
CASSETTES = ROOT / 'cassettes'  # the release tapes (in git): what users load
DISKS = ROOT / 'disks'          # the release disks (.atr, in git): the boot disk, the 16k memtest's, BASCRC's
DISKSET = ROOT / 'disk-set'     # the disk set (.atr, in git): the 8k tapes as disks
CARTS = ROOT / 'carts'          # the release cartridge (.car, in git)
SHARE = Path('//TRUENAS/Media/games/ATARI800/_diag')   # the tapes, in the MiSTer Atari800 core's folder
# The version: in every release file's name (diag-...-v0.8.cas) and at the
# right of every screen's title bar, so a file and what it shows can be
# matched. One digit before the point, one or two after, and a patch level
# (one digit after a second point) when there is one (screen.asm).
# build/ keeps the plain names.
VERSION = '0.15'
VDEFS = dict(zip(('VMAJ', 'VMIN', 'VPAT'), VERSION.split('.') + ['0']))

# Each tape: source dir, name, stages (first = boot), defines. A later stage
# is told where the boot stage keeps its BSS and where its own test area ends.
# The system tapes are one main.asm with the tests picked by WANT_* defines.
# The 8k and 16k sets share tape 1: its stage 2 (16K and up) relocates the
# RAM test to the RAM stage 1 sat in, and tests the XL/XE extras where it
# finds them. The one-load 16k and 32k+ RAM tapes are built by build_one16
# and build_one32.
ALL7 = dict(WANT_ROM=1, WANT_KB=1, WANT_CON=1, WANT_JOY=1, WANT_PAD=1,
            WANT_POK=1, WANT_GTIA=1)
S8 = {'SETNO': 0}
# NEEDPG: the RAM a tape needs, in pages. Below it the tape halts at once
# (boot.asm): red border, the low tone on and off. Every tape runs on any
# machine with at least that much RAM, the bigger and newer ones included.
# The 8k set needs 8K, which every Atari has, so it has no check.
N16 = {'NEEDPG': '$40'}
TAPES = [('tape1', 'diag-8k-01-ram', ['main.asm', 'stage2.asm'], {'NORAMK': 1}),  # (FOUND: main RAM)
         ('system', 'diag-8k-02-rom', ['main.asm'], dict(S8, TAPENO=2, WANT_ROM=1)),
         ('system', 'diag-8k-03-input', ['main.asm'],
          dict(S8, TAPENO=3, WANT_KB=1, WANT_CON=1)),
         ('system', 'diag-8k-04-ports', ['main.asm'],
          dict(S8, TAPENO=4, WANT_JOY=1, WANT_PAD=1)),
         ('system', 'diag-8k-05-sound', ['main.asm'], dict(S8, TAPENO=5, WANT_POK=1)),
         ('system', 'diag-8k-06-video', ['main.asm'], dict(S8, TAPENO=6, WANT_GTIA=1)),
         ('one16', 'diag-16k-01-ram', [], N16),
         ('system', 'diag-16k-02-system', ['main.asm'],
          dict(ALL7, **N16, SETNO=1, TAPENO=2, MENU=1, BIGSTAGE=1)),
         ('system', 'diag-16k-03-hello', ['main.asm'],     # the sampled sound: too big
          dict(N16, SETNO=1, TAPENO=3, WANT_POK=1, HELLO16=1, BIGSTAGE=1)),   # for 8K
         ('one32', 'diag-32k-xl-xe', [], {'NEEDPG': '$80'}),
         ('system', 'diag-controls', ['main.asm'],
          dict(N16, SETNO=3, WANT_KB=1, WANT_JOY=1, WANT_PAD=1, BIGSTAGE=1)),
         ('tape2', 'diag-8k-memtest', ['main.asm'], {'OWNTEST': 1, 'NOXL': 1, 'NORAMK': 1, 'NOFONT': 1,
                                                  'FIREONLY': 1, 'NOSHORT': 1}),   # (8K: no room)
         ('bounce', 'diag-16k-memtest', [], dict(N16, BOUNCE=1, BIGSTAGE=1, OWNTEST=1))]
# The long memory test as the cartridge and the boot disk carry it (with
# CART: no NEEDPG, its own title bar), as diag-16k-memtest's defines.
MEMDEFS = dict(BOUNCE=1, BIGSTAGE=1, OWNTEST=1)
# The cartridge (mkcar.py, src/cart/romsum.asm): the tests run from ROM,
# one program to an 8K bank (build_car), and need 8K of RAM. Only the long
# memory test is copied to RAM, as it tests the RAM under the cartridge too.
CAR = 'diag-cart'
CAR8M = 'diag-cart-8mbit'       # the same on the 8 Mbit MaxFlash: a raw 1 MB .bin
CARMEMBK = 3                    # the memory test's image: from this bank on
CARDATAPG = 0x1F                # (mkcar.DATAPG)


def hello_pak():
    """The sampled "hello" packed for every format (cart/hello.asm's player
    unpacks it as it plays): build/hello-pak.bin from
    src/cart/audio/hello-15k.bin (tools/mkhello.py), whose samples, 0-30,
    each become a 4-bit step from the one before, the step + 8, two to a
    byte, high first. A step beyond -8..7 is cut there and made up on the
    next samples (35 of 7424 come out off, by at most 5). Steps of 0 pad it
    to whole pages. Half the size: 15 pages, not 29."""
    out = BUILD / 'hello-pak.bin'
    lev, nib = 0, []
    for s in (ROOT / 'src' / 'cart' / 'audio' / 'hello-15k.bin').read_bytes():
        step = max(-8, min(7, s - lev))
        lev += step
        nib.append(step + 8)
    nib += [8] * (-len(nib) % 512)
    out.write_bytes(bytes(nib[i] << 4 | nib[i + 1] for i in range(0, len(nib), 2)))
    return out


def mads(src, asm, out, defines):
    args = [str(MADS), asm, f'-o:{out}.bin', f'-l:{out}.lst', f'-t:{out}.lab']
    args += [f'-d:{k}={v}' for k, v in dict(VDEFS, **defines).items()]
    r = subprocess.run(args, cwd=ROOT / 'src' / src, capture_output=True, text=True)
    if r.returncode:
        sys.exit(f'{src}/{asm}:\n' + r.stdout + r.stderr)


def labels(path):
    lab = {}
    for line in open(path, encoding='latin-1'):
        p = line.split()
        if len(p) == 3 and len(p[1]) == 4:
            lab[p[2].upper()] = int(p[1], 16)
    return lab


def gen_shlib(lab_path):
    """The library's addresses for the later parts of a one-load image
    (src/common/lib.asm, SHLIB): every label in stage 1's table between
    LIBBEG and LIBEND, without the macro-made ones, as build/shlib.asm."""
    lab = labels(lab_path)
    lo, hi = lab['LIBBEG'], lab['LIBEND']
    names = [(n, a) for n, a in sorted(lab.items())   # (a branch label inside a
             if lo <= a < hi and '.' not in n          # routine, "mu_by", stays
             and not re.match(r'[A-Z]{2}\d?_', n)      # inside: another part may
             and n not in ('LIBBEG', 'LIBEND')]         # use the same name)
    (BUILD / 'shlib.asm').write_text(
        '; build.py: the library in stage 1 (src/common/lib.asm)\n'
        + ''.join(f'{n}\t= ${a:04X}\n' for n, a in names))
    return hi - lo


def build(src, name, stages, defines, label):
    out = BUILD / name
    mads(src, stages[0], out, defines)
    s1 = labels(f'{out}.lab')
    prev, nexts = s1, []
    for k, asm in enumerate(stages[1:], 2):
        # 'dir/file.asm' takes a stage from another source dir. PREVBSS: the
        # stage before, whose results it takes over.
        sdir, sasm = asm.split('/') if '/' in asm else (src, asm)
        d = dict(defines, S1BSS=f"${s1['BSS']:04X}", S1TSTART=f"${s1['TSTART']:02X}",
                 PREVBSS=f"${prev['BSS']:04X}")
        mads(sdir, sasm, Path(f'{out}.s{k}'), d)
        prev = labels(f'{out}.s{k}.lab')
        nexts += ['--next', f'{out}.s{k}.bin']
    subprocess.run([sys.executable, str(ROOT / 'tools' / 'mkcas.py'), f'{out}.cas',
                    '--boot', f'{out}.bin', f'{out}.lab', *nexts, '--name', label],
                   check=True)
    return [Path(f'{out}.cas')] + [Path(f'{out}-part{k}.cas')
                                   for k in range(2, len(stages) + 1)]


def build_bounce(name, defines, label, img=False):
    """The 16K+ burn-in: tape 2 with BOUNCE. Its relocation bitmap marks the
    bytes that hold its own page numbers: assembled at $0800 and at $0C00,
    those bytes differ by exactly 4 (4 pages, not 1: the screen block is
    found on a 1K boundary, so values made from it only move in steps of 4,
    which is why BOFF is a multiple of 4 too). BOFF, the distance to copy B, is a
    whole number of 1K blocks just past copy A's screen block. Checked: copy
    A patched by the bitmap must equal the stage assembled at B's address."""
    out = BUILD / name
    bmap = BUILD / 'bounce.bmap'
    tmp = Path(f'{out}.reloc')
    def asm(load, boff, path):
        mads('tape2', 'main.asm', path, dict(defines, BLOAD=f'${load:04X}', BOFF=f'${boff:02X}'))
        return Path(f'{path}.bin').read_bytes(), labels(f'{path}.lab')
    bmap.write_bytes(bytes(1))
    _, lab = asm(0x0800, 0x1C, out)
    nrel = lab['BMAP'] - 0x0800                  # bytes the bitmap covers
    bmap.write_bytes(bytes((nrel + 7) // 8))
    _, lab = asm(0x0800, 0x1C, out)
    boff = (lab['SCR1'] + 4 - 0x08 + 3) & ~3
    a0, lab = asm(0x0800, boff, out)
    a1, _ = asm(0x0C00, boff, tmp)
    assert lab['BMAP'] - 0x0800 == nrel and len(a0) == len(a1)
    bits = bytearray((nrel + 7) // 8)
    for i in range(nrel):
        d = (a1[i] - a0[i]) & 0xFF
        if d not in (0, 4):
            sys.exit(f'build_bounce: byte ${0x0800 + i:04X} moves by {d}, not 0 or 4')
        if d:
            bits[i >> 3] |= 1 << (i & 7)
    assert a0[nrel:] == a1[nrel:-2] + a0[-2:] or a0[nrel:-2] == a1[nrel:-2]
    bmap.write_bytes(bytes(bits))
    a0, lab = asm(0x0800, boff, out)             # the real one, with the bitmap
    for off in (boff, lab['BOFFXL']):            # both places copy B can go
        b0, _ = asm(0x0800 + off * 256, boff, tmp)   # as the assembler sees it
        patched = bytes((v + off) & 0xFF if bits[i >> 3] >> (i & 7) & 1 else v
                        for i, v in enumerate(a0[:nrel])) + a0[nrel:]
        if patched[:-2] != b0[:-2]:
            bad = next(i for i in range(len(b0) - 2) if patched[i] != b0[i])
            sys.exit(f'build_bounce: copy B ({off:#04x} pages up) differs at ${bad:04X}')
    print(f'{name}: copy A $0800-${lab["BSS"] - 1:04X}, copy B {boff:#04x} pages up, '
          f'{sum(bin(x).count("1") for x in bits)} relocated bytes')
    return wrap(out, label, img)


def build_one16(name, defines, label, disk=False):
    """The one-load 16k RAM tape: tape 1's stage 1 (ONE16) with stage 2
    inserted at PAYAT, built to run there. Stage 1's BSS and TSTART depend
    on stage 2's size, and stage 2 on those, but no size depends on an
    address: two rounds settle it."""
    out = BUILD / name
    s2, pay = Path(f'{out}.s2'), BUILD / 'payload16.bin'
    pay.write_bytes(bytes(0x1000))
    d1 = dict(defines, ONE16=1)
    mads('tape1', 'main.asm', out, d1)
    s1 = labels(f'{out}.lab')
    for _ in range(4):
        gen_shlib(f'{out}.lab')
        d2 = dict(defines, ONE16=1, S2AT=f"${s1['PAYAT']:04X}", S1AGAIN=f"${s1['AGAIN']:04X}",
                  S1BSS=f"${s1['BSS']:04X}", S1TSTART=f"${s1['TSTART']:02X}")
        mads('tape1', 'stage2.asm', s2, d2)
        pay.write_bytes(Path(f'{s2}.bin').read_bytes())
        mads('tape1', 'main.asm', out, d1)
        new = labels(f'{out}.lab')
        if all(new[k] == s1[k] for k in ('BSS', 'PAYAT', 'TSTART')):
            break
        s1 = new
    else:
        sys.exit('build_one16: did not settle')
    if disk:                        # a boot disk's piece: just the image
        return Path(f'{out}.bin')
    subprocess.run([sys.executable, str(ROOT / 'tools' / 'mkcas.py'), f'{out}.cas',
                    '--boot', f'{out}.bin', f'{out}.lab', '--name', label], check=True)
    return [Path(f'{out}.cas')]


def build_one32(name, defines, label):
    """The one-load 32k+ tape: tape 1's stage 1 (ONE16, ONE32) with, at
    PAYAT, stage 2 and then the system tests (SYSAT), all three sharing
    stage 1's BSS page. No size depends on an address: a few rounds settle
    the addresses."""
    out = BUILD / name
    s2, sy, pay = Path(f'{out}.s2'), Path(f'{out}.sys'), BUILD / 'payload16.bin'
    pay.write_bytes(bytes(0x4000))
    d1 = dict(defines, ONE16=1, ONE32=1)
    mads('tape1', 'main.asm', out, d1)
    s1 = labels(f'{out}.lab')
    sysat = s1['PAYAT'] + 0x1200
    for _ in range(6):
        gen_shlib(f'{out}.lab')
        common = dict(S1BSS=f"${s1['BSS']:04X}", S1TSTART=f"${s1['TSTART']:02X}",
                      S1AGAIN=f"${s1['AGAIN']:04X}")
        d2 = dict(d1, S2AT=f"${s1['PAYAT']:04X}", SYS32=f'${sysat:04X}', **common)
        mads('tape1', 'stage2.asm', s2, d2)
        b2 = Path(f'{s2}.bin').read_bytes()
        sysat = s1['PAYAT'] + len(b2)
        d2['SYS32'] = f'${sysat:04X}'
        mads('tape1', 'stage2.asm', s2, d2)
        b2 = Path(f'{s2}.bin').read_bytes()
        dsy = dict(ALL7, SETNO=4, MENU=1, CHAIN=1, SYSAT=f'${sysat:04X}',
                   SHAREBSS=f"${s1['BSS']:04X}", RAMAGAIN=f"${s1['AGAIN']:04X}",
                   SELFAT=f"${s1['PAYAT']:04X}",       # the ROM test's self-check:
                   SELFPG=(s1['IMGEND'] - s1['PAYAT']) // 256,  # stage 1's CRCAT on
                   **{k: 1 for k in ('CART',) if k in defines})
        mads('system', 'main.asm', sy, dsy)
        pay.write_bytes(b2 + Path(f'{sy}.bin').read_bytes())
        mads('tape1', 'main.asm', out, d1)
        new = labels(f'{out}.lab')
        if all(new[k] == s1[k] for k in ('BSS', 'PAYAT', 'TSTART', 'IMGEND')):
            break
        s1 = new
    else:
        sys.exit('build_one32: did not settle')
    return wrap(out, label)


def build_car(fast, big=False):
    """The cartridge's three code banks and the memory test's image.
    Bank 0, the RAM test: tape 1's stage 1 with stage 2 in the same image,
    as build_one16, but assembled for ROM at $A000. Banks 1 and 2: the
    system tests, three and four of them, each with the menu.
    big: the 8 Mbit MaxFlash (CART8M: its off switch is $D580), as the raw
    1 MB image its flasher writes; the .car (type 75) stays in build/."""
    f = {'FAST': 1} if fast else {}
    pre, c8 = ('cart8m', {'CART8M': 1}) if big else ('cart', {})
    me = build_bounce('diag-memtest-cart', dict(MEMDEFS, CART=1, **f), '', img=True)
    mempg = -(-len(me[0].read_bytes()) // 256)
    if CARMEMBK + -(-mempg // CARDATAPG) > 16:
        sys.exit('build_car: the memory test does not fit')
    out = BUILD / f'{pre}-ram'
    s2, pay = Path(f'{out}.s2'), BUILD / 'payload16.bin'
    pay.write_bytes(bytes(0x100))
    d1 = dict(f, ONE16=1, ROM=1, SYSA=1, **c8)
    mads('tape1', 'main.asm', out, d1)
    s1 = labels(f'{out}.lab')
    for _ in range(4):
        gen_shlib(f'{out}.lab')
        d2 = dict(d1, S2AT=f"${s1['PAYAT']:04X}", S1AGAIN=f"${s1['AGAIN']:04X}",
                  S1BSS=f"${s1['BSS']:04X}", S1TSTART=f"${s1['TSTART']:02X}")
        mads('tape1', 'stage2.asm', s2, d2)
        pay.write_bytes(Path(f'{s2}.bin').read_bytes())
        mads('tape1', 'main.asm', out, d1)
        new = labels(f'{out}.lab')
        if new['PAYAT'] == s1['PAYAT']:
            break
        s1 = new
    else:
        sys.exit('build_car: did not settle')
    hello = hello_pak()
    hellopg = len(hello.read_bytes()) // 256
    hellobk = CARMEMBK + -(-mempg // CARDATAPG)                  # after the memory test
    common = dict(f, **c8, ROM=1, MENU=1, SETNO=0, TAPENO=0, MEMBK=CARMEMBK, MEMPG=mempg,
                  DATAPG=CARDATAPG, HELLOBK=hellobk, HELLOPG=hellopg,
                  CODEBK=3)                  # (the ROM test's self-check: banks 0-2)
    mads('system', 'main.asm', BUILD / f'{pre}-sysa',
         dict(common, WANT_ROM=1, WANT_KB=1, WANT_CON=1, OTHER=2))
    mads('system', 'main.asm', BUILD / f'{pre}-sysb',
         dict(common, WANT_JOY=1, WANT_PAD=1, WANT_POK=1, WANT_GTIA=1, OTHER=1, HASLDR=1))
    car = BUILD / (f'{CAR8M}.car' if big else f'{CAR}.car')
    raw = BUILD / f'{CAR8M}.bin'
    deadbk = hellobk + 1                  # the dead test: after the "hello"
    subprocess.run([sys.executable, str(ROOT / 'tools' / 'mkcar.py'), str(car),
                    *[x for b in ('ram', 'sysa', 'sysb')
                      for x in ('--bank', str(BUILD / f'{pre}-{b}.bin'))],
                    '--mem', *map(str, me), '--data', str(hello), '--data-at', str(hellobk),
                    *[x for d in build_dead(fast, deadbk) for x in ('--deadbank', str(d))],
                    '--dead-at', str(deadbk),
                    *(['--raw8m', str(raw)] if big else [])],
                   check=True)
    return raw if big else car


DEADN = 4                       # the dead test's banks: start + stage B, the show,
                                # stage A, the other chips (the words: 8 Mbit, later)


def build_dead(fast, deadbk=5, std=False):
    """The dead test (src/deadtest/main.asm), once per bank: build/dead<N>.bin
    for banks deadbk on, or with std the standalone 8K (build/deadstd.bin).
    The font first (tools/mkfont.py)."""
    subprocess.run([sys.executable, str(ROOT / 'tools' / 'mkfont.py'),
                    str(ROOT / 'src' / 'deadtest' / 'font.txt'), str(BUILD / 'dtfont.bin')],
                   check=True)
    subprocess.run([sys.executable, str(ROOT / 'tools' / 'mkdtext.py'),
                    str(ROOT / 'src' / 'deadtest' / 'text.txt'), str(BUILD / 'dtext.asm')],
                   check=True)
    f = {'FAST': 1} if fast else {}
    if std:
        out = BUILD / 'deadstd'
        mads('deadtest', 'main.asm', out, dict(f, DTBANK=0, DEADBK=0, STANDALONE=1))
        return [Path(f'{out}.bin')]
    outs = []
    for n in range(deadbk, deadbk + DEADN):
        out = BUILD / f'dead{n}'
        mads('deadtest', 'main.asm', out, dict(f, DTBANK=n, DEADBK=deadbk))
        outs.append(Path(f'{out}.bin'))
    return outs


def build_deadstd(fast):
    """The standalone dead test: build/diag-deadtest.car (type 1) and .rom."""
    car, rom = BUILD / 'diag-deadtest.car', BUILD / 'diag-deadtest.rom'
    subprocess.run([sys.executable, str(ROOT / 'tools' / 'mkcar.py'), str(car),
                    '--std8k', str(rom), '--deadbank', str(build_dead(fast, std=True)[0])],
                   check=True)
    return [car, rom]


def build_disk(fast, out=None):
    """The boot disk (Atari-diag-boot-disk-scope.md): every piece built, laid
    out (build/disktab.asm, which every piece includes: its size is fixed,
    so a second round settles it), summed, and written as an .atr."""
    import mkatr
    out = out or BUILD / ('diag-disk-fast.atr' if fast else 'diag-disk.atr')
    f = {'FAST': 1} if fast else {}
    hello = hello_pak()
    sysd = dict(f, DISK=1, MENU=1, SETNO=0, TAPENO=0, HELLOPG=len(hello.read_bytes()) // 256)
    def system(name, **want):
        mads('system', 'main.asm', BUILD / f'disk-{name.lower()}', dict(sysd, **want))
        return BUILD / f'disk-{name.lower()}.bin'
    def pieces():
        mads('tape1', 'main.asm', BUILD / 'disk-ram8', dict(f, DISK=1, NORAMK=1))
        return {'RAM8': BUILD / 'disk-ram8.bin',
                'RAM16': build_one16('disk-ram16', dict(f, DISK=1), '', disk=True),
                'MENU': system('MENU', MENUPC=1),
                'ROM': system('ROM', WANT_ROM=1),
                'INPUT': system('INPUT', WANT_KB=1, WANT_CON=1),
                'PORTS': system('PORTS', WANT_JOY=1, WANT_PAD=1),
                'SOUND': system('SOUND', WANT_POK=1),
                'VIDEO': system('VIDEO', WANT_GTIA=1),
                'HELLO': hello,
                'MEM': build_bounce('disk-mem', dict(MEMDEFS, CART=1, DISK=1, **f),
                                    '', img=True)[0]}
    tabf = BUILD / 'disktab.asm'
    tabf.write_text(mkatr.disktab(mkatr.layout({})))
    first = {n: b.read_bytes() for n, b in pieces().items()}
    tabf.write_text(mkatr.disktab(mkatr.layout(first)))
    bins = pieces()
    for n, b in bins.items():
        if len(b.read_bytes()) != len(first[n]):
            sys.exit(f'build_disk: {n} changed size with the real layout')
        if n != 'HELLO':
            mkatr.patch_piece(b, b.with_suffix('.lab'))
    return make_disk(out, bins)


def make_disk(out, bins):
    """The boot disk from finished pieces ({name: .bin}, tools/mkatr.py's
    PIECES names): their layout into build/disktab.asm, the boot (which
    includes it), then the .atr."""
    import mkatr
    pieces = {n: Path(b).read_bytes() for n, b in bins.items()}
    tab = mkatr.layout(pieces)
    (BUILD / 'disktab.asm').write_text(mkatr.disktab(tab))
    mads('disk', 'boot.asm', BUILD / 'disk-boot', {})
    mkatr.atr(out, (BUILD / 'disk-boot.bin').read_bytes(), pieces, tab)
    return Path(out)


def build_diskset(fast):
    """The disk set (disk-set/): the 8k tapes as disks, for when the boot
    disk can't help (its menu and loader need more of the machine). Each
    disk is named as its tape and holds the tape's own program, byte for
    byte (mkatr.cas_image), so its title bar and its NEXT line name the
    disk to load next. The OS boots it from sector 1 as from tape, except:
      - diag-8k-01-ram: part 1 built with DSKLD (loader.asm: part 2 from the
        disk, by itself on 16K and up), then part 2;
      - diag-8k-05-sound and diag-8k-memtest: a boot (src/disk/setboot.asm)
        that picks by the RAM: under 16K the tape's program, 16K and up the
        sound test with the sampled "hello" (HELLO16: the recording in the
        image) or diag-16k-memtest's.
    Also the 16k memtest's own disk, for disks/. Needs the tapes built.
    Returns (the disk set, the 16k memtest disk)."""
    import mkatr
    tape = lambda n: mkatr.cas_image(BUILD / f'{n}.cas')
    f = {'FAST': 1} if fast else {}     # (as the tapes it goes with)
    out = []
    for n in ('diag-8k-02-rom', 'diag-8k-03-input', 'diag-8k-04-ports', 'diag-8k-06-video'):
        mkatr.plain(BUILD / f'{n}.atr', [tape(n)])
        out.append(BUILD / f'{n}.atr')
    build('tape1', 'dset-ram', ['main.asm', 'stage2.asm'], dict(f, NORAMK=1, DSKLD=1), '')
    s2 = tape('dset-ram-part2')
    if s2 != tape('diag-8k-01-ram-part2'):
        sys.exit("build_diskset: the RAM disk's part 2 isn't the tape's")
    mkatr.plain(BUILD / 'diag-8k-01-ram.atr', [tape('dset-ram'), s2])
    out.insert(0, BUILD / 'diag-8k-01-ram.atr')
    build('system', 'dset-sound16', ['main.asm'],
          dict(f, **N16, SETNO=0, TAPENO=5, WANT_POK=1, HELLO16=1, BIGSTAGE=1), '')
    for n, big in (('diag-8k-05-sound', 'dset-sound16'), ('diag-8k-memtest', 'diag-16k-memtest')):
        imgs = [tape(n), tape(big)]
        (BUILD / 'settab.asm').write_text(mkatr.settab(imgs))
        mads('disk', 'setboot.asm', BUILD / 'dset-boot', {})
        mkatr.choice(BUILD / f'{n}.atr', (BUILD / 'dset-boot.bin').read_bytes(), imgs)
        out.append(BUILD / f'{n}.atr')
    mkatr.plain(BUILD / 'diag-16k-memtest.atr', [tape('diag-16k-memtest')])
    return out, BUILD / 'diag-16k-memtest.atr'


def build_bascrc(lst):
    """BASCRC's disk (mkatr.dos2): it boots to the check in machine code
    (src/basic/bascrc.asm with BOOT), and holds it as a DOS file too, with
    the BASIC listing (lst, mkbasic.py's): BASCRC.XEX, for L from DOS 2,
    and BASCRC.LST, for ENTER "D:BASCRC.LST"."""
    import mkatr
    bx, bb = BUILD / 'diag-bascrc', BUILD / 'bascrc-boot'
    mads('basic', 'bascrc.asm', bx, {})
    mads('basic', 'bascrc.asm', bb, {'BOOT': 1})
    out = BUILD / 'diag-bascrc.atr'
    mkatr.dos2(out, Path(f'{bb}.bin').read_bytes(),
               [('BASCRC.XEX', Path(f'{bx}.bin').read_bytes()), ('BASCRC.LST', lst.read_bytes())])
    return out


def wrap(out, label, img=False):
    """The boot image as a tape; img: just the image (.bin, .lab), for
    mkcar.py and the boot disk."""
    if img:
        return [Path(f'{out}.bin'), Path(f'{out}.lab')]
    subprocess.run([sys.executable, str(ROOT / 'tools' / 'mkcas.py'), f'{out}.cas',
                    '--boot', f'{out}.bin', f'{out}.lab', '--name', label], check=True)
    return [Path(f'{out}.cas')]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--fault', help='BANK,BIT[,EVERY]  (bank 0 = low RAM; EVERY: burn-in '
                    'only, inject every n-th pass)')
    ap.add_argument('--fast', action='store_true')
    ap.add_argument('--nodeploy', action='store_true')
    a = ap.parse_args()

    BUILD.mkdir(exist_ok=True)
    hello_pak()                         # (the tapes' hello.asm includes it)
    cas = []
    for src, name, stages, defs in TAPES:
        d = dict(defs, FAST=1) if a.fast else dict(defs)
        if src == 'one32':
            cas += build_one32(name, d, f'A8 {name.upper()}')
            continue
        if src == 'one16':
            cas += build_one16(name, d, f'A8 {name.upper()}')
            continue
        if src == 'bounce':
            cas += build_bounce(name, d, f'A8 {name.upper()}')
            continue
        cas += build(src, name, stages, d, f'A8 {name.upper()}')
        if a.fault:
            bank, bit, *every = a.fault.split(',')
            fd = dict(d, FAULT_BANK=bank, FAULT_BIT=bit)
            tag = f'b{bank}-d{bit}'
            if every:
                if src != 'tape2':
                    continue        # only the burn-in has passes
                fd['FAULT_EVERY'] = every[0]
                tag += f'-e{every[0]}'
            cas += build(src, f'{name}-FAULT-{tag}', stages, fd,
                         f'A8 {name.upper()} FAULT {tag}')
    car = build_car(a.fast)
    car8m = build_car(a.fast, big=True)
    dstd = build_deadstd(a.fast)        # the standalone dead test (.car, .rom)
    atr = build_disk(a.fast)            # the boot disk (Atari-diag-boot-disk-scope.md)
    dset, memdisk = build_diskset(a.fast)     # the 8k tapes as disks, and the 16k memtest's
    # BASCRC, the BASIC cartridge check: the BASIC program as a tape for
    # ENTER "C:", and a disk that boots to it in machine code and holds the
    # listing for ENTER "D:"
    bas, lst = BUILD / 'diag-bascrc.cas', BUILD / 'bascrc.lst'
    subprocess.run([sys.executable, str(ROOT / 'tools' / 'mkbasic.py'),
                    str(ROOT / 'src' / 'basic' / 'bascrc.bas'), str(lst), str(bas)], check=True)
    cas.append(bas)
    bdisk = build_bascrc(lst)
    if a.fast:                      # FAST builds skip test patterns: not for use,
        return                      # so they stay in build/
    rel = []                        # the release files, named with the version
    for folder, files in ((CASSETTES, cas), (DISKS, [atr, memdisk, bdisk]), (DISKSET, dset),
                          (CARTS, [car, car8m, *dstd])):
        folder.mkdir(exist_ok=True)
        for f in files:
            if 'FAULT' in f.name:   # fault-injection builds stay in build/
                continue
            for old in folder.glob(f'{f.stem}-v[0-9]*{f.suffix}'):   # other versions,
                old.unlink()                                         # and the name
            (folder / f.name).unlink(missing_ok=True)                # without one
            dst = folder / f'{f.stem}-v{VERSION}{f.suffix}'
            shutil.copy2(f, dst)
            rel.append(dst)
    if a.nodeploy:
        return
    for c in rel:                   # the release files to the share, for testing
        dst = SHARE / c.name
        try:
            if dst.exists() and dst.read_bytes() == c.read_bytes():
                continue
            shutil.copy2(c, dst)
            print('deployed', dst)
        except OSError as e:        # share offline, or the file in use
            print(f'NOT deployed {c.name}: {e}')


if __name__ == '__main__':
    main()
