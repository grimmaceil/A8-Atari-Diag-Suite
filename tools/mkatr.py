#!/usr/bin/env python3
"""The boot disk (Atari-diag-boot-disk-scope.md): its layout, the pieces'
sums, and the .atr image. Used by build.py (build_disk, make_disk).

Layout: sectors 1-4 the boot, then each piece in a run of whole sectors,
in PIECES order. build/disktab.asm tells every piece where the others are:
first sector, sector count, load page. A piece not on the disk points past
its end, so loading it fails as a disk error does.

And the disk set (disk-set/, build.py's build_diskset) and the 16k memtest
disk: the tapes' own programs on disks (cas_image), one booted by the OS
from sector 1 (plain), or two with a boot that picks one by the RAM
(choice, settab).
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


def header(disk):
    """The 16-byte ATR header for an image of 128-byte sectors."""
    paras = len(disk) // 16
    return struct.pack('<HHHHB', 0x0296, paras & 0xFFFF, 128, paras >> 16, 0) + bytes(7)


def atr(out, boot, pieces, tab):
    """Write the image: a 16-byte ATR header, then 720 sectors."""
    disk = bytearray(SECTORS * 128)
    assert len(boot) == 512
    disk[0:512] = boot
    for name, data in pieces.items():
        sec = tab[name][0]
        disk[(sec - 1) * 128:(sec - 1) * 128 + len(data)] = data
    Path(out).write_bytes(header(disk) + disk)
    used = max(t[0] + t[1] - 1 for n, t in tab.items() if n in pieces) if pieces else 4
    print(f'{out}: {used} of {SECTORS} sectors, '
          + ', '.join(f'{n} {tab[n][0]}+{tab[n][1]}' for n in PIECES if n in pieces))


def cas_image(path):
    """A tape file's program as it is read from the tape: the data of its
    $FC records, as many as its first one's header says (byte 1). The boot
    file's is what the OS loads; a part 2's is what tape 1's loader reads."""
    d, p, data = Path(path).read_bytes(), 0, []
    while p < len(d):
        ln = struct.unpack('<H', d[p + 4:p + 6])[0]
        if d[p:p + 4] == b'data' and d[p + 10] == 0xFC:
            data.append(d[p + 11:p + 11 + 128])
        p += 8 + ln
    img = b''.join(data[:data[0][1]])
    assert img[0] == 0 and img[1] * 128 == len(img) and img[2] == 0, f'{path}: not a program'
    return img


def plain(out, images):
    """A disk of programs one after another from sector 1. The OS boots the
    first as it would from tape (its sectors to LOAD, then LOAD+6); a second
    is read by the first (the RAM disk: part 2 from the sector after part
    1's last, loader.asm's DSKLD)."""
    disk = bytearray(SECTORS * 128)
    at = 0
    for img in images:
        disk[at:at + len(img)] = img
        at += len(img)
    Path(out).write_bytes(header(disk) + disk)
    print(f'{out}: ' + ' + '.join(f'{len(i) // 128}' for i in images) + ' sectors')


def settab(images):
    """build/settab.asm's text: where a two-program disk keeps its programs
    (after the boot's four sectors), as disktab's, for dload.asm."""
    rows, sec = [], FIRST
    for img in images:
        rows.append((sec, len(img) // 128, img[3]))
        sec += len(img) // 128
    col = lambda f: ', '.join(f(t) for t in rows)
    return ('; build.py: where a disk set disk keeps its programs (tools/mkatr.py)\n'
            f'dtsl\t.byte {col(lambda t: f"${t[0] & 0xFF:02X}")}\n'
            f'dtsh\t.byte {col(lambda t: f"${t[0] >> 8:02X}")}\n'
            f'dtcnt\t.byte {col(lambda t: str(t[1]))}\n'
            f'dtpg\t.byte {col(lambda t: f"${t[2]:02X}")}\n')


def choice(out, boot, images):
    """A two-program disk: the boot (src/disk/setboot.asm, assembled with
    settab(images)) in sectors 1-4, then the programs in that order."""
    assert len(boot) == 512 and boot[1] == 4
    disk = bytearray(SECTORS * 128)
    disk[:512] = boot
    at = 512
    for img in images:
        disk[at:at + len(img)] = img
        at += len(img)
    Path(out).write_bytes(header(disk) + disk)
    print(f'{out}: boot 4, ' + ' + '.join(f'{len(i) // 128}' for i in images) + ' sectors')
