#!/usr/bin/env python3
"""Make the cartridge's sampled "hello" (src/cart/audio/hello.bin) from
src/cart/audio/En-us-hello.ogg: the word, trimmed, at one sample every
LINES scan lines (15.7 kHz / 3 = 5.2 kHz), 5 bits a sample (0-30: two
4-bit POKEY volumes added), packed high bit first, after a 2-byte count of
the samples. src/cart/hello.asm plays it (and halves it for one voice).

Run by hand when the recording or the rate changes; the result is in git,
so a build doesn't need this. It needs numpy and soundfile
(pip install soundfile), which the build doesn't.

The recording: "En-us-hello.ogg" from Wikimedia Commons, by the Commons
user Dvortygirl, released into the public domain
(https://commons.wikimedia.org/wiki/File:En-us-hello.ogg).
"""
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'src' / 'cart' / 'audio' / 'En-us-hello.ogg'
OUT = ROOT / 'src' / 'cart' / 'audio' / 'hello.bin'
LINES = 3                       # scan lines to a sample (hello.asm: HLINES)
RATE = 15700 / LINES


def main():
    d, sr = sf.read(SRC)
    if d.ndim > 1:
        d = d.mean(axis=1)
    a = np.abs(d)
    on = np.where(a > a.max() * 0.04)[0]          # the word, without the silence
    d = d[max(on[0] - sr // 100, 0):on[-1] + sr // 100]
    n = int(len(d) / sr * RATE)
    edges = np.linspace(0, len(d), n + 1).astype(int)
    s = np.array([d[edges[i]:edges[i + 1]].mean() for i in range(n)])   # box filter
    s = s / np.abs(s).max()
    q = np.clip(np.round(s * 15 + 15), 0, 30).astype(int)
    bits = ''.join(f'{v:05b}' for v in q)
    bits += '0' * (-len(bits) % 8)
    data = bytes(int(bits[i:i + 8], 2) for i in range(0, len(bits), 8))
    OUT.write_bytes(bytes([n & 0xFF, n >> 8]) + data)
    print(f'{OUT}: {n} samples at {RATE:.0f} Hz, {n / RATE:.2f} s, {len(data) + 2} bytes')


if __name__ == '__main__':
    main()
