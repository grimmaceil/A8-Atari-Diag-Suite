#!/usr/bin/env python3
"""Pack the dead test's font (src/deadtest/font.txt) into the 512 bytes
ANTIC reads: characters 0-63 in Atari's internal order (space to
underscore, ATASCII $20-$5F), 8 bytes each, top row first, bit 7 the
leftmost pixel.

  python tools/mkfont.py src/deadtest/font.txt build/dtfont.bin

font.txt: '#' comment lines; '= c' (or '= space') starts a character,
then its 8 rows of 8 '.' or '#'.
"""
import sys
from pathlib import Path


def pack(text):
    glyphs, cur, name = {}, None, None
    for ln, line in enumerate(text.splitlines(), 1):
        if line.startswith('#') and cur is None or not line.strip():
            continue
        if line.startswith('= '):
            name = line[2:]
            name = ' ' if name == 'space' else name
            if len(name) != 1 or not 0x20 <= ord(name) < 0x60 or name in glyphs:
                sys.exit(f'line {ln}: bad or repeated character {line!r}')
            glyphs[name] = cur = []
            continue
        if cur is None or len(line) != 8 or set(line) - set('.#'):
            sys.exit(f'line {ln}: want 8 of . or #: {line!r}')
        cur.append(int(line.replace('.', '0').replace('#', '1'), 2))
        if len(cur) == 8:
            cur = None
    out = bytearray()
    for code in range(64):
        g = glyphs.get(chr(0x20 + code))
        if g is None or len(g) != 8:
            sys.exit(f'character {chr(0x20 + code)!r} (internal {code}) missing or short')
        out += bytes(g)
    return bytes(out)


def main():
    src, dst = sys.argv[1:3]
    Path(dst).write_bytes(pack(Path(src).read_text(encoding='utf-8')))


if __name__ == '__main__':
    main()
