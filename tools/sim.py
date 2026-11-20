#!/usr/bin/env python3
"""Run a boot image under py65 with a minimal Atari model and decode the
beep/flash code it produces.

Model: RAM from $0000 to --ram (a floating bus above it reads the address high
byte, as the real bus does after an abs or (zp),Y fetch), hardware registers
logged, WSYNC = one scanline. No ANTIC/GTIA/POKEY beyond that.

Real hardware faults can be simulated, independent of the FAULT build flag:
  --stuck BANK:BIT:LEVEL   e.g. 2:5:0 = bank 2 ($4000-$7FFF), D4 stuck low
  --stuck LO-HI:BIT:LEVEL  e.g. 0200-0400:1:1 = D0 stuck high in $0200-$03FF
  --stuck xN:BIT:LEVEL     the same in 130XE extended bank N (0-3, --xe)
  --mirror                 bank 3 aliases bank 2 (a missing address line)
  --leak LO-HI:SECS        e.g. 8000-9000:3 = a refresh fault: a page there
                           forgets (reads $00) once SECS pass with no CPU
                           access to it (any access refreshes its row)
Cartridges and the empty bus:
  --basic FILE --slot      the 8K ROM is a cartridge in the slot on an XL/XE
                           too: TRIG3 reads 1 and PORTB bit 1 can't switch it
                           out (without --slot, an XL/XE's --basic is built in)
  --dmabus                 400/800: an empty address at $A000-$BFFF reads $00
                           while ANTIC's DMA is on (DMACTL nonzero: the last
                           byte it fetched, a blank screen's), its high byte
                           while it is off
  --hole LO-HI             no RAM there (a pulled board): reads float, writes
                           are lost; more than one --hole may be given
  --nochip D800|E000       a 400/800 OS chip pulled: its range floats
GTIA's collisions are an approximation (the dead test's GTIA check): every
collision register reads 0 after a HITCLR write; a player's playfield
collisions (P0PF-P3PF) read $0F once that player's GRAFPn is written nonzero
while ANTIC's DMA is on.
  --rompoke ADDR=VAL,...   OS ROM bytes changed (a bad chip)
The dead test (a .car whose start bank's $BFFD bit 7 is set) is entered at
($BFFE) with nothing set up; at its hand-over (a jump to the OS's reset
entry) or at the end, the dead: line gives its results as the PIA and the
stack pointer hold them, and every value written to PORTB until then.
"""
import argparse
import struct
from pathlib import Path
import os
import random
import sys

from py65.devices.mpu6502 import MPU

LINES_PER_MS = 15.7


class Atari:
    """Time comes from the CPU cycle count: 114 cycles per scanline, and a
    WSYNC write skips to the start of the next line. (No DMA cycle stealing.)"""

    def __init__(self, ramtop, stuck, mirror, xl, pal, keys, xe=False, xstuck=None):
        self.ram = bytearray(0x10000)
        self.xe = xe             # 130XE: 4 x 16K at $4000 when PORTB bit 4 = 0
        self.ext = bytearray(0x10000)
        self.xstuck = xstuck     # (bank, andmask, ormask) in extended RAM
        self.xealias = False
        self.flaky = None        # (lo, hi, mask, probability)
        self.leak = None         # (lo, hi, lines): --leak, a refresh fault
        self.ltouch = {}         # --leak: page -> the line of its last access
        self.nmis = 0
        self.irqen, self.irqen_line = 0, 0
        self.stimer = None
        self.presses = []        # (start_line, end_line, kind, value)
        self.kbcode = 0xFF
        self.ramtop = ramtop
        self.stuck = stuck       # (lo, hi, andmask, ormask) or None
        self.mirror = mirror
        self.xl = xl
        self.pal = pal
        self.frame_lines = 312 if pal else 262
        self.keys = keys         # [(start_line, end_line)] a key is held
        self.mpu = None
        self.events = []         # (line, reg, value)
        self.regs = {}
        self.romover = {}       # --forge: stand-in ROM bytes replaced
        self.osrom = None        # --osrom: a real OS image (10K or 16K)
        self.basic = None        # --basic: a real 8K BASIC (or cartridge)
        self.pm = {}            # GRACTL, PMBASE: for the P/M color mask in screen()
        self.car = None          # .car: an AtariMax 128K (16 x 8K at $A000) or 1 MB (128)
        self.carbank, self.caron = 0, False
        self.carlog = []         # (line, 'bank n' / 'off')
        self.ddrb = 0xFF if xl else 0x00   # PIA port B direction, as the OS sets it
        self.ddra = 0x00                   # PIA port A direction (the dead test's storage)
        self.dlw = []            # (line, register, value): DLISTL/DLISTH writes, the
                                 # last few frames (a display list chosen row by row)
        self.holes = []          # --hole: (lo, hi), no RAM there
        self.nochip = []         # --nochip: (lo, hi), a 400/800 OS chip pulled
        self.pfcoll = [0, 0, 0, 0]   # P0PF-P3PF (see the docstring)
        self.busnoise = False    # an idle bus reads back anything (a real 800)
        self.slot = False        # --slot: --basic is a cartridge in the slot (XL/XE too)
        self.dmabus = False      # --dmabus: $A000-$BFFF's empty bus reads $00 with DMA on
        self.skctl = 0x13        # SKCTL as an OS load leaves it (main: 3 for a .car)
        self.mute34 = []         # (line, AUDC, value): voice 3 or 4 turned on while
                                 # SKCTL bit 4 (async receive) holds it silent

    def _carsel(self, a):
        """AtariMax 128K: an access to $D500-$D50F selects bank n, $D510-$D51F
        switches the cartridge off. 1 MB (the 8 Mbit MaxFlash): $D500-$D57F
        bank n, $D580-$D5FF off."""
        if self.car is None or len(self.car) == 0x2000:    # (a plain 8K: no banks)
            return
        big = len(self.car) > 0x20000
        if big or a & 0xFF < 0x20:
            on, bank = (not a & 0x80, a & 0x7F) if big else (not a & 0x10, a & 0x0F)
            if (on, bank) != (self.caron, self.carbank):
                self.carlog.append((self.line, f'bank {bank}' if on else 'off'))
            self.caron = on
            if on:
                self.carbank = bank

    def _t4lines(self):
        """Timer 4's period in scan lines: AUDF4, or AUDF4:AUDF3 with voices
        3 and 4 joined (AUDCTL bit 3), at 64 kHz (15 kHz with AUDCTL bit 0)."""
        ctl = self.regs.get(0xD208, 0)
        n = self.regs.get(0xD206, 0)
        if ctl & 8:
            n = n << 8 | self.regs.get(0xD204, 0)
        clock = 15700 if ctl & 1 else 63921
        return (n + 1) / clock * 1000 * LINES_PER_MS

    def peek(self, a):
        """What ANTIC sees: the cartridge ROM where it is mapped, else RAM."""
        a &= 0xFFFF
        if self.caron and 0xA000 <= a < 0xC000:
            return self.car[self.carbank * 0x2000 + a - 0xA000]
        return self.ram[a]

    def active(self, kind):
        ln = self.line
        out = []
        for st, en, k, v in self.presses:
            if k == kind and st <= ln < en:
                out.append(v)
                if k == 'KB':
                    self.kbcode = v
        return out

    def press(self, at, kind, value=None, secs=0.25):
        self.presses.append((at, at + int(secs * 1000 * LINES_PER_MS), kind, value))

    @property
    def line(self):
        return self.mpu.processorCycles // 114

    def _map(self, a):
        if self.mirror and 0x8000 <= a < 0xC000:
            return a - 0x4000
        return a

    def __getitem__(self, a):
        if isinstance(a, slice):
            return [self[i] for i in range(*a.indices(0x10000))]
        if 0xD000 <= a < 0xD800:
            if 0xD004 <= a < 0xD008:     # P0PF-P3PF
                return self.pfcoll[a - 0xD004]
            if 0xD000 <= a < 0xD004 or 0xD008 <= a < 0xD010:
                return 0         # the other collision registers
            if a == 0xD01F:      # console keys, 0 = pressed
                v = 0x0F
                for bit in self.active('CON'):
                    v &= ~bit
                return v
            if a == 0xD209:      # KBCODE: the last key pressed
                ln = self.line
                last = [e for e in self.presses if e[2] == 'KB' and e[0] <= ln]
                if last:
                    self.kbcode = max(last)[3]
                return self.kbcode
            if a == 0xD20A:
                return random.randrange(256)
            if a == 0xD40B:
                return (self.line % self.frame_lines) // 2
            if a == 0xD014:
                return 0x01 if self.pal else 0x0F
            if a == 0xD013:      # TRIG3: XL/XE, 1 = a cartridge in the slot (the
                if self.xl:      # diag cartridge while it is on); 400/800: stick
                    return int(self.car is not None and self.caron or self.slot)   # 4's button,
                return 1         # not pressed
            if a == 0xD300:      # PORTA: sticks 1 and 2, 0 = pressed (--joy)
                if not self.regs.get(0xD302, 0x3C) & 4:
                    return self.ddra     # PACTL bit 2 = 0: the direction register
                v = 0xFF
                for bit in self.active('JOY'):
                    v &= ~bit
                ora = self.regs.get(0xD300, 0xFF)    # output pins read what they drive
                return (v & ~self.ddra | ora & self.ddra) & 0xFF
            if a == 0xD010:      # TRIG0: fire on stick 1, 0 = pressed (--joy)
                return 0 if self.active('FIRE') else 1
            if a in (0xD302, 0xD303):   # PACTL/PBCTL: bits 0-5 as written (the
                return self.regs.get(a, 0x3C) & 0x3F   # IRQ flags, 6-7: none)
            if a == 0xD301:
                if not self.regs.get(0xD303, 0x3C) & 4:
                    return self.ddrb     # PBCTL bit 2 = 0: the direction register
                if not self.xl:
                    return 0xFF          # 400/800: joystick ports 3 and 4, nothing in
                return self.regs.get(a, 0xFF)
            if 0xD500 <= a < 0xD600:
                self._carsel(a)
                return 0xFF
            if a == 0xD20E:      # IRQST: bit 6 latches a keypress while the
                ln = self.line   # keyboard IRQ is enabled (masked or not),
                v = 0xFF         # bit 7 BREAK, bit 0 timer 1 (~4 ms after STIMER)
                if self.irqen & 0x40 and (any(self.irqen_line <= s <= ln for s, e in self.keys)
                                          or any(self.irqen_line <= e[0] <= ln
                                                 for e in self.presses if e[2] == 'KB')):
                    v &= ~0x40
                if self.irqen & 0x80 and any(self.irqen_line <= e[0] <= ln
                                             for e in self.presses if e[2] == 'BREAK'):
                    v &= ~0x80
                if self.irqen & 1 and self.stimer is not None and ln - self.stimer > 63:
                    v &= ~1
                if (self.irqen & 4 and self.stimer is not None
                        and ln - max(self.stimer, self.irqen_line) > self._t4lines()):
                    v &= ~4
                return v
            if 0xD200 <= a < 0xD208:
                return 228       # POTn: nothing plugged in
            if a == 0xD20F:      # SKSTAT: bit 2 low while a key is held, 3 SHIFT
                ln = self.line
                v = 0xFF
                if any(s <= ln < e for s, e in self.keys) or self.active('KB'):
                    v &= ~4
                if self.active('SHIFT'):
                    v &= ~8
                return v
            return 0xFF
        if a >= 0xC000 and self.os_out():
            if self.ramtop < 0xC000:
                return a >> 8    # e.g. a 16K 600XL: nothing under the OS
        elif a >= 0xC000:
            if self.xl or a >= 0xD800:
                if any(lo <= a < hi for lo, hi in self.nochip):
                    return a >> 8    # --nochip: the chip pulled, a floating bus
                if a in self.romover:
                    return self.romover[a]
                if self.osrom is not None:
                    return self.osrom[a - (0xC000 if len(self.osrom) == 0x4000 else 0xD800)]
                return ((a * 31) ^ (a >> 3)) & 0xFF    # stand-in ROM bytes
            if self.busnoise:
                return random.randrange(256)
            return a >> 8        # 400/800: nothing at $C000-$CFFF
        pb = self.regs.get(0xD301, 0xFF)
        if (self.xl and self.osrom is not None and len(self.osrom) == 0x4000
                and 0x5000 <= a < 0x5800 and pb & 0x81 == 0x01):
            return self.osrom[a - 0x4000]   # the self-test ROM (PORTB bit 7 = 0)
        if self.caron and 0xA000 <= a < 0xC000:
            return self.car[self.carbank * 0x2000 + a - 0xA000]
        if self.basic is not None and 0xA000 <= a < 0xC000 and (
                not self.xl or self.slot or not pb & 0x02):
            return self.basic[a - 0xA000]   # BASIC (XL/XE: PORTB bit 1 = 0) or a cartridge
        if any(lo <= a < hi for lo, hi in self.holes):
            return a >> 8        # --hole: floating bus
        if self.ramtop <= a < 0xC000:
            if self.dmabus and a >= 0xA000 and self.regs.get(0xD400, 0):
                return 0x00      # --dmabus: ANTIC's last fetch, with its DMA on
            return a >> 8        # floating bus
        x = self._ext(a)
        if x is not None:
            v = self.ext[x]
            if self.xstuck and x >> 14 == self.xstuck[0]:
                v = (v & self.xstuck[1]) | self.xstuck[2]
            return v
        a = self._map(a)
        if self.leak:
            self._leak(a)
        v = self.ram[a]
        if self.stuck and self.stuck[0] <= a < self.stuck[1]:
            v = (v & self.stuck[2]) | self.stuck[3]
        if self.flaky and self.flaky[0] <= a < self.flaky[1] and random.random() < self.flaky[3]:
            v ^= self.flaky[2]
        return v

    def __setitem__(self, a, v):
        if 0xD000 <= a < 0xD800:
            if a == 0xD20E:
                self.irqen, self.irqen_line = v, self.line
            if a == 0xD209:
                self.stimer = self.line
            if a in (0xD01D, 0xD407):
                self.pm[a] = v
            if a == 0xD20F:
                self.skctl = v
            # POKEY's async receive mode (SKCTL bit 4, as SIO leaves it) holds
            # timers 3 and 4 until a start bit: those voices make no sound
            if a in (0xD205, 0xD207) and v & 0x0F and self.skctl & 0x10:
                self.mute34.append((self.line, a, v))
            if 0xD500 <= a < 0xD600:
                self._carsel(a)
            if a == 0xD301 and not self.regs.get(0xD303, 0x3C) & 4:
                self.ddrb = v
                return
            if a == 0xD300:
                if not self.regs.get(0xD302, 0x3C) & 4:
                    self.ddra = v
                else:
                    self.regs[a] = v     # port A's output register
                return
            if a == 0xD303:
                self.regs[a] = v
            if a == 0xD01E:      # HITCLR
                self.pfcoll = [0, 0, 0, 0]
            if 0xD00D <= a < 0xD011 and v and self.regs.get(0xD400, 0):
                self.pfcoll[a - 0xD00D] = 0x0F
            if a in (0xD402, 0xD403):
                self.dlw.append((self.line, a, v))
                if len(self.dlw) > 400:
                    self.dlw = [w for w in self.dlw if w[0] > self.line - 3 * self.frame_lines]
            if a == 0xD40A:
                self.mpu.processorCycles = (self.line + 1) * 114
            elif a in (0xD01A, 0xD200, 0xD201, 0xD01F, 0xD40E, 0xD400,
                       0xD402, 0xD403, 0xD302, 0xD301, 0xD017, 0xD018,
                       0xD012, 0xD013, 0xD014, 0xD015, 0xD401, 0xD409,
                       0xD016, 0xD019, 0xD01B, 0xD404, 0xD405,
                       0xD000, 0xD001, 0xD002, 0xD003, 0xD008, 0xD009, 0xD00A, 0xD00B,
                       0xD00D, 0xD00E, 0xD00F, 0xD010, 0xD011,
                       0xD202, 0xD203, 0xD204, 0xD205, 0xD206, 0xD207, 0xD208):
                if self.regs.get(a) != v:
                    self.events.append((self.line, a, v))
                self.regs[a] = v
            return
        if a >= 0xC000 and self.os_out():
            if self.ramtop >= 0xC000:
                self.ram[a] = v
            return
        if a >= self.ramtop or a >= 0xC000 or self.caron and a >= 0xA000:
            return
        if any(lo <= a < hi for lo, hi in self.holes):
            return
        x = self._ext(a)
        if x is not None:
            self.ext[x] = v
            return
        if self.leak:
            self._leak(self._map(a))
        self.ram[self._map(a)] = v

    def _leak(self, a):
        """--leak: a page in the range that no CPU access touched for too
        long has lost its contents (refresh never reached its row). ANTIC's
        reads aren't modelled: keep the screen block out of the range."""
        lo, hi, n = self.leak
        if lo <= a < hi:
            p, ln = a >> 8, self.line
            last = self.ltouch.get(p)
            if last is not None and ln - last > n:
                self.ram[p << 8:(p + 1) << 8] = bytes(256)
            self.ltouch[p] = ln

    def _ext(self, a):
        pb = self.regs.get(0xD301, 0xFF)
        if self.xe and 0x4000 <= a < 0x8000 and not pb & 0x10:
            bank = (pb >> 2) & 3
            if self.xealias and bank == 3:
                bank = 2         # a stuck bank-select line
            return bank * 0x4000 + a - 0x4000
        return None

    def os_out(self):
        return self.xl and not self.regs.get(0xD301, 0xFF) & 1

    def __len__(self):
        return 0x10000

    def render(self, path, palette, font, scale=2):
        """The last whole frame as a PNG: border (COLBK), the GRAPHICS 0 text
        (COLPF2 background, COLPF1 luminance), inverse video, the P/M color
        mask, and every color as it was on each scan line (WSYNC color bars
        and ramps too). palette: 768 bytes of RGB; font: the 1K ROM font.
        A display list with more than GRAPHICS 0 text (test 7's modes page)
        is drawn by tools/antic.py instead."""
        from PIL import Image
        import antic
        fl = self.frame_lines
        f0 = (self.line // fl - 1) * fl          # the last complete frame
        regs = (0xD01A, 0xD017, 0xD018, 0xD012, 0xD013, 0xD014, 0xD015, 0xD401, 0xD400,
                0xD016, 0xD019, 0xD01B, 0xD404, 0xD405)
        cur = {r: 0 for r in regs}
        per = []                                   # register values per scan line
        ev = sorted((e for e in self.events if e[1] in regs), key=lambda e: e[0])
        k = 0
        for ln in range(f0, f0 + 248):
            while k < len(ev) and ev[k][0] <= ln:
                cur[ev[k][1]] = ev[k][2]
                k += 1
            per.append(dict(cur))
        dl = self.regs.get(0xD402, 0) | self.regs.get(0xD403, 0) << 8
        if any(p[0xD400] & 0x20 for p in per) and any(
                m != 2 for m, _, _, _ in antic.lines(self.peek, dl, per).values()):
            img = antic.draw(self.peek, dl, per, palette, font)
            img.resize((384 * scale, 240 * scale), Image.NEAREST).save(path)
            return
        rgb = lambda c: tuple(palette[(c & 0xFE) * 3:(c & 0xFE) * 3 + 3])
        W, H = 384, 240                            # scan lines 8-247, 32 px border
        img = Image.new('RGB', (W, H))
        px = img.load()
        rows = {}                                  # scan line -> (text address, row in char)
        if per[-1][0xD400] & 0x20 or any(p[0xD400] & 0x20 for p in per):
            dl = self.regs.get(0xD402, 0) | self.regs.get(0xD403, 0) << 8
            addr, scan = 0, 8
            for _ in range(64):
                op = self.peek(dl)
                if op == 0x41:
                    break
                if op & 0x0F == 0:
                    dl += 1
                    scan += (op >> 4 & 7) + 1
                    continue
                if op & 0x40:
                    addr = self.peek(dl + 1) | self.peek(dl + 2) << 8
                    dl += 3
                else:
                    dl += 1
                for r in range(8):
                    rows[scan + r] = (addr, r)
                addr += 40
                scan += 8
        pmb = self.pm.get(0xD407, 0) << 8 if self.pm.get(0xD01D, 0) == 3 else None
        for y in range(H):
            sl = y + 8
            p = per[sl]
            bk = rgb(p[0xD01A])
            for x in range(W):
                px[x, y] = bk
            if sl not in rows or not p[0xD400] & 0x20:
                continue
            addr, r = rows[sl]
            pf1, pf2 = p[0xD017], p[0xD018]
            for c in range(40):
                code = self.peek(addr + c)
                bits = font[(code & 0x7F) * 8 + r]
                if code & 0x80 and p[0xD401] & 2:
                    bits ^= 0xFF
                bg = pf2
                if pmb is not None:
                    yb = sl // 2
                    if c < 32:
                        on = self.ram[pmb + 0x200 + (c >> 3) * 0x80 + yb] & 0x80 >> (c & 7)
                        n = c >> 3
                    else:
                        m = c - 32
                        on = self.ram[pmb + 0x180 + yb] & 1 << (2 * (m >> 1) + 1 - (m & 1))
                        n = m >> 1
                    if on:
                        bg = p[0xD012 + n]
                fg = (bg & 0xF0) | (pf1 & 0x0E)
                cb, cf = rgb(bg), rgb(fg)
                for b in range(8):
                    px[32 + c * 8 + b, y] = cf if bits & 0x80 >> b else cb
        img.resize((W * scale, H * scale), Image.NEAREST).save(path)

    def screen(self):
        """The GRAPHICS 0 screen as text (inverse letters shown lowercase)."""
        if not self.regs.get(0xD400, 0) & 0x20:
            return '(ANTIC DMA off)'
        dl = self.regs[0xD402] | self.regs[0xD403] << 8
        fl = self.frame_lines
        f0 = (self.line // fl - 1) * fl        # the last whole frame
        if any(f0 + 8 < ln < f0 + fl for ln, _, _ in self.dlw):
            return self._screen_rewritten(f0)
        rows, addr, scan = [], 0, 8
        # SIM_PMKEEP=1: show the mask even after P/M is switched off (the auto
        # responder finishes the keyboard test before most snapshot times)
        pmb = self.pm.get(0xD407, 0) << 8 if self.pm.get(0xD01D, 0) == 3 or os.environ.get('SIM_PMKEEP') and 0xD407 in self.pm else None
        for _ in range(64):
            op = self.peek(dl)
            if op == 0x41:
                break
            if op & 0x0F == 0:
                dl += 1
                scan += (op >> 4 & 7) + 1
                continue
            if op & 0x40:
                addr = self.peek(dl + 1) | self.peek(dl + 2) << 8
                dl += 3
            else:
                dl += 1
            row = ''
            for c in [self.peek(addr + i) for i in range(40)]:
                ch = c & 0x7F
                ch = chr(ch + 32) if ch < 64 else '^v[]'[ch - 0x5C] if 0x5C <= ch < 0x60 else '~'
                row += ch.lower() if c & 0x80 and ch.isalpha() else (
                    '#' if c & 0x80 and ch == ' ' else ch)
            row = row.rstrip()
            if pmb is not None:     # double-line P/M: columns with color behind them
                y = scan // 2
                cols = ''.join('=' if self.ram[pmb + 0x200 + (c >> 3) * 0x80 + y] & 0x80 >> (c & 7)
                               else ' ' for c in range(32))
                cols += ''.join('=' if self.ram[pmb + 0x180 + y] & 1 << (2 * (m >> 1) + 1 - (m & 1))
                                else ' ' for m in range(8))
                if cols.strip():
                    row += '\n  |' + cols.rstrip()
            rows.append(row)
            addr += 40
            scan += 8
        return '\n'.join(f'{i:2d}|{r}' for i, r in enumerate(rows))


def _dl_at(hw, t):
    """The display-list pointer as the CPU had last written it by line t."""
    lo = hi = None
    for ln, r, v in hw.dlw:
        if ln > t:
            break
        if r == 0xD402:
            lo = v
        else:
            hi = v
    lo = hw.regs.get(0xD402, 0) if lo is None else lo
    hi = hw.regs.get(0xD403, 0) if hi is None else hi
    return lo | hi << 8


def _screen_rewritten(self, f0):
    """The screen of the frame from line f0 when the CPU rewrote the
    display-list pointer while it was drawn (the dead test picks each row's
    line that way): ANTIC fetches each instruction at its row's first line,
    from wherever the pointer was last set before that line."""
    p = _dl_at(self, f0 + 7)
    rows, scan, last, addr = [], 8, f0 + 7, 0
    for _ in range(64):
        t = f0 + scan
        if any(last < ln < t for ln, _, _ in self.dlw):
            p = _dl_at(self, t - 1)
        last = t
        op = self.peek(p)
        if op in (0x41, 0x01) or scan >= 248:
            break
        if op & 0x0F == 0:
            p += 1
            scan += (op >> 4 & 7) + 1
            continue
        addr = self.peek(p + 1) | self.peek(p + 2) << 8 if op & 0x40 else addr
        p += 3 if op & 0x40 else 1
        row = ''
        for c in [self.peek(addr + i) for i in range(40)]:
            ch = c & 0x7F
            ch = chr(ch + 32) if ch < 64 else '^v[]'[ch - 0x5C] if 0x5C <= ch < 0x60 else '~'
            row += ch.lower() if c & 0x80 and ch.isalpha() else ('#' if c & 0x80 and ch == ' ' else ch)
        rows.append(row.rstrip())
        scan += 8
    return '\n'.join(f'{i:2d}|{r}' for i, r in enumerate(rows))


Atari._screen_rewritten = _screen_rewritten


def forge(hw, spec):
    """--forge ADDR=CRC,...: make the stand-in ROM chip at ADDR (D800, E000 or
    F000, 400/800 sizes) hit that CRC32, by solving for its last 4 bytes
    (CRC32 is affine over GF(2)), so tape 3's ROM names can be tested
    without real ROM images."""
    import zlib
    size = {0xD800: 0x800, 0xE000: 0x1000, 0xF000: 0x1000}
    for item in spec.split(','):
        addr, want = (int(x, 16) for x in item.split('='))
        body = bytes(hw[a] for a in range(addr, addr + size[addr] - 4))
        base = zlib.crc32(body + bytes(4))
        cols = [zlib.crc32(body + (1 << i).to_bytes(4, 'little')) ^ base for i in range(32)]
        rows = [(cols[i], 1 << i) for i in range(32)]     # (crc effect, x bits)
        x, need = 0, base ^ want
        for bit in range(32):                              # Gaussian elimination
            piv = next(k for k in range(bit, 32) if rows[k][0] >> bit & 1)
            rows[bit], rows[piv] = rows[piv], rows[bit]
            for k in range(32):
                if k != bit and rows[k][0] >> bit & 1:
                    rows[k] = (rows[k][0] ^ rows[bit][0], rows[k][1] ^ rows[bit][1])
        for bit in range(32):
            if need >> bit & 1:
                x ^= rows[bit][1]
        tail = x.to_bytes(4, 'little')
        assert zlib.crc32(body + tail) == want
        for i, v in enumerate(tail):
            hw.romover[addr + size[addr] - 4 + i] = v


SIOV = 0xE459
XITVBV = 0xE462


def push(mpu, hw, v):
    hw.ram[0x100 + mpu.sp] = v & 0xFF
    mpu.sp = (mpu.sp - 1) & 0xFF


def pull(mpu, hw):
    mpu.sp = (mpu.sp + 1) & 0xFF
    return hw.ram[0x100 + mpu.sp]


def vbi(mpu, hw):
    """A VBI NMI. With the OS in, do what its NMI handler does before
    JMP (VVBLKI): push A, X, Y. With the OS out (XL/XE), the CPU takes the
    vector from RAM at $FFFA. A VVBLKI still pointing into the OS (its own
    VBI) isn't modelled: those NMIs are skipped."""
    if hw.os_out():
        vec = hw.ram[0xFFFA] | hw.ram[0xFFFB] << 8
        regs = ()
    else:
        vec = hw.ram[0x222] | hw.ram[0x223] << 8
        regs = (mpu.a, mpu.x, mpu.y)
        if vec >= 0xC000:
            # the OS's own VBI (the disk loader runs with it): just its
            # shadow copies, the screen and the border as they will look
            for reg, sh in ((0xD01A, 0x2C8), (0xD017, 0x2C5), (0xD018, 0x2C6),
                            (0xD400, 0x22F), (0xD402, 0x230), (0xD403, 0x231),
                            (0xD409, 0x2F4), (0xD401, 0x2F3)):
                hw[reg] = hw.ram[sh]
            return
    push(mpu, hw, mpu.pc >> 8)
    push(mpu, hw, mpu.pc)
    push(mpu, hw, mpu.p & ~mpu.BREAK)
    mpu.p |= mpu.INTERRUPT
    for r in regs:
        push(mpu, hw, r)
    mpu.pc = vec
    hw.nmis += 1


def xitvbv(mpu, hw):
    mpu.y = pull(mpu, hw)
    mpu.x = pull(mpu, hw)
    mpu.a = pull(mpu, hw)
    mpu.p = pull(mpu, hw) | mpu.UNUSED
    lo = pull(mpu, hw)
    mpu.pc = lo | pull(mpu, hw) << 8


def cas_records(path):
    import struct
    d, p, out = open(path, 'rb').read(), 0, []
    while p < len(d):
        ln = struct.unpack('<H', d[p + 4:p + 6])[0]
        if d[p:p + 4] == b'data':
            out.append(d[p + 8:p + 8 + ln])
        p += 8 + ln
    return out


def siov(mpu, hw, stream, disk=None, diskerr=None):
    """Stand-in for the OS's SIOV, held to what the OS listing says the call
    needs. Cassette reads: the cassette DCB as RBLOK builds it, short gaps.
    Disk reads (an .atr, drive 1): command R, 128 bytes, about 0.11 s a
    sector (an 810); diskerr {sector: times} fails a sector that often
    ($90, the drive's error). Both need interrupts running (VBI timers,
    serial IRQs). Anything else is a timeout ($8A)."""
    m = hw.ram
    hw.skctl = 0x13          # the OS's SIO ends in its receive mode, SKCTL $13
    irq_ok = not mpu.p & mpu.INTERRUPT and hw.regs.get(0xD40E, 0) & 0x40
    if disk is not None and m[0x300] == 0x31:
        sec = m[0x30A] | m[0x30B] << 8
        buf = m[0x304] | m[0x305] << 8
        ok = (m[0x301] == 1 and m[0x302] == 0x52 and m[0x303] == 0x40
              and m[0x308] | m[0x309] << 8 == 128)
        if not ok or not irq_ok:
            status = 0x8A
            print(f'SIOV timeout ({"DCB" if not ok else "interrupts off"})')
        elif not 1 <= sec <= len(disk) // 128 or diskerr.get(sec, 0) > 0:
            if sec in diskerr:
                diskerr[sec] -= 1
            status = 0x90
        else:
            for k in range(128):
                hw[buf + k] = disk[(sec - 1) * 128 + k]
            status = 1
        mpu.processorCycles += int(0.11 * 1.79e6)
        m[0x303] = status
        mpu.y = status
        mpu.p = (mpu.p & ~(mpu.NEGATIVE | mpu.ZERO)) | (mpu.NEGATIVE if status & 0x80 else 0)
        lo = m[0x100 + ((mpu.sp + 1) & 0xFF)]
        hi = m[0x100 + ((mpu.sp + 2) & 0xFF)]
        mpu.sp = (mpu.sp + 2) & 0xFF
        mpu.pc = ((hi << 8) | lo) + 1
        return
    dcb_ok = (m[0x300] == 0x60 and m[0x302] == 0x52 and m[0x303] == 0x40 and
              m[0x304] | m[0x305] << 8 == 0x3FD and m[0x308] | m[0x309] << 8 == 131
              and m[0x30B] & 0x80)
    if dcb_ok and irq_ok and stream:
        rec = stream.pop(0)
        m[0x3FD:0x3FD + 131] = rec[:131]
        status = 1
        mpu.processorCycles += int((132 * 10 / 600 + 0.26) * 1.79e6)
    else:
        status = 0x8A
        why = 'DCB' if not dcb_ok else 'interrupts off' if not irq_ok else 'tape end'
        print(f'SIOV timeout ({why})')
    m[0x303] = status
    mpu.y = status
    mpu.p = (mpu.p & ~(mpu.NEGATIVE | mpu.ZERO)) | (mpu.NEGATIVE if status & 0x80 else 0)
    lo = m[0x100 + ((mpu.sp + 1) & 0xFF)]
    hi = m[0x100 + ((mpu.sp + 2) & 0xFF)]
    mpu.sp = (mpu.sp + 2) & 0xFF
    mpu.pc = ((hi << 8) | lo) + 1


KEYCODES = [0x00, 0x01, 0x02, 0x05, 0x06, 0x07, 0x08, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E,
            0x0F, 0x10, 0x12, 0x15, 0x16, 0x17, 0x18, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E,
            0x1F, 0x20, 0x21, 0x22, 0x23, 0x25, 0x26, 0x27, 0x28, 0x2A, 0x2B, 0x2C,
            0x2D, 0x2E, 0x2F, 0x30, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
            0x3A, 0x3C, 0x3D, 0x3E, 0x3F]   # every key all machines have


WALK = [0x1F, 0x1E, 0x1A, 0x18, 0x1D, 0x1B, 0x33]   # keys 1-7: the menu order


class Auto:
    """Answers tape 3's prompts as a person would, from the screen text.
    deny: prompt words to answer No to; skip: keys to leave unpressed."""
    PROMPTS = ['HEARD ALL', 'PRESS EVERY KEY', 'PRESS START, SELECT AND OPTION',
               'PRESS START, SELECT, OPTION', 'HEARD IT?',
               'MOVE EACH STICK', 'UNPLUG ALL PADDLES', 'TURN EACH', 'LOOKS RIGHT?',
               'LOOKS RIGHT?']

    def __init__(self, hw, deny, skip, menuwalk=False, walk=None, skiponce=False):
        self.hw, self.deny, self.skip, self.seen = hw, deny, skip, set()
        self.menuwalk, self.walk = menuwalk or bool(walk), 0
        self.keys = walk or WALK          # the menu keys, in turn
        self.skiponce = skiponce

    def check(self):
        text = self.hw.screen()
        # the menu: its key line at a row's start (the RAM tapes' page test
        # shows the program's own pages, strings and all, as a jumble on top)
        if '|START=RUN  SELECT=DOWN' in text:   # (rows are 'NN|text')
            sel = [l for l in text.splitlines() if any(c.islower() for c in l[3:])]
            sig = 'MENU|' + '|'.join(sel)
            if sig not in self.seen:
                self.seen = {x for x in self.seen if x.startswith('MENU|')}
                self.seen.add(sig)          # (a test run again is answered again)
                when = self.hw.line + int(1000 * LINES_PER_MS)
                if self.menuwalk and self.walk < len(self.keys):   # a test by its key
                    self.hw.press(when, 'KB', self.keys[self.walk])
                    self.walk += 1
                else:                         # START: the highlighted line (the
                    self.hw.press(when, 'CON', 1)            # next test, then the results)
            return
        if ('START = GO ON' in text or 'START=GO ON' in text or 'ANY OTHER KEY=GO ON' in text
                or 'ANY OTHER KEY=MENU' in text):   # a result that waits: one
            ln = self.hw.line        # press, as a person would (a tap during a tone
            lines = text.splitlines()  # counts, and a second could leak into the next test)
            sig = 'GOON|' + lines[0] + '|' + '|'.join(l for l in lines if 'TEST ' in l or 'PASS' in l)
            if sig not in self.seen and not any(e > ln for st, e, k, v in self.hw.presses if k == 'CON'):
                self.seen.add(sig)
                self.hw.press(ln + 4000, 'CON', 1)
            return
        for p in self.PROMPTS:
            if p not in text:
                continue
            lines = text.splitlines()         # the header names the test; a
            sig = p + '|' + lines[0] + '|' + '|'.join(  # result line is no new prompt
                l for l in lines if 'VOICE' in l)
            if sig in self.seen:
                continue
            self.seen.add(sig)
            self.answer(p, text)

    def answer(self, p, text):
        hw, t = self.hw, self.hw.line
        step = int(0.35 * 1000 * LINES_PER_MS)
        if p == 'PRESS EVERY KEY':
            codes = KEYCODES[:len(KEYCODES) - self.skip]
            if self.skiponce:
                self.skip = 0
            for i, c in enumerate(codes):
                hw.press(t + (i + 1) * step, 'KB', c | (0x80 if c == 0x3F else 0))
            n = len(codes) + 1
            hw.press(t + n * step, 'SHIFT')
            hw.press(t + (n + 1) * step, 'BREAK')
            hw.press(t + (n + 3) * step, 'CON', 1)
        elif p.startswith('PRESS START'):
            for i, bit in enumerate((1, 2, 4)):
                hw.press(t + (i + 1) * 2 * step, 'CON', bit)
        else:
            yes = not any(d in text for d in self.deny)
            when = t + int(2.5 * 1000 * LINES_PER_MS)
            if p in ('HEARD IT?', 'LOOKS RIGHT?', 'HEARD ALL'):
                hw.press(when, 'KB', 0x2B if yes else 0x23)
            else:
                hw.press(when, 'CON', 1)        # START


def tones(events):
    """AUDC1 on/off pairs -> [(start_ms, len_ms, audf, colbk)]."""
    out, audf, col, on = [], 0, 0, None
    for line, reg, v in events:
        if reg == 0xD200:
            audf = v
        elif reg == 0xD01A:
            col = v
        elif reg == 0xD201:
            if v & 0x0F and on is None:
                on = (line, audf, col)
            elif not v & 0x0F and on is not None:
                out.append((on[0] / LINES_PER_MS, (line - on[0]) / LINES_PER_MS,
                            on[1], on[2]))
                on = None
    return out


NAMES = {72: 'L', 35: 'S', 144: 'E', 60: 'J', 47: 'J', 40: 'J'}


def decode(ts):
    """Tones -> code string like 'L2 S5 E | L2 S5 E', groups split on >500 ms
    gaps, report repeats on >2 s gaps."""
    s, prev_end, grp = [], None, []
    def flush():
        if grp:
            s.append(f'{grp[0]}{len(grp)}' if grp[0] in 'LS' else
                     ''.join(grp) if grp[0] == 'J' else grp[0] * len(grp))
    for start, ln, f, col in ts:
        n = NAMES.get(f, '?')
        if n == '?':
            continue            # the alive chirp is a sweep, not a code tone
        gap = None if prev_end is None else start - prev_end
        if gap is not None and (gap > 500 or n != grp[0]):
            flush()
            grp = []
            if gap > 2000:
                s.append('|')
        grp.append(n)
        prev_end = start + ln
    flush()
    return ' '.join(s)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('tape', help='a .cas (boot stage, then later stages read via SIOV), '
                    'an .xex, a .car, an .atr (the boot disk) or a raw boot .bin')
    ap.add_argument('--ram', type=lambda x: int(x, 0), default=0xC000)
    ap.add_argument('--memlo', type=lambda x: int(x, 0), default=0x1CFC,
                    help='.xex: MEMLO as DOS leaves it (DOS 2.5: $1CFC)')
    ap.add_argument('--stuck')
    ap.add_argument('--mirror', action='store_true')
    ap.add_argument('--seconds', type=float, default=40,
                    help='simulated time to run after the tests finish')
    ap.add_argument('--xl', action='store_true', help='ROM at $C000 (XL/XE)')
    ap.add_argument('--xe', action='store_true', help='130XE: --xl plus 64K extended RAM')
    ap.add_argument('--xealias', action='store_true', help='extended bank 3 is bank 2')
    ap.add_argument('--xejunk', action='store_true',
                    help='130XE: extended RAM holds random bytes at power-on, as real RAM does')
    ap.add_argument('--pal', action='store_true')
    ap.add_argument('--kb', default='', help='CODE:SECS[:HOLD],...  a key by its KBCODE (hex), e.g. BE:2:8 = CTRL+S from 2 s for 8 s')
    ap.add_argument('--busnoise', action='store_true',
                    help='400/800: $C000-$CFFF (nothing there) reads back random bytes')
    ap.add_argument('--key', default='', help='seconds at which a key is pressed, e.g. 3,30')
    ap.add_argument('--snap', default='', help='seconds at which to print the screen')
    ap.add_argument('--shot', default='', help='SECS:FILE.png,... : save the screen as a picture')
    ap.add_argument('--shoton', action='append', default=[],
                    help='TEXT@SECS@FILE.png : a picture SECS after TEXT first shows on screen (^TEXT: at a row start)')
    ap.add_argument('--osrom', help='a real OS ROM file (10K 400/800 or 16K XL/XE) instead of the stand-in')
    ap.add_argument('--basic', help='a real 8K BASIC ROM: XL/XE built in, or a 400/800 cartridge')
    ap.add_argument('--slot', action='store_true',
                    help='with --basic: a cartridge in the slot, on an XL/XE too (TRIG3 = 1)')
    ap.add_argument('--nochip', action='append', default=[],
                    help='D800 or E000: that 400/800 OS chip pulled (reads float)')
    ap.add_argument('--rompoke', default='',
                    help='ADDR=VAL,... (hex): OS ROM bytes changed (a bad chip)')
    ap.add_argument('--hole', action='append', default=[],
                    help='LO-HI (hex): no RAM there; reads float, writes are lost')
    ap.add_argument('--dmabus', action='store_true',
                    help='400/800: $A000-$BFFF with nothing there reads $00 while DMACTL is on')
    ap.add_argument('--palette', default='//TRUENAS/Media/games/ATARI800/ntsc.act',
                    help='768-byte RGB palette for --shot (the MiSTer core palette)')
    ap.add_argument('--flaky', help='BANK:BIT:P  a bit that reads wrong with chance P per read')
    ap.add_argument('--leak', help='LO-HI:SECS  a refresh fault: a page there reads $00 once '
                    'SECS pass with no CPU access to it')
    ap.add_argument('--insert', nargs=2, metavar=('SECONDS', 'CAS'),
                    help='start playing another tape (e.g. a -part2.cas) at that time')
    ap.add_argument('--auto', action='store_true', help='answer tape 3 prompts')
    ap.add_argument('--until', type=float, help='stop at this simulated time (s)')
    ap.add_argument('--deny', default='', help='with --auto: answer No where the screen shows these (comma list)')
    ap.add_argument('--skip', type=int, default=0, help='with --auto: leave this many keys unpressed')
    ap.add_argument('--walk', help='with --auto: menu digits to press in turn, e.g. 22')
    ap.add_argument('--skiponce', action='store_true', help='--skip only the first keyboard test')
    ap.add_argument('--menuwalk', action='store_true',
                    help='with --auto: run the menu tests one at a time by their keys')
    ap.add_argument('--peek', help='LO-HI: print these BSS bytes (hex offsets) at the end')
    ap.add_argument('--forge', help='ADDR=CRC32,...: stand-in 400/800 OS chips with these CRCs')
    ap.add_argument('--pick', default='START:1',
                    help='.car: the console key pressed at the menu, and when (s): START or SELECT')
    ap.add_argument('--con', default='',
                    help='console keys pressed, e.g. START:52,SELECT:60 (seconds)')
    ap.add_argument('--joy', default='',
                    help='joystick 1, e.g. DOWN:52,FIRE:60 (UP, DOWN, LEFT, RIGHT, FIRE; seconds[:hold])')
    ap.add_argument('--diskerr', default='',
                    help='.atr: SECTOR[:TIMES],... sectors that fail to read (once, or TIMES times)')
    ap.add_argument('--bss', type=lambda x: int(x, 0),
                    help='where the program keeps its BSS page, for the end report (the 32k+ image: its BSS label)')
    ap.add_argument('--events', help='write every logged register write (line, register, value) to this file')
    ap.add_argument('-v', action='store_true')
    a = ap.parse_args()

    stuck = xstuck = None
    if a.stuck and a.stuck.startswith('x'):
        bank, bit, lvl = a.stuck[1:].split(':')
        m = 1 << (int(bit) - 1)
        xstuck = (int(bank), 0xFF if int(lvl) else 0xFF ^ m, m if int(lvl) else 0)
    elif a.stuck:
        where, bit, lvl = a.stuck.split(':')
        bit, lvl = int(bit), int(lvl)
        m = 1 << (bit - 1)
        if '-' in where:                   # an address range: LO-HI
            lo, hi = (int(x, 16) for x in where.split('-'))
        else:
            lo, hi = (int(where) - 1) * 0x4000, int(where) * 0x4000
        stuck = (lo, hi, 0xFF if lvl else 0xFF ^ m, m if lvl else 0)

    stream = []                            # records left on the tape
    xex = car = disk = None
    if a.tape.lower().endswith('.xex'):
        # Load it as DOS does: segment by segment, INITAD after any segment
        # that sets it, RUNAD at the end (xex_next, in the main loop). The
        # image is the biggest segment; it runs at $0800.
        raw = open(a.tape, 'rb').read()
        assert raw[:2] == b'\xff\xff', 'not an Atari binary file'
        xex, i = [], 2
        while i < len(raw):
            if raw[i:i + 2] == b'\xff\xff':
                i += 2
            st, en = struct.unpack('<HH', raw[i:i + 4])
            xex.append((st, raw[i + 4:i + 5 + en - st]))
            i += 5 + en - st
        img = max((d for _, d in xex), key=len)
    elif a.tape.lower().endswith('.car'):
        # The OS's cold start finds the cartridge and runs it (CARTRUN at
        # $BFFA, in the bank it starts in: 0; an older 8 Mbit MaxFlash,
        # type 42, starts in 127); RAMTOP stops below it. A diag
        # cartridge ($BFFD bit 7) is entered at ($BFFE) before any of that.
        raw = open(a.tape, 'rb').read()
        ctype = struct.unpack('>I', raw[4:8])[0]
        assert raw[:4] == b'CART' and ctype in (1, 41, 42, 75), 'not a .car of type 1, 41, 42, 75'
        car = raw[16:]
        assert len(car) == {1: 0x2000, 41: 0x20000}.get(ctype, 0x100000)
        carstart = 127 if ctype == 42 else 0
        img = bytes(6)                     # (the image: whichever the menu copies)
    elif a.tape.lower().endswith('.atr'):
        # The OS's disk boot: sector 1's header says how many sectors and
        # where; it loads them there and calls load+6 (as a tape boot).
        raw = open(a.tape, 'rb').read()
        assert raw[:2] == bytes([0x96, 0x02]), 'not an .atr'
        disk = raw[16:]
        img = disk[:disk[1] * 128]
    elif a.tape.lower().endswith('.cas'):
        recs = cas_records(a.tape)
        nrec = recs[0][4]
        img = b''.join(r[3:131] for r in recs[:nrec])
        stream = recs[nrec + 1:]           # the OS boot also reads the EOF
    else:
        img = open(a.tape, 'rb').read()
    load = img[2] | img[3] << 8
    to_line = lambda t: int(float(t) * 1000 * LINES_PER_MS)
    keys = [(to_line(t), to_line(t) + to_line(0.25)) for t in a.key.split(',') if t]
    snaps = sorted(to_line(t) for t in a.snap.split(',') if t)
    hw = Atari(a.ram, stuck, a.mirror, a.xl or a.xe, a.pal, keys, a.xe, xstuck)
    hw.busnoise = a.busnoise
    hw.slot = a.slot
    hw.holes = [tuple(int(x, 16) for x in h.split('-')) for h in a.hole]
    hw.nochip = [{'D800': (0xD800, 0xE000), 'E000': (0xE000, 0xF000)}[c.upper()]
                 for c in a.nochip]
    for kv in (x for x in a.rompoke.split(',') if x):
        k, v = kv.split('=')
        hw.romover[int(k, 16)] = int(v, 16)
    hw.dmabus = a.dmabus
    if car is not None:
        hw.skctl = 0x03                    # no SIO before a cartridge: the OS's 3
    for k in (x for x in a.kb.split(',') if x):
        c, t, *h = k.split(':')
        hw.press(to_line(t), 'KB', int(c, 16), float(h[0]) if h else 0.25)
    if a.osrom:
        hw.osrom = Path(a.osrom).read_bytes()
        assert len(hw.osrom) in (0x2800, 0x4000), 'an OS ROM is 10K or 16K'
    if a.basic:
        hw.basic = Path(a.basic).read_bytes()
        assert len(hw.basic) == 0x2000, 'a BASIC ROM is 8K'
    shots = sorted((to_line(t), f) for t, f in (x.split(':', 1) for x in a.shot.split(',') if x))
    if shots:
        palette = Path(a.palette).read_bytes()
        if hw.osrom is None:
            sys.exit('--shot needs --osrom (the screen font comes from it)')
        font = hw.osrom[0x2000:0x2400] if len(hw.osrom) == 0x4000 else hw.osrom[0x800:0xC00]
    when = [[x, to_line(d), f, None]   # [text, delay, file, due line]
            for x, d, f in (t.split('@', 2) for t in a.shoton)]
    if when and not shots:
        palette = Path(a.palette).read_bytes()
        if hw.osrom is None:
            sys.exit('--shoton needs --osrom (the screen font comes from it)')
        font = hw.osrom[0x2000:0x2400] if len(hw.osrom) == 0x4000 else hw.osrom[0x800:0xC00]
    next_look = 0
    if a.forge:
        forge(hw, a.forge)
    hw.xealias = a.xealias
    if a.xejunk:
        hw.ext[:] = random.Random(7).randbytes(0x10000)
    if a.flaky:
        bank, bit, prob = a.flaky.split(':')
        random.seed(1)
        hw.flaky = ((int(bank) - 1) * 0x4000, int(bank) * 0x4000, 1 << (int(bit) - 1),
                    float(prob))
    if a.leak:
        where, secs = a.leak.split(':')
        lo, hi = (int(x, 16) for x in where.split('-'))
        hw.leak = (lo, hi, to_line(secs))
    for i in range(0x800):                 # OS state that must survive
        hw.ram[i] = (i * 7 + 3) & 0xFF
    # RAMTOP ($6A), as the OS sized it at power-on: the RAM, up to $C000,
    # and $A000 with BASIC or a cartridge in (the tapes' NEEDPG check)
    hw.ram[0x6A] = min(a.ram, 0xC000, 0xA000 if a.basic or car else 0xC000) >> 8
    lowram_before = bytes(hw.ram[:0x800])
    mpu = MPU(memory=hw, pc=load + 6)
    hw.mpu = mpu
    mpu.sp = 0xF0
    # The OS's reset entry (a real --osrom only): a jump there with a
    # cartridge in (the dead test's hand-over) is the cold start again.
    reset_pc = hw[0xFFFC] | hw[0xFFFD] << 8 if a.osrom else None
    dead = []                              # the dead test's results at its hand-over

    def dead_line():
        portb = sorted({v for ln, r, v in hw.events if r == 0xD301})
        return (f'dead: ddra=${hw.ddra:02X} ddrb=${hw.ddrb:02X} s=${mpu.sp:02X} '
                f'pactl=${hw.regs.get(0xD302, 0x3C):02X} pbctl=${hw.regs.get(0xD303, 0x3C):02X} '
                f'portb={",".join(f"{v:02X}" for v in portb) or "-"}')

    def car_cold():
        """The OS's cold start with the cartridge in, as far as it matters
        here: a diag cartridge ($BFFD bit 7, in the bank that is in) is
        entered at ($BFFE) before the OS sets anything up; otherwise the
        chips cleared, RAM as the OS leaves it for a cartridge (low RAM,
        RAMTOP) and CARTRUN at ($BFFA)."""
        b = hw.carbank * 0x2000 if len(car) > 0x2000 else 0
        if car[b + 0x1FFD] & 0x80:
            mpu.pc = car[b + 0x1FFE] | car[b + 0x1FFF] << 8
            return
        hw.regs.clear()
        hw.ddrb = 0xFF if hw.xl else 0x00
        hw.ddra = 0x00
        for i in range(0x800):
            hw.ram[i] = (i * 7 + 3) & 0xFF
        hw.ram[0x6A] = min(a.ram, 0xA000) >> 8
        mpu.sp = 0xF0
        mpu.p |= mpu.INTERRUPT
        mpu.pc = car[b + 0x1FFA] | car[b + 0x1FFB] << 8
    XSENT = 0x0700                         # where the "DOS" loader would be
    if xex is not None:
        hw.ram[0x2E7], hw.ram[0x2E8] = a.memlo & 0xFF, a.memlo >> 8
        lowram_before = bytes(hw.ram[:0x800])

        def xex_next():                    # load on to the next INITAD or the end
            while xex:
                st, d = xex.pop(0)
                for k, v in enumerate(d):
                    hw[st + k] = v         # (RAM that isn't there keeps nothing)
                if st == 0x2E2:
                    push(mpu, hw, (XSENT - 1) >> 8)
                    push(mpu, hw, (XSENT - 1) & 0xFF)
                    mpu.pc = d[0] | d[1] << 8
                    return
            mpu.pc = hw.ram[0x2E0] | hw.ram[0x2E1] << 8
            print(f'xex loaded at {hw.line / LINES_PER_MS / 1000:.1f} s, run ${mpu.pc:04X}')
        xex_next()
    elif car is not None:
        hw.car, hw.caron, hw.carbank = car, True, carstart
        car_cold()
        key, at = a.pick.split(':')
        hw.press(to_line(at), 'CON', {'START': 1, 'SELECT': 2}[key.upper()])
    else:
        hw.ram[load:load + len(img)] = img
    for kv in (x for x in a.con.split(',') if x):
        key, at, *h = kv.split(':')        # KEY:SECS[:HOLD]
        hw.press(to_line(at), 'CON', {'START': 1, 'SELECT': 2, 'OPTION': 4}[key.upper()],
                 float(h[0]) if h else 0.25)
    for kv in (x for x in a.joy.split(',') if x):
        key, at, *h = kv.split(':')        # KEY:SECS[:HOLD]
        key = key.upper()
        hw.press(to_line(at), 'FIRE' if key == 'FIRE' else 'JOY',
                 {'UP': 1, 'DOWN': 2, 'LEFT': 4, 'RIGHT': 8, 'FIRE': 1}[key],
                 float(h[0]) if h else 0.25)
    diskerr = {}
    for kv in (x for x in a.diskerr.split(',') if x):
        sec, *n = kv.split(':')
        diskerr[int(sec)] = int(n[0]) if n else 1
    limit = None
    seen, aud_on = 0, -1                   # events looked at; the last voice-1 sound in them
    steps = 0
    entered = set()
    insert_at = to_line(a.insert[0]) if a.insert else None
    frame = 0
    auto = Auto(hw, [d for d in a.deny.split(',') if d], a.skip, a.menuwalk,
                [0x32 if c == '0' else 0x35 if c == '8' else 0x30 if c == '9' else WALK[int(c) - 1]
                 for c in a.walk] if a.walk else None,
                a.skiponce) if a.auto else None
    next_auto = 0
    while True:
        if auto and hw.line >= next_auto:
            next_auto = hw.line + 8000
            if hw.regs.get(0xD400, 0) & 0x20:
                auto.check()
        f = (hw.line - 248) // hw.frame_lines      # VBI at line 248
        if f != frame:
            frame = f
            if hw.regs.get(0xD40E, 0) & 0x40:
                vbi(mpu, hw)
        if mpu.pc == XITVBV:
            xitvbv(mpu, hw)
            continue
        if insert_at is not None and hw.line >= insert_at:
            stream[:] = cas_records(a.insert[1])
            insert_at = None
            print(f'tape {a.insert[1]} started at {hw.line / LINES_PER_MS / 1000:.1f} s')
        if xex is not None and mpu.pc == XSENT:
            xex_next()
            continue
        if mpu.pc == SIOV:
            siov(mpu, hw, stream, disk, diskerr)
            continue
        if car is not None and mpu.pc == reset_pc and hw.caron:
            if not dead:
                dead.append(dead_line())
            car_cold()
            print(f'cold start at {hw.line / LINES_PER_MS / 1000:.2f} s, bank {hw.carbank}')
            continue
        if mpu.pc == 0x2006 and 0x2006 not in entered and xex is None and car is None:   # (not .xex: its program has code there)
            entered.add(0x2006)
            print(f'stage 2 entered at {hw.line / LINES_PER_MS / 1000:.1f} s')
        mpu.step()
        steps += 1
        if shots and hw.line >= shots[0][0]:
            hw.render(shots.pop(0)[1], palette, font)
        if when and hw.line >= next_look:
            next_look = hw.line + 2000
            text = hw.screen()
            for w in when:
                if w[3] is None and (w[0] in text if not w[0].startswith('^') else
                                     '|' + w[0][1:] in text):
                    w[3] = hw.line + w[1]
                if w[3] is not None and w[3] >= 0 and hw.line >= w[3]:
                    hw.render(w[2], palette, font)
                    print(f'shot {w[2]} at {hw.line / LINES_PER_MS / 1000:.1f} s')
                    w[3] = -1
        if snaps and hw.line >= snaps[0]:
            print(f'--- screen at {snaps.pop(0) / LINES_PER_MS / 1000:.1f} s'
                  f'  COLBK ${hw.regs.get(0xD01A, 0):02X}')
            print(hw.screen())
        # The tests are over once the reporter starts its first flash.
        base = 4000                    # .car: from when the cartridge handed over
        if hw.carlog and hw.carlog[-1][1] == 'off':
            base += hw.carlog[-1][0]
        # (Only the new events each step: test 7's page 2 logs thousands of
        # color and scroll writes, and reading all of them each step never ended.)
        while seen < len(hw.events):
            ln, r, v = hw.events[seen]
            seen += 1
            if r == 0xD201 and v & 0x0F:
                aud_on = max(aud_on, ln)
        if limit is None and aud_on > base:
            limit = hw.line + a.seconds * 1000 * LINES_PER_MS
            t_done = hw.line / LINES_PER_MS / 1000
        if limit is not None and hw.line > limit:
            break
        if a.until and hw.line > a.until * 1000 * LINES_PER_MS:
            if limit is None:
                t_done = 0
            break
        if steps > 800_000_000:          # (every result waits now: long --auto runs need more)
            sys.exit('runaway: no report produced')

    if a.events:
        Path(a.events).write_text(''.join(f'{ln} {r:04X} {v:02X}\n' for ln, r, v in hw.events))
    if hw.mute34:
        ln, r, v = hw.mute34[0]
        print(f'POKEY: voice {(r - 0xD201) // 2 + 1} turned on (AUDC ${v:02X}) at '
              f'{ln / LINES_PER_MS / 1000:.1f} s while SKCTL is ${hw.skctl:02X} or like it: '
              f'held silent ({len(hw.mute34)} times in all)')
    ts = tones(hw.events)
    if a.v:
        for t in ts:
            print(f'{t[0]:9.0f} ms {t[1]:5.0f} ms audf {t[2]:3d} colbk ${t[3]:02X}')
    if car is not None:
        print(dead[0] if dead else dead_line())
    if car is not None:                  # the image the menu copied to $0800
        print('cartridge:', ', '.join(f'{ln / LINES_PER_MS / 1000:.2f} s {w}' for ln, w in hw.carlog))
        img = bytes(hw.ram[0x801] * 128)
        load = 0x0800
    bss = load + len(img)
    if car is not None and hw.caron:     # the tests run from ROM: BSS is at $0800
        bss = 0x0800
    if a.bss is not None:
        bss = a.bss
    elif 0x2006 in entered:                # stage 2's BSS follows its image
        bss = 0x2000 + hw.ram[0x2001] * 128
    bad = [hw.ram[bss + 0x40 + b] for b in range(10)]
    print(f'first result at {t_done:.1f} s, {steps} steps, {hw.nmis} VBIs, '
          f'ended at {hw.line / LINES_PER_MS / 1000:.0f} s, PC ${mpu.pc:04X}, PORTB ${hw.regs.get(0xD301, 0xFF):02X}')
    print('--- final screen'); print(hw.screen())
    if os.environ.get('SIM_DUMP'):       # LO-HI (hex): memory at the end, for checks
        lo, hi = (int(x, 16) for x in os.environ['SIM_DUMP'].split('-'))
        print(f'dump ${lo:04X}:', ' '.join(f'{hw.ram[i]:02X}' for i in range(lo, hi + 1)))
    if os.environ.get('SIM_IMGDIFF') and car is None:   # the image's bytes changed in RAM
        diff = [load + i for i in range(len(img)) if hw.ram[load + i] != img[i]]
        print(f'image bytes changed in RAM: {len(diff)}',
              ' '.join(f'${x:04X}:{img[x - load]:02X}>{hw.ram[x]:02X}' for x in diff[:24]))
    if a.peek:                           # BSS offsets, e.g. E0-F3
        lo, hi = (int(x, 16) for x in a.peek.split('-'))
        print(f'BSS ${bss:04X} +{lo:02X}:', ' '.join(f'{hw.ram[bss + i]:02X}' for i in range(lo, hi + 1)))
    print('BADMASK[1..9]', ' '.join(f'${b:02X}' for b in bad[1:]),
          ' RAMTOP $%02X00' % hw.ram[bss + 0x12], ' NBANKS', hw.ram[bss + 0x11])
    for b in range(1, 10):
        if bad[b]:
            r = lambda o: hw.ram[bss + o + b]
            print(f'  bank {b}: first ${r(0x80):02X}{r(0x70):02X} wrote ${r(0x90):02X}'
                  f' read ${r(0xA0):02X} count {r(0x50) | r(0x60) << 8}')
    # Low RAM must come through intact, apart from what the stage itself
    # uses once low RAM has passed: zero page $80-$FF (pointers, the system
    # tests' data) and the stack page.
    # SIO's control block, the cassette buffer and the display shadows are
    # written on purpose for the stage 2 load; burn-in sets VVBLKI and keeps
    # its log in $0500-$06FF.
    sio = set(range(0x300, 0x30C)) | set(range(0x3FD, 0x480)) | {0x22F, 0x230, 0x231,
          0x2C5, 0x2C6, 0x2C8, 0x2F3, 0x2F4, 0x4D, 0x222, 0x223} | set(range(0x500, 0x700))
    if xex is not None:                  # the loader's RUNAD/INITAD; the mover's COLDST
        sio |= {0x2E0, 0x2E1, 0x2E2, 0x2E3, 0x244}
    if car is not None:                  # the cartridge's COLDST, GINTLK, message line, trampoline
        sio |= {0x244, 0x3FA} | set(range(0x600, 0x700))
    keep = [i for i in range(0x800) if not (0x80 <= i < 0x100 or 0x100 <= i < 0x200
                                            or i in sio)]
    changed = [i for i in keep if hw.ram[i] != lowram_before[i]]
    print('low RAM preserved:', not changed,
          ' '.join(f'${i:04X}' for i in changed[:12]) if changed else '')
    print('code:', decode(ts))


if __name__ == '__main__':
    main()
