#!/usr/bin/env python3
"""Make the cartridge's sampled "hello" (src/cart/audio/hello.bin) from
src/cart/audio/En-us-hello.ogg: the word, trimmed, at one sample every
LINES scan lines (15.7 kHz / 3 = 5.2 kHz), 4 bits a sample, two samples to
a byte (the first in the high nibble). src/cart/hello.asm plays it.

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
    n = int(len(d) / sr * RATE) & ~1              # (a whole number of bytes)
    edges = np.linspace(0, len(d), n + 1).astype(int)
    s = np.array([d[edges[i]:edges[i + 1]].mean() for i in range(n)])   # box filter
    s = s / np.abs(s).max()
    q = np.clip(np.round(s * 7.5 + 7.5), 0, 15).astype(int)
    OUT.write_bytes(bytes(q[i] << 4 | q[i + 1] for i in range(0, n, 2)))
    print(f'{OUT}: {n} samples at {RATE:.0f} Hz, {n / RATE:.2f} s, {n // 2} bytes')


if __name__ == '__main__':
    main()
