#!/usr/bin/env python3
"""Make the sampled "hello" for src/cart/hello.asm from
src/cart/audio/En-us-hello.ogg, and a preview to listen to on a PC.

  src/cart/audio/hello-15k.bin   one sample a scan line (15.7 kHz), one
                                 byte each, 0-30 (two voices' levels added):
                                 packed by build.py (hello_pak: 4-bit steps,
                                 half the size) for the cartridge, the boot
                                 disk and the tapes, which unpack it as it
                                 plays
  build/hello-preview.wav        what the Atari plays, in the order it plays
                                 it: 4 bits (one voice), 1 bit (the console
                                 speaker), 5 bits (two voices), for both
                                 rates; then the recording itself

It starts and ends at 0, the level of a voice that is off, with a 5 ms
ramp to and from the middle (silence), so a word doesn't start or stop
with a click. Whole pages, padded with 0.

The recording is cleaned up for 4 and 5 bits, the usual steps for speech
at a low bit depth:
  1. low frequencies and the DC offset out (a 100 Hz high-pass): they use
     up levels without adding anything you can hear on a TV speaker
  2. the word only: the silence before and after cut, 10 ms kept
  3. presence: 1.5 kHz and up lifted (about 5 dB), so the consonants (the
     h, the l) stay clear
  4. compression: the quiet parts raised towards the loud ones (2:1 on a
     10 ms envelope, at most 12 dB), so the word fills the 16 levels
     instead of using the top few for the "e" and losing the rest; a gate
     keeps the silence silent
  5. a proper low-pass (windowed sinc) at 0.45 x the playback rate, and
     resampling to it, so nothing above it folds back as noise
  6. peak normalized, a little soft clipping, rounded to 0-30
No dither: at 4 bits it adds a steady hiss, worse than the rounding.

Run by hand when the recording or a step changes; the results are in git,
so a build doesn't need this. It needs numpy and soundfile
(pip install soundfile); the build needs neither.

The recording: "En-us-hello.ogg" from Wikimedia Commons, by the Commons
user Dvortygirl, released into the public domain
(https://commons.wikimedia.org/wiki/File:En-us-hello.ogg).
"""
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / 'src' / 'cart' / 'audio'
SRC = AUDIO / 'En-us-hello.ogg'
LINE = 15700.0                  # NTSC scan lines a second (PAL: 15557, 1% slower)
# file, scan lines a sample when played, how many times faster than recorded
OUTS = [(AUDIO / 'hello-15k.bin', 1, 1)]
PREVIEW = ROOT / 'build' / 'hello-preview.wav'
PREV_SR = 44100


def lowpass(x, fc, sr, zeros=16):
    """Windowed-sinc low-pass at fc Hz."""
    f = fc / sr
    n = np.arange(-int(zeros / (2 * f)), int(zeros / (2 * f)) + 1)
    h = 2 * f * np.sinc(2 * f * n) * np.blackman(len(n))
    return np.convolve(x, h / h.sum(), mode='same')


def resample(x, sr_in, sr_out, zeros=16):
    """Band-limited resampling: a windowed sinc at 0.45 x the new rate,
    evaluated at each new sample's position."""
    fc = 0.45 * min(sr_in, sr_out) / sr_in          # cycles per input sample
    half = int(zeros / (2 * fc)) + 1
    t = np.arange(int(len(x) * sr_out / sr_in)) * sr_in / sr_out
    k = np.arange(-half, half + 1)
    idx = np.floor(t).astype(int)[:, None] + k[None, :]
    d = t[:, None] - idx
    w = 2 * fc * np.sinc(2 * fc * d) * np.blackman(2 * half + 1)[None, :]
    xi = np.where((idx >= 0) & (idx < len(x)), x[np.clip(idx, 0, len(x) - 1)], 0.0)
    return (xi * w).sum(axis=1) / w.sum(axis=1)


def envelope(x, sr, ms):
    n = max(1, int(sr * ms / 1000))
    return np.sqrt(np.convolve(x * x, np.ones(n) / n, mode='same'))


def clean(d, sr):
    a = np.exp(-2 * np.pi * 100 / sr)                # 1. high-pass, 100 Hz
    y = np.zeros_like(d)
    for i in range(1, len(d)):
        y[i] = a * (y[i - 1] + d[i] - d[i - 1])
    env = envelope(y, sr, 10)                        # 2. the word only
    on = np.where(env > env.max() * 0.03)[0]
    y = y[max(on[0] - sr // 100, 0):on[-1] + sr // 100]
    y = y + 0.8 * (y - lowpass(y, 1500, sr))         # 3. presence
    env = envelope(y, sr, 10)                        # 4. compression and gate
    e = env / env.max()
    g = np.clip(e, 1e-4, 1) ** -0.5
    g = np.minimum(g, 4.0) * np.clip((e - 0.02) / 0.03, 0, 1)
    g = np.convolve(g, np.ones(sr // 200) / (sr // 200), mode='same')
    y = y * g
    n = int(sr * 0.005)                              # (5 ms fades)
    ramp = np.linspace(0, 1, n)
    y[:n] *= ramp
    y[-n:] *= ramp[::-1]
    return y


def quantize(y, bits=5):
    """0-30 (5 bits: two voices' levels added)."""
    top = 30 if bits == 5 else 15
    y = y / np.abs(y).max()                          # 6. normalize, soft clip
    y = np.tanh(1.3 * y) / np.tanh(1.3)
    return np.clip(np.round((y + 1) * top / 2), 0, top).astype(int)


def play(q, lines, mode):
    """What POKEY or the speaker puts out, as -1..1 at PREV_SR."""
    top = q.max() if q.max() > 15 else 15            # (0-30 or 0-15)
    if mode == 4:
        v = ((q >> 1) if top > 15 else q) / 15.0
    elif mode == 5:
        v = q / 30.0
    else:                                            # 1 bit, as hello.asm does
        mid = (top + 1) // 2                         # 16 of 0-30, 8 of 0-15
        v, on = np.zeros(len(q)), 0
        for i, s in enumerate(q):
            on = 1 if s >= mid else 0 if s <= mid - 2 else on
            v[i] = on
    v = v * 2 - 1
    v -= v[:200].mean() if len(v) > 200 else 0      # (no click from the offset)
    hold = np.repeat(v, 64)                          # sample and hold, then down
    return resample(hold, LINE / lines * 64, PREV_SR, zeros=8) * 0.8


def main():
    import soundfile as sf          # (only here: mkwords.py shares the rest)
    d, sr = sf.read(SRC)
    if d.ndim > 1:
        d = d.mean(axis=1)
    y = clean(d, sr)
    gap = np.zeros(int(PREV_SR * 0.3))
    preview = []
    for path, lines, fast in OUTS:
        rate = LINE / lines / fast                       # recorded at
        q = quantize(resample(y, sr, rate))
        ramp = np.round(np.linspace(0, 15, max(4, int(rate * 0.005)))).astype(int)
        q = np.concatenate([ramp, q, ramp[::-1]])
        q = np.concatenate([q, np.zeros(-len(q) % 256, int)])
        path.write_bytes(bytes(q.tolist()))
        print(f'{path.name}: {len(q)} samples recorded at {rate:.0f} Hz, played at '
              f'{LINE / lines:.0f} Hz ({len(q) * lines / LINE:.2f} s), {len(q)} bytes '
              f'({len(q) // 256} pages)')
        for mode in (4, 1, 5):
            preview += [play(q, lines, mode), gap]
    orig = resample(d / np.abs(d).max(), sr, PREV_SR) * 0.8
    preview += [gap, orig]
    pcm = (np.clip(np.concatenate(preview), -1, 1) * 32000).astype('<i2')
    PREVIEW.parent.mkdir(exist_ok=True)
    with wave.open(str(PREVIEW), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(PREV_SR)
        w.writeframes(pcm.tobytes())
    print(f'{PREVIEW}: {len(pcm) / PREV_SR:.1f} s')


if __name__ == '__main__':
    main()
