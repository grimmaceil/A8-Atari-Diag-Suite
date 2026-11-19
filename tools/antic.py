"""ANTIC and GTIA drawn from memory: the simulator's picture of a frame whose
display list has more than GRAPHICS 0 text (sim.py's render hands it over;
test 7's video modes page, for the user guide).

What it draws, per scan line, with the registers as they were on that line:
the character modes 2, 6 and 7 (the font: the 1K ROM font, CHBASE $E0),
the bitmap modes 8-F, GTIA's modes 9, 10 and 11 on mode F lines (PRIOR bits
6-7), blank lines, LMS, JMP/JVB, fine scrolling (HSCROL: a wide fetch moved
right; VSCROL: the first line of a region starts at row VSCROL, the line
after it ends there) and the normal playfield width. Not drawn: players and
missiles, DLIs, the narrow and wide playfields, modes 3-5's extras.

The picture is 384 x 240 (scan lines 8-247; the playfield's 320 hires pixels
from x 32), as sim.py's render makes it.
"""
LINES = {2: 8, 3: 10, 4: 8, 5: 16, 6: 8, 7: 16, 8: 8, 9: 4, 10: 4, 11: 2, 12: 1,
         13: 2, 14: 1, 15: 1}
BYTES = {2: 40, 3: 40, 4: 40, 5: 40, 6: 20, 7: 20, 8: 10, 9: 10, 10: 20, 11: 20,
         12: 20, 13: 40, 14: 40, 15: 40}       # a line, normal width
COLBK, COLPM0, COLPF0, PRIOR = 0xD01A, 0xD012, 0xD016, 0xD01B
CHACTL, DMACTL, HSCROL, VSCROL = 0xD401, 0xD400, 0xD404, 0xD405
REGS = (COLBK, PRIOR, 0xD012, 0xD013, 0xD014, 0xD015, 0xD016, 0xD017, 0xD018,
        0xD019, CHACTL, DMACTL, HSCROL, VSCROL)


def lines(peek, dl, per, top=8, bottom=248):
    """The display list, walked: {scan line: (mode, address, row, hscrol)}."""
    out, scan, addr, inv = {}, top, 0, False
    for _ in range(240):
        if scan >= bottom:
            break
        op = peek(dl)
        mode = op & 0x0F
        if mode == 0:                          # blank lines
            dl += 1
            scan += (op >> 4 & 7) + 1
            inv = False
            continue
        if mode == 1:                          # JMP, or JVB: the end
            if op & 0x40:
                break
            dl = peek(dl + 1) | peek(dl + 2) << 8
            continue
        if op & 0x40:
            addr = peek(dl + 1) | peek(dl + 2) << 8
            dl += 3
        else:
            dl += 1
        rows = LINES[mode]
        p = per[min(scan, len(per) - 1)]
        first, last = 0, rows - 1
        vs = p.get(VSCROL, 0) & 0x0F
        if op & 0x20:                          # a VSCROL line
            if not inv:
                first = min(vs, rows - 1)
            inv = True
        elif inv:                              # the line after the region
            last = min(vs, rows - 1)
            inv = False
        hs = p.get(HSCROL, 0) & 0x0F if op & 0x10 else None
        for r in range(first, last + 1):
            out[scan] = (mode, addr, r, hs)
            scan += 1
        width = BYTES[mode] * (48 if hs is not None else 40) // 40
        addr = (addr & 0xF000) | ((addr + width) & 0x0FFF)   # (a 4K boundary wraps)
    return out


def pixel(peek, font, mode, addr, r, d, sub, p):
    """The color value at data color clock d (and hires half sub) of a line."""
    pf = [p.get(COLPF0 + i, 0) for i in range(4)]
    bk = p.get(COLBK, 0)
    if mode == 2:
        code = peek(addr + d // 4)
        bits = font[(code & 0x7F) * 8 + r]
        if code & 0x80 and p.get(CHACTL, 0) & 2:
            bits ^= 0xFF
        on = bits & 0x80 >> ((d % 4) * 2 + sub)
        return (pf[2] & 0xF0) | (pf[1] & 0x0E) if on else pf[2]
    if mode in (6, 7):
        code = peek(addr + d // 8)
        row = r // 2 if mode == 7 else r
        on = font[(code & 0x3F) * 8 + row] & 0x80 >> (d % 8)
        return pf[code >> 6] if on else bk
    if mode in (8, 10, 13):                    # 4 colors: BAK, PF0, PF1, PF2
        px = d // {8: 4, 10: 2, 13: 1}[mode]
        v = peek(addr + px // 4) >> (6 - 2 * (px % 4)) & 3
        return [bk, pf[0], pf[1], pf[2]][v]
    if mode in (9, 11, 12):                    # 2 colors: BAK, PF0
        px = d // {9: 4, 11: 1, 12: 1}[mode]
        return pf[0] if peek(addr + px // 8) & 0x80 >> (px % 8) else bk
    if mode == 15:
        gtia = p.get(PRIOR, 0) & 0xC0
        if not gtia:
            q = 2 * d + sub
            on = peek(addr + q // 8) & 0x80 >> (q % 8)
            return (pf[2] & 0xF0) | (pf[1] & 0x0F) if on else pf[2]
        if gtia == 0x80:                       # mode 10: a color clock later
            d -= 1
            if d < 0:
                return bk
        px = d // 2                            # 80 pixels, 4 bits each
        v = peek(addr + px // 2) >> (4 if px % 2 == 0 else 0) & 15
        if gtia == 0x40:                       # 9: 16 shades of COLBK's hue
            return (bk & 0xF0) | v
        if gtia == 0xC0:                       # 11: 16 hues at COLBK's luminance
            return v << 4 | (bk & 0x0F)
        regs = [p.get(COLPM0 + i, 0) for i in range(4)] + pf + [bk] * 4 + pf
        return regs[v]                         # 10: nine registers
    return bk                                  # (modes 3-5: not drawn)


def draw(peek, dl, per, palette, font):
    """The frame as a PIL image (384 x 240)."""
    from PIL import Image
    W, H = 384, 240
    img = Image.new('RGB', (W, H))
    px = img.load()
    pal = lambda c, exact=False: tuple(palette[(c if exact else c & 0xFE) * 3:
                                               (c if exact else c & 0xFE) * 3 + 3])
    walk = lines(peek, dl, per)
    for y in range(H):
        sl = y + 8
        p = per[sl]
        bk = pal(p.get(COLBK, 0))
        for x in range(W):
            px[x, y] = bk
        if sl not in walk or not p.get(DMACTL, 0) & 0x20:
            continue
        mode, addr, r, hs = walk[sl]
        exact = mode == 15 and p.get(PRIOR, 0) & 0xC0 == 0x40   # (GTIA 9: 16 shades)
        for x in range(320):
            c = x // 2
            d = c + 16 - hs if hs is not None else c
            if d < 0:
                continue
            px[32 + x, y] = pal(pixel(peek, font, mode, addr, r, d, x % 2, p), exact)
    return img
