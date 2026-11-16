#!/usr/bin/env python3
"""BASCRC, the BASIC ROM check (src/basic/bascrc.bas), as files to load.

The diag programs check the XL/XE's built-in BASIC themselves; a BASIC
cartridge (the 400/800, the 1200XL) they don't read, so this short Atari
BASIC program does: it CRC32s $A000-$BFFF with a little machine code and
names the revision (A, B, C). Two forms of the same listing:
  .lst  ATASCII text (EOL $9B), for ENTER "D:BASCRC.LST" from a DOS disk
  .cas  a tape for ENTER "C:": the OS cassette handler's records (full $FC,
        the last partial $FA with its byte count in its last byte, then
        EOF $FE), with normal inter-record gaps, since the handler stops the
        motor between records when BASIC reads it this way
"""
import argparse
from pathlib import Path

from mkcas import chunk, record

LEADER_MS = 20000      # (as LIST "C:" writes it: slack before the first block)
IRG_MS = 3000


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('src')
    ap.add_argument('lst')
    ap.add_argument('cas')
    a = ap.parse_args()
    lines = [ln.rstrip() for ln in Path(a.src).read_text(encoding='ascii').splitlines()
             if ln.strip()]
    data = b''.join(ln.encode('ascii') + b'\x9b' for ln in lines)
    Path(a.lst).write_bytes(data)
    recs = []
    for i in range(0, len(data), 128):
        part = data[i:i + 128]
        if len(part) == 128:
            recs.append(record(part))
        else:
            recs.append(record(part + bytes(127 - len(part)) + bytes([len(part)]), 0xFA))
    recs.append(record(bytes(128), 0xFE))
    out = chunk(b'FUJI', 0, b'BASCRC') + chunk(b'baud', 600)
    for k, r in enumerate(recs):
        out += chunk(b'data', LEADER_MS if k == 0 else IRG_MS, r)
    Path(a.cas).write_bytes(out)
    secs = LEADER_MS / 1000 + (len(recs) - 1) * IRG_MS / 1000 + len(recs) * 132 * 10 / 600
    print(f'{a.cas}: {len(lines)} lines, {len(data)} bytes, {len(recs)} records, ~{secs:.0f} s')


if __name__ == '__main__':
    main()
