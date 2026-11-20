#!/usr/bin/env python3
"""The dead test's screen lines (src/deadtest/text.txt) as MADS source:

  python tools/mkdtext.py src/deadtest/text.txt build/dtext.asm

For each line: 40 bytes of screen codes (dta d'...', padded with blanks)
and a display-list fragment, DT_<NAME>_<VARIANT> (or DT_<NAME> for the
variant '-'): $42 (mode 2, LMS) and the line's address. The show bank
points ANTIC at one fragment per row (show.asm); ANTIC's display-list
counter only counts within 1K, so the fragments are aligned to 4 (a 3-byte
fragment never crosses a 1K boundary), and its memory-scan counter only
within 4K, so no line crosses a 4K boundary.
"""
import sys
from pathlib import Path


def lines(text):
    out = []
    for ln, line in enumerate(text.splitlines(), 1):
        if not line.strip() or line.startswith('#'):
            continue
        name, variant, *rest = line.split(None, 2)
        body = rest[0].rstrip() if rest else ''
        if len(body) > 40:
            sys.exit(f'line {ln}: {len(body)} columns, a line holds 40')
        if any(not 0x20 <= ord(c) < 0x60 for c in body):
            sys.exit(f'line {ln}: only space to underscore (the font\'s 64 characters)')
        label = f'DT_{name}' if variant == '-' else f'DT_{name}_{variant}'
        out.append((label, body))
    return out


def asm(entries):
    src = ['; made by tools/mkdtext.py from src/deadtest/text.txt: do not edit']
    for label, body in entries:
        src += ['\t.if [*&$FFF]+40>$1000', '\t.align $1000', '\t.endif',
                f'{label}_L']
        if body:
            src.append("\tdta d'" + body.replace("'", "''") + "'")
        if 40 - len(body):
            src.append(f'\t:{40 - len(body)} dta 0')
    src.append('\t.align 4')
    for label, _ in entries:
        src += [f'{label}\tdta $42,a({label}_L)', '\tdta 0']
    return '\n'.join(src) + '\n'


def main():
    """--std: without the no-RAM OS lines (OS*: the standalone has no ROM
    phase)."""
    args = [a for a in sys.argv[1:] if a != '--std']
    entries = lines(Path(args[0]).read_text(encoding='utf-8'))
    if '--std' in sys.argv:
        entries = [e for e in entries if not e[0].startswith('DT_OS')]
    Path(args[1]).write_text(asm(entries), encoding='latin-1')


if __name__ == '__main__':
    main()
