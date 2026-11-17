#!/usr/bin/env python3
"""The boot disk (Atari-diag-boot-disk-scope.md): its layout, the pieces'
sums, and the .atr image. Used by build.py (build_disk, make_disk).

Layout: sectors 1-4 the boot, then each piece in a run of whole sectors,
in PIECES order. build/disktab.asm tells every piece where the others are:
first sector, sector count, load page. A piece not on the disk points past
its end, so loading it fails as a disk error does.
"""
import struct
import zlib
from pathlib import Path

import mkcas

PIECES = ['RAM8', 'RAM16', 'MENU', 'ROM', 'INPUT', 'PORTS', 'SOUND', 'VIDEO',
          'HELLO', 'MEM']
SECTORS = 720                    # single density
FIRST = 5                        # after the boot's four
HELLOPG = 0x1C                   # dload.asm's HELLOAT
NOWHERE = SECTORS + 1            # a missing piece: a sector the disk hasn't


def load_page(name, data):
    """A piece's load page: from its tape-style header; HELLO is raw data."""
    if name == 'HELLO':
        return HELLOPG
    assert data[0] == 0 and data[1] * 128 == len(data), f'{name}: not a piece image'
    return data[3]


def layout(pieces):
    """{name: data} -> {name: (first sector, sectors, load page)}."""
    out, sec = {}, FIRST
    for name in PIECES:
        if name not in pieces:
            out[name] = (NOWHERE, 1, 0x09)
            continue
        n = -(-len(pieces[name]) // 128)
        out[name] = (sec, n, load_page(name, pieces[name]))
        sec += n
    if sec - 1 > SECTORS:
        raise SystemExit(f'the disk is full: {sec - 1} sectors of {SECTORS}')
    return out


def disktab(tab):
    """build/disktab.asm's text."""
    col = lambda f: ', '.join(f(tab[n]) for n in PIECES)
    return ('; build.py: where the boot disk keeps its pieces (tools/mkatr.py)\n'
            f'dtsl\t.byte {col(lambda t: f"${t[0] & 0xFF:02X}")}\n'
            f'dtsh\t.byte {col(lambda t: f"${t[0] >> 8:02X}")}\n'
            f'dtcnt\t.byte {col(lambda t: str(t[1]))}\n'
            f'dtpg\t.byte {col(lambda t: f"${t[2]:02X}")}\n')


def patch_piece(bin_path, lab_path):
    """Put a piece's sum in (and CRCFIX, the ROM test's self-check). A RAM
    piece or the long test sums itself as a tape does (boot.asm: mkcas);
    the others with dload.asm's dsum: a plain sum, nothing changes first."""
    lab = mkcas.read_labels(lab_path)
    if 'CK_OP' in lab:
        return mkcas.patch_boot(bin_path, lab_path)[0]
    img = bytearray(Path(bin_path).read_bytes())
    load = lab['LOAD']
    k = lab['CKSUM'] - load
    tail = 6 if 'CRCFIX' in lab else 2
    if k != len(img) - tail:
        raise SystemExit(f'{bin_path}: CKSUM is not {tail} bytes from the end')
    img[k:k + 2] = struct.pack('<H', sum(img[:k]) & 0xFFFF)
    if tail == 6:
        at = lab['CRCAT'] - load
        img[-4:] = struct.pack('<I', zlib.crc32(bytes(img[at:-4])))
        assert zlib.crc32(bytes(img[at:])) == 0x2144DF1C
    Path(bin_path).write_bytes(img)
    return img


def atr(out, boot, pieces, tab):
    """Write the image: a 16-byte ATR header, then 720 sectors."""
    disk = bytearray(SECTORS * 128)
    assert len(boot) == 512
    disk[0:512] = boot
    for name, data in pieces.items():
        sec = tab[name][0]
        disk[(sec - 1) * 128:(sec - 1) * 128 + len(data)] = data
    paras = len(disk) // 16
    head = struct.pack('<HHHHB', 0x0296, paras & 0xFFFF, 128, paras >> 16, 0) + bytes(7)
    Path(out).write_bytes(head + disk)
    used = max(t[0] + t[1] - 1 for n, t in tab.items() if n in pieces) if pieces else 4
    print(f'{out}: {used} of {SECTORS} sectors, '
          + ', '.join(f'{n} {tab[n][0]}+{tab[n][1]}' for n in PIECES if n in pieces))
