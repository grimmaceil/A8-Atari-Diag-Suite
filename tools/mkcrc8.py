#!/usr/bin/env python3
"""The dead test's checksum tables, made once and committed (no ROM image
goes in git, only these numbers):

  python tools/mkcrc8.py ROMDIR

  src/deadtest/crc32tab.asm   the CRC32 table (reflected, $EDB88320) as four
                              256-byte columns, for stage A's CRC32 of the
                              OS chips with a good RAM page (pure arithmetic)
  src/deadtest/romcrc8.asm    the dead test's CRC-8 (polynomial $07, init 0,
                              crc = table[crc EOR byte]) of each known OS
                              chip, for the case with no RAM at all, and
                              its table

The CRC-8 runs in the order the dead test reads with no RAM: one X loop of
256, the chip's pages inside it (byte X of every page, then X+1). The
XL/XE image leaves out $D000-$D7FF (the self-test ROM, reachable only by
PORTB, whose direction register then holds a RAM result). Each range also
gets the CRC-8 of a floating bus (every byte its own page number): a chip
that isn't there. ROMDIR: the OS ROM files (Mike's _sysroms); each known
chip is matched by its CRC32 against test 1's table (src/common/romtab.asm).
"""
import re
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RANGES = {                      # label: pages, in the order the dead test reads them
    'D8': list(range(0xD8, 0xE0)),
    'E0': list(range(0xE0, 0xF0)),
    'F0': list(range(0xF0, 0x100)),
    'XL': list(range(0xC0, 0xD0)) + list(range(0xD8, 0x100)),
    'C0': [0xC0],               # an XL/XE has ROM here; a 400/800 nothing
}


def crc8tab():
    t = []
    for i in range(256):
        c = i
        for _ in range(8):
            c = (c << 1 ^ 0x07 if c & 0x80 else c << 1) & 0xFF
        t.append(c)
    return t


T8 = crc8tab()


def crc8(read, pages):
    c = 0
    for x in range(256):
        for p in pages:
            c = T8[c ^ read(p * 256 + x)]
    return c


def known():
    """test 1's table: CRC32 -> (table, name number)."""
    src = (ROOT / 'src' / 'common' / 'romtab.asm').read_text(encoding='latin-1')
    out, tab = {}, None
    for line in src.splitlines():
        m = re.match(r'(tab_\w+)', line)
        if m:
            tab = m.group(1)
        m = re.search(r'\.dword \$([0-9A-F]{8})', line)
        if m:
            out[int(m.group(1), 16)] = tab
    return out


def main():
    romdir = Path(sys.argv[1])
    tabs = known()
    found = {k: [] for k in ('D8', 'E0', 'F0', 'XL')}
    for f in sorted(romdir.glob('*OS*.rom')):
        img = f.read_bytes()
        base = 0x10000 - len(img)
        read = lambda a: img[a - base]
        if len(img) == 0x2800:          # 400/800: three chips
            for k, lo, n in (('D8', 0xD800, 0x800), ('E0', 0xE000, 0x1000), ('F0', 0xF000, 0x1000)):
                c32 = zlib.crc32(img[lo - base:lo - base + n])
                if c32 in tabs:
                    found[k].append((crc8(read, RANGES[k]), c32, f.name))
        elif len(img) == 0x4000:        # XL/XE: the whole image's CRC32 names it
            c32 = zlib.crc32(img)
            if c32 in tabs:
                found['XL'].append((crc8(read, RANGES['XL']), c32, f.name))
    lines = ['; made by tools/mkcrc8.py from the OS ROM dumps: do not edit',
             "; The dead test's CRC-8 of each known OS chip (see mkcrc8.py), a",
             '; count then the CRC-8s; and of a floating bus (the chip not there).']
    for k in ('D8', 'E0', 'F0', 'XL'):
        uniq = {}
        for c8, c32, name in found[k]:
            uniq.setdefault(c8, (c32, name))
        lines.append(f'c8_{k.lower()}\tdta {len(uniq)}')
        for c8, (c32, name) in uniq.items():
            lines.append(f'\tdta ${c8:02X}\t\t; CRC32 ${c32:08X}: {name}')
    for k, pages in RANGES.items():
        lines.append(f'C8FL_{k}\t= ${crc8(lambda a: a >> 8, pages):02X}\t; a floating bus')
    lines.append('crc8t\t\t\t; the CRC-8 table')
    for i in range(0, 256, 16):
        lines.append('\tdta ' + ','.join(f'${T8[j]:02X}' for j in range(i, i + 16)))
    (ROOT / 'src' / 'deadtest' / 'romcrc8.asm').write_text('\n'.join(lines) + '\n', encoding='latin-1')

    t32 = []
    for i in range(256):
        c = i
        for _ in range(8):
            c = c >> 1 ^ 0xEDB88320 if c & 1 else c >> 1
        t32.append(c)
    lines = ['; made by tools/mkcrc8.py: do not edit',
             '; The CRC32 table (reflected, polynomial $EDB88320), one column per byte',
             '; of each entry: crc = (crc >> 8) EOR table[(crc EOR byte) AND $FF].']
    for b in range(4):
        lines.append(f'crc32t{b}')
        for i in range(0, 256, 16):
            lines.append('\tdta ' + ','.join(f'${t32[j] >> 8 * b & 0xFF:02X}' for j in range(i, i + 16)))
    (ROOT / 'src' / 'deadtest' / 'crc32tab.asm').write_text('\n'.join(lines) + '\n', encoding='latin-1')
    print({k: len(v) for k, v in found.items()})


if __name__ == '__main__':
    main()
