#!/usr/bin/env python3
"""The dead test's spoken words (8 Mbit cartridge): each word made once with
the espeak-ng speech synthesizer (its output is free to use), cleaned up as
the "hello" recording is (tools/mkhello.py: high-pass, the word only,
presence, compression), low-passed and resampled to one sample every two
scan lines (7850 Hz), rounded to 4 bits (a POKEY voice's volume, 0-15),
two samples a byte (high nibble first), and committed:

  python tools/mkwords.py            all the words, with espeak-ng
  python tools/mkwords.py bank       just these

  src/deadtest/words/<name>.bin      the packed samples (whole pages: the
                                     player plays them all; the padding is
                                     silence)
  build/words-preview.wav            every word, as the Atari plays it

A word's WAV may be put at src/deadtest/words/<name>.wav to use instead of
the synthesizer (Mike's own recording, say): it is cleaned up the same way.
The word list and the synthesizer's settings are src/deadtest/words/words.txt.

Every word starts and ends at level 8 (a voice in volume-only mode at the
middle: silence), with a 5 ms ramp, so it starts and stops without a click.
Needs numpy (mkhello.py's own needs; the build needs neither).
"""
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mkhello import clean, lowpass, resample   # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
WORDS = ROOT / 'src' / 'deadtest' / 'words'
ESPEAK = Path(r'C:\Program Files\eSpeak NG\espeak-ng.exe')
RATE = 15700.0 / 2              # a sample every two scan lines (NTSC)
MAXPG = 20                      # a word bank's data pages (speak.asm: $A800-$BBFF)


def wordlist():
    """words.txt: '# settings: ...' then 'name: text' lines."""
    out, opts = [], []
    for line in (WORDS / 'words.txt').read_text(encoding='utf-8').splitlines():
        if line.startswith('# espeak-ng:'):
            opts = line.split(':', 1)[1].split()
        elif line.strip() and not line.startswith('#'):
            name, text = (s.strip() for s in line.split(':', 1))
            out.append((name, text))
    return out, opts


def synth(text, opts):
    with tempfile.TemporaryDirectory() as tmp:
        f = Path(tmp) / 'w.wav'
        subprocess.run([str(ESPEAK), *opts, '-w', str(f), text], check=True)
        return readwav(f)


def readwav(f):
    with wave.open(str(f)) as w:
        sr, n, ch, sw = w.getframerate(), w.getnframes(), w.getnchannels(), w.getsampwidth()
        d = np.frombuffer(w.readframes(n), dtype={1: np.uint8, 2: np.int16}[sw]).astype(float)
    if sw == 1:
        d -= 128
    if ch > 1:
        d = d.reshape(-1, ch).mean(axis=1)
    return d / np.abs(d).max(), sr


def make(d, sr):
    """4-bit levels at RATE, from the middle and back to it."""
    y = clean(d, sr)
    y = resample(lowpass(y, 0.45 * RATE, sr), sr, RATE)
    y = y / np.abs(y).max()
    y = np.tanh(1.3 * y) / np.tanh(1.3)
    q = np.clip(np.round((y + 1) * 7.5), 0, 15).astype(int)
    ramp = int(RATE * 0.005)
    q = np.concatenate([np.round(np.linspace(8, q[0], ramp)).astype(int), q,
                        np.round(np.linspace(q[-1], 8, ramp)).astype(int)])
    if len(q) % 2:
        q = np.append(q, 8)
    packed = bytes((a << 4) | b for a, b in zip(q[0::2], q[1::2]))
    packed += bytes([0x88]) * (-len(packed) % 256)       # whole pages of silence
    return packed, q


def main():
    words, opts = wordlist()
    pick = set(sys.argv[1:])
    preview = []
    for name, text in words:
        if pick and name not in pick:
            continue
        own = WORDS / f'{name}.wav'
        d, sr = readwav(own) if own.exists() else synth(text, opts)
        packed, q = make(d, sr)
        if len(packed) > MAXPG * 256:
            sys.exit(f'{name}: {len(packed) // 256} pages, a word bank holds {MAXPG}')
        (WORDS / f'{name}.bin').write_bytes(packed)
        preview.append(np.repeat(q / 7.5 - 1, 2))
        print(f'{name:10s} {len(q) / RATE:.2f} s  {len(packed) // 256} pages')
    if preview:
        pv = np.concatenate([np.concatenate([p, np.zeros(int(RATE))]) for p in preview])
        (ROOT / 'build').mkdir(exist_ok=True)
        with wave.open(str(ROOT / 'build' / 'words-preview.wav'), 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(int(RATE * 2))
            w.writeframes((pv * 12000).astype(np.int16).tobytes())


if __name__ == '__main__':
    main()
