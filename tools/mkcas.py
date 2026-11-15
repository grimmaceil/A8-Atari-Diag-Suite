#!/usr/bin/env python3
"""Wrap assembled stage images as a bootable .cas tape.

Each image is raw (mads opt h-) and starts with the 6-byte cassette boot
header (flags, record count, load address, init address). This script:
  * patches each image's checksum into its last two bytes: the boot stage's
    self-check (see main.asm), and a plain sum for a later stage, which the
    stage before it checks after loading it;
  * writes FUJI / baud / data chunks, one 132-byte record per data chunk:
    $55 $55 sync, control $FC (full record), 128 data bytes, checksum.

Each later stage is also written as its own tape, <name>-partN.cas, for a
player that doesn't stop with the motor (AspeQt): play it when the stage
before is waiting, then press START.

Every file ends with an EOF record ($FE), as on commercial tapes: the OS
boot reads one record past the counted ones and discards it, so without it
the boot would swallow the next stage's first record.
"""
import argparse
import struct
import sys
import zlib

LEADER_MS = 15000   # mark tone before the first record (Necromancer: ~14.9 s)
IRG_MS = 260        # gap between records
NEXT_MS = 4000      # before a later stage: the motor was stopped, so the
                    # deck needs time to come up to speed


def read_labels(path):
    labels = {}
    for line in open(path, encoding='latin-1'):
        parts = line.split()
        if len(parts) == 3 and len(parts[1]) == 4:
            try:
                labels[parts[2].upper()] = int(parts[1], 16)
            except ValueError:
                pass
    return labels


def image_sum(img, load, ck_op, tail=2):
    """The 16-bit sum boot.asm computes at run time: every byte but the last
    TAIL (the sum, and CRCFIX if there is one).

    The page operand of ck_op is rewritten as the loop runs; when the loop
    reaches that byte it holds the page currently being summed, which is the
    page the byte itself is in.
    """
    seen = bytearray(img)
    op = ck_op + 2 - load
    seen[op] = (ck_op + 2) >> 8
    return sum(seen[:-tail]) & 0xFFFF


def record(data, ctrl=0xFC):
    rec = bytes([0x55, 0x55, ctrl]) + data
    ck = 0
    for b in rec:  # sum with end-around carry, as SIO does
        ck += b
        if ck > 0xFF:
            ck = (ck & 0xFF) + 1
    return rec + bytes([ck])


def chunk(tag, aux, body=b''):
    return tag + struct.pack('<HH', len(body), aux) + body


def plain_sum(img):
    return sum(img[:-2]) & 0xFFFF


def records(img, first_gap):
    """Data chunks for one file: its records, then the EOF record."""
    out = b''
    nrec = len(img) // 128
    for i in range(nrec):
        out += chunk(b'data', first_gap if i == 0 else IRG_MS,
                     record(bytes(img[i * 128:(i + 1) * 128])))
    return out + chunk(b'data', IRG_MS, record(bytes(128), 0xFE))


def load_image(path):
    img = bytearray(open(path, 'rb').read())
    nrec = img[1]
    if len(img) != nrec * 128:
        sys.exit(f'{path}: image is {len(img)} bytes, header says {nrec} records')
    return img, nrec, img[2] | img[3] << 8


def patch_boot(bin_path, lab_path):
    """Put the image sum into a boot image's last two bytes, in place
    (mkcas and mkxex). Returns the image, its records, load address, sum.
    With CRCFIX (the ROM test's self-check: the sum, then 4 bytes, end the
    image): those 4 bytes are the CRC32 of the image from CRCAT up to them,
    as it is in RAM once the boot has run (the page operands boot.asm's sum
    loop and low RAM test change, as they leave them), so the CRC32 of
    CRCAT to the end is the CRC32 residue."""
    img, nrec, load = load_image(bin_path)
    lab = read_labels(lab_path)
    tail = 6 if 'CRCFIX' in lab else 2
    if load != lab['LOAD'] or lab['CKSUM'] - load != len(img) - tail:
        sys.exit('boot image layout does not match the label table')
    s = image_sum(img, load, lab['CK_OP'], tail)
    k = len(img) - tail
    img[k:k + 2] = struct.pack('<H', s)
    if tail == 6:
        ram = bytearray(img)         # the boot's own changes to its code:
        ram[lab['CK_OP'] + 2 - load] = (load + len(img)) >> 8   # the sum loop's
        for lr in ('LR_A', 'LR_B', 'LR_C', 'LR_D'):              # page, the low
            if lr in lab:                                        # RAM test's
                ram[lab[lr] + 2 - load] = 0x08                   # (it ends at 8)
        at = lab['CRCAT'] - load
        if at % 256:
            sys.exit('CRCAT must be on a page')
        img[-4:] = struct.pack('<I', zlib.crc32(bytes(ram[at:-4])))
        assert zlib.crc32(bytes(ram[at:-4]) + bytes(img[-4:])) == 0x2144DF1C
    open(bin_path, 'wb').write(img)
    return img, nrec, load, s


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('cas')
    ap.add_argument('--boot', nargs=2, metavar=('BIN', 'LAB'), required=True)
    ap.add_argument('--next', action='append', default=[], metavar='BIN',
                    help='a later stage, loaded by the stage before it')
    ap.add_argument('--name', default='A8 DIAG')
    a = ap.parse_args()

    img, nrec, load, s = patch_boot(a.boot[0], a.boot[1])

    out = chunk(b'FUJI', 0, a.name.encode('ascii'))
    out += chunk(b'baud', 600)
    out += records(img, LEADER_MS)
    secs = LEADER_MS / 1000 + (nrec + 1) * (132 * 10 / 600 + IRG_MS / 1000)
    print(f'{a.cas}: boot {nrec} records at ${load:04X}, sum ${s:04X}')
    for k, path in enumerate(a.next, 2):
        img, n, load = load_image(path)
        if n % 2:
            sys.exit(f'{path}: a later stage must be whole pages')
        s = plain_sum(img)
        img[-2:] = struct.pack('<H', s)
        open(path, 'wb').write(img)
        out += records(img, NEXT_MS)
        part = a.cas[:-4] + f'-part{k}.cas'
        open(part, 'wb').write(chunk(b'FUJI', 0, f'{a.name} PART {k}'.encode('ascii'))
                               + chunk(b'baud', 600) + records(img, NEXT_MS))
        secs += NEXT_MS / 1000 + (n + 1) * (132 * 10 / 600 + IRG_MS / 1000)
        print(f'  + {n} records at ${load:04X}, sum ${s:04X}')
    open(a.cas, 'wb').write(out)
    print(f'  ~{secs:.0f} s of tape')


if __name__ == '__main__':
    main()
