#!/usr/bin/env python3
# Usage: python3 -I make_food_models.py <out_dir> <colormap.png>
# Builds low-poly Malaysian food .glb files that reuse the Kenney Food Kit colormap palette.
import json
import math
import os
import random
import struct
import sys
import zlib

OUT_DIR, TEX_PATH = sys.argv[1], sys.argv[2]


def read_png(path):
    d = open(path, "rb").read()
    pos, idat, plte, trns = 8, b"", b"", b""
    while pos < len(d):
        (ln,) = struct.unpack(">I", d[pos:pos + 4])
        typ, body = d[pos + 4:pos + 8], d[pos + 8:pos + 8 + ln]
        pos += 12 + ln
        if typ == b"IHDR":
            w, h, bd, ct = struct.unpack(">IIBB", body[:10])
        elif typ == b"PLTE":
            plte = body
        elif typ == b"tRNS":
            trns = body
        elif typ == b"IDAT":
            idat += body
    assert bd == 8 and ct in (2, 3, 6)
    bpp = {2: 3, 3: 1, 6: 4}[ct]
    raw, stride = zlib.decompress(idat), w * bpp
    rows, prev, p = [], bytearray(stride), 0
    for _ in range(h):
        f, line = raw[p], bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if f == 1:
                line[i] = (line[i] + a) & 255
            elif f == 2:
                line[i] = (line[i] + b) & 255
            elif f == 3:
                line[i] = (line[i] + ((a + b) >> 1)) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        rows.append(line)
        prev = line
    if ct == 3:
        pal = [(plte[i * 3], plte[i * 3 + 1], plte[i * 3 + 2], trns[i] if i < len(trns) else 255)
               for i in range(len(plte) // 3)]
        rows = [bytearray(b for idx in r for b in pal[idx]) for r in rows]
        bpp = 4
    return w, h, bpp, rows


W, H, BPP, ROWS = read_png(TEX_PATH)
SWATCHES = []
for cy in range(8, H, 16):
    for cx in range(8, W, 16):
        px = ROWS[cy][cx * BPP:cx * BPP + BPP]
        if BPP == 4 and px[3] < 255:
            continue
        if px[0] + px[1] + px[2] < 20:
            continue
        SWATCHES.append((px[0], px[1], px[2], (cx + 0.5) / W, (cy + 0.5) / H))


def col(rgb):
    best = min(SWATCHES, key=lambda s: sum((s[i] - rgb[i]) ** 2 for i in range(3)))
    return (best[3], best[4])


class Model:
    def __init__(self):
        self.P, self.N, self.T = [], [], []

    def tri(self, a, b, c, uv, ctr):
        u = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
        v = (c[0] - a[0], c[1] - a[1], c[2] - a[2])
        n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
        ln = math.sqrt(sum(x * x for x in n))
        if ln < 1e-12:
            return
        fc = [(a[i] + b[i] + c[i]) / 3 - ctr[i] for i in range(3)]
        if sum(n[i] * fc[i] for i in range(3)) < 0:
            b, c = c, b
            n = (-n[0], -n[1], -n[2])
        n = tuple(x / ln for x in n)
        for p in (a, b, c):
            self.P.append(p)
            self.N.append(n)
            self.T.append(uv)

    def recenter(self):
        xs = [p[0] for p in self.P]
        ys = [p[1] for p in self.P]
        zs = [p[2] for p in self.P]
        cx, cz, by = (min(xs) + max(xs)) / 2, (min(zs) + max(zs)) / 2, min(ys)
        self.P = [(p[0] - cx, p[1] - by, p[2] - cz) for p in self.P]


def xf(p, s, ry, rz, off):
    x, y, z = p[0] * s[0], p[1] * s[1], p[2] * s[2]
    if rz:
        c, sn = math.cos(rz), math.sin(rz)
        x, y = x * c - y * sn, x * sn + y * c
    if ry:
        c, sn = math.cos(ry), math.sin(ry)
        x, z = x * c + z * sn, -x * sn + z * c
    return (x + off[0], y + off[1], z + off[2])


def lathe(m, prof, seg, rgb, off, s=(1, 1, 1), ry=0, rz=0):
    uv = col(rgb)
    ys = [p[1] for p in prof]
    ctr = xf((0, (min(ys) + max(ys)) / 2, 0), s, ry, rz, off)
    rings = [[xf((r * math.cos(2 * math.pi * j / seg), y, r * math.sin(2 * math.pi * j / seg)), s, ry, rz, off)
              for j in range(seg)] for r, y in prof]
    for k in range(len(prof) - 1):
        for j in range(seg):
            j2 = (j + 1) % seg
            a, b, c, d = rings[k][j], rings[k][j2], rings[k + 1][j2], rings[k + 1][j]
            m.tri(a, b, c, uv, ctr)
            m.tri(a, c, d, uv, ctr)


def box(m, rgb, off, sz, ry=0):
    uv = col(rgb)
    h = [sz[0] / 2, sz[1] / 2, sz[2] / 2]
    v = [xf((sx * h[0], sy * h[1], sz_ * h[2]), (1, 1, 1), ry, 0, off)
         for sx in (-1, 1) for sy in (-1, 1) for sz_ in (-1, 1)]
    for q in [(0, 1, 3, 2), (4, 5, 7, 6), (0, 1, 5, 4), (2, 3, 7, 6), (0, 2, 6, 4), (1, 3, 7, 5)]:
        m.tri(v[q[0]], v[q[1]], v[q[2]], uv, off)
        m.tri(v[q[0]], v[q[2]], v[q[3]], uv, off)


def clean(x):
    return 0.0 if abs(x) < 1e-9 else x


def sphere(m, rgb, off, r, seg=8, rings=4, ry=0, rz=0):
    prof = []
    for i in range(rings + 1):
        a = -math.pi / 2 + math.pi * i / rings
        prof.append((clean(math.cos(a)), math.sin(a)))
    lathe(m, prof, seg, rgb, off, s=r, ry=ry, rz=rz)


def dome(m, rgb, off, r, seg=10, rings=3):
    prof = [(0, 0)]
    for i in range(rings + 1):
        a = (math.pi / 2) * i / rings
        prof.append((clean(math.cos(a)), math.sin(a)))
    lathe(m, prof, seg, rgb, off, s=r)


def cyl(m, rgb, off, r, h, seg=10):
    lathe(m, [(0, 0), (r, 0), (r, h), (0, h)], seg, rgb, off)


def roti_jala():
    m = Model()
    pale, gold = (250, 228, 165), (238, 185, 85)
    r, L = 0.045, 0.30
    prof = [(0, -L / 2), (r * 0.85, -L / 2), (r, -L / 2 + 0.025), (r, L / 2 - 0.025), (r * 0.85, L / 2), (0, L / 2)]
    rolls = [(-0.09, r, 0.000), (0.0, r, 0.012), (0.09, r, -0.010),
             (-0.045, r + 0.0779, -0.006), (0.045, r + 0.0779, 0.008)]
    for z, y, dx in rolls:
        lathe(m, prof, 8, pale, (dx, y, z), rz=-math.pi / 2)
        for x in (-0.09, 0.0, 0.09):
            lathe(m, [(0, -0.007), (r * 1.06, -0.007), (r * 1.06, 0.007), (0, 0.007)], 8, gold,
                  (x + dx, y, z), rz=-math.pi / 2)
    return m


def karipap():
    m = Model()
    gold, dark = (215, 145, 75), (165, 95, 60)
    uv = col(gold)
    R, h, N, M = 0.20, 0.12, 5, 9
    rings = []
    for k in range(N + 1):
        phi = (math.pi / 2) * k / N
        s, y, zc = clean(math.cos(phi)), h * math.sin(phi), 0.05 * math.sin(phi)
        rings.append([(R * s * math.cos(math.pi * j / M), y, zc + 0.8 * R * s * math.sin(math.pi * j / M))
                      for j in range(M + 1)])
    ctr = (0, h * 0.35, 0.07)
    for k in range(N):
        for j in range(M):
            a, b, c, d = rings[k][j], rings[k][j + 1], rings[k + 1][j + 1], rings[k + 1][j]
            m.tri(a, b, c, uv, ctr)
            m.tri(a, c, d, uv, ctr)
        right_a, left_a, right_b, left_b = rings[k][0], rings[k][M], rings[k + 1][0], rings[k + 1][M]
        m.tri(left_a, right_a, right_b, uv, ctr)
        m.tri(left_a, right_b, left_b, uv, ctr)
    for j in range(M):
        m.tri((0, 0, 0), rings[0][j], rings[0][j + 1], uv, ctr)
    for i in range(9):
        box(m, dark, (-0.17 + i * 0.0425, 0.025, -0.002), (0.032, 0.05, 0.035))
    for j in range(1, M):
        th = math.pi * j / M
        sphere(m, dark, (R * math.cos(th), 0.018, 0.8 * R * math.sin(th)), (0.026, 0.02, 0.026), 6, 3)
    return m


def nasi_lemak():
    m = Model()
    box(m, (90, 200, 130), (0, 0.01, 0), (0.56, 0.02, 0.50))
    box(m, (50, 150, 100), (0, 0.021, 0), (0.56, 0.004, 0.012))
    dome(m, (255, 255, 255), (-0.07, 0.02, 0.03), (0.17, 0.15, 0.17), 12, 4)
    for z in (-0.14, -0.04):
        sphere(m, (255, 255, 255), (0.19, 0.045, z), (0.075, 0.035, 0.055), 8, 3)
        sphere(m, (255, 190, 60), (0.19, 0.068, z), (0.035, 0.022, 0.03), 8, 3)
    for x, z in ((0.20, 0.10), (0.14, 0.16), (0.22, 0.18)):
        cyl(m, (60, 160, 110), (x, 0.02, z), 0.055, 0.018, 10)
        cyl(m, (150, 220, 150), (x, 0.038, z), 0.044, 0.004, 10)
    dome(m, (205, 70, 50), (-0.04, 0.02, -0.17), (0.075, 0.04, 0.065), 8, 3)
    dome(m, (232, 100, 60), (-0.04, 0.05, -0.17), (0.04, 0.02, 0.035), 8, 3)
    for i, (x, z, a) in enumerate(((-0.10, -0.205, 0.3), (-0.06, -0.21, -0.2), (-0.01, -0.205, 0.5),
                                   (0.03, -0.20, -0.4), (0.07, -0.19, 0.1))):
        sphere(m, (120, 75, 55), (x, 0.03, z), (0.035, 0.008, 0.01), 6, 3, ry=a)
    for x, z in ((0.05, -0.12), (0.09, -0.15), (0.06, -0.16), (0.11, -0.11), (0.03, -0.14), (0.08, -0.09)):
        sphere(m, (220, 170, 120), (x, 0.032, z), (0.016, 0.014, 0.014), 6, 3)
    return m


def lay(m, prof, rgb, off, seg=8, ry=0):
    lathe(m, prof, seg, rgb, off, ry=ry, rz=-math.pi / 2)


def disc(m, rgb, off, r, h=0.012, seg=8):
    cyl(m, rgb, off, r, h, seg)


def bowl(m, rgb, off=(0, 0, 0), k=1.0):
    prof = [(0, 0), (0.05, 0), (0.08, 0.015), (0.11, 0.065), (0.104, 0.072), (0.097, 0.066), (0.074, 0.026), (0, 0.026)]
    lathe(m, prof, 12, rgb, off, s=(k, k, k))


def scatter(seed, n, rx, rz, gap=0.0):
    rnd = random.Random(seed)
    pts = []
    tries = 0
    while len(pts) < n and tries < 2000:
        tries += 1
        p = (rnd.uniform(-rx, rx), rnd.uniform(-rz, rz))
        if all((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 >= gap * gap for q in pts):
            pts.append(p)
    return pts


def chilli(state):
    m = Model()
    red, green = (215, 40, 35), (80, 150, 60)
    if state == "raw":
        body = [(0, -0.1), (0.008, -0.09), (0.02, -0.04), (0.028, 0.03), (0.027, 0.08), (0, 0.09)]
        stem = [(0, 0.085), (0.014, 0.09), (0.01, 0.12), (0, 0.128)]
        for z, ry, k in ((0.03, 0.25, 1.0), (-0.035, -0.2, 0.85)):
            lay(m, [(r * k, y * k) for r, y in body], red, (0, 0.028, z), ry=ry)
            lay(m, [(r * k, y * k) for r, y in stem], green, (0, 0.028, z), ry=ry)
    else:
        for i, (x, z) in enumerate(scatter(1, 8, 0.12, 0.05, 0.05)):
            disc(m, red, (x, 0, z), 0.026, 0.012)
            disc(m, (250, 225, 130), (x, 0.012, z), 0.016, 0.003)
    return m


def shallot(state):
    m = Model()
    prof = [(0, 0), (0.05, 0.008), (0.075, 0.04), (0.07, 0.085), (0.04, 0.125), (0.012, 0.15), (0, 0.155)]
    if state == "raw":
        for x, z, k in ((-0.05, 0.0, 1.0), (0.06, 0.03, 0.85)):
            lathe(m, prof, 8, (170, 80, 120), (x, 0, z), s=(k, k, k))
            cyl(m, (150, 110, 80), (x, -0.008, z), 0.014 * k, 0.012, 6)
    else:
        for i, (x, z) in enumerate(scatter(2, 10, 0.07, 0.07, 0.035)):
            box(m, (200, 120, 150) if i % 2 else (240, 200, 215), (x, 0.015, z), (0.03, 0.03, 0.03), ry=i)
    return m


def garlic(state):
    m = Model()
    if state == "raw":
        prof = [(0, 0), (0.04, 0.005), (0.075, 0.04), (0.07, 0.08), (0.03, 0.115), (0.008, 0.14), (0, 0.14)]
        for x, z, k in ((-0.05, 0.0, 1.0), (0.07, 0.03, 0.8)):
            lathe(m, prof, 6, (245, 238, 220), (x, 0, z), s=(k, k, k))
            cyl(m, (150, 110, 80), (x, -0.006, z), 0.012 * k, 0.01, 6)
    else:
        for i, (x, z) in enumerate(scatter(3, 12, 0.07, 0.06, 0.03)):
            box(m, (250, 240, 200), (x, 0.01, z), (0.02, 0.02, 0.02), ry=i)
    return m


def ginger(state):
    m = Model()
    if state == "raw":
        for off, sz in (((0, 0.04, 0), (0.10, 0.045, 0.05)), ((0.09, 0.04, 0.02), (0.05, 0.035, 0.04)),
                        ((-0.08, 0.035, -0.02), (0.045, 0.03, 0.04)), ((0.03, 0.05, -0.05), (0.04, 0.03, 0.03))):
            sphere(m, (205, 160, 95), off, sz, 7, 3)
    else:
        for i in range(6):
            x = -0.10 + i * 0.04
            sphere(m, (205, 160, 95), (x, 0.012, (i % 2) * 0.02), (0.045, 0.011, 0.036), 7, 2)
            sphere(m, (240, 210, 120), (x, 0.021, (i % 2) * 0.02), (0.036, 0.004, 0.028), 7, 2)
    return m


def lemongrass(state):
    m = Model()
    pale, green = (225, 225, 150), (140, 190, 80)
    if state == "raw":
        for ry, z in ((0.0, 0.0), (0.3, 0.04), (-0.3, -0.04)):
            lay(m, [(0, -0.15), (0.018, -0.14), (0.016, -0.05)], pale, (0, 0.02, z), ry=ry)
            lay(m, [(0.016, -0.05), (0.012, 0.1), (0.003, 0.15), (0, 0.15)], green, (0, 0.02, z), ry=ry)
    else:
        for i in range(8):
            lay(m, [(0.017, -0.012), (0.017, 0.012)], pale if i < 5 else green, (-0.12 + i * 0.034, 0.017, (i % 3 - 1) * 0.02))
    return m


def cucumber(state):
    m = Model()
    if state == "raw":
        lay(m, [(0, -0.11), (0.025, -0.105), (0.033, -0.09), (0.033, 0.09), (0.025, 0.105), (0, 0.11)],
            (80, 160, 70), (0, 0.033, 0))
        lay(m, [(0, -0.112), (0.02, -0.11)], (200, 230, 160), (0, 0.033, 0))
    else:
        for i in range(6):
            x, z = -0.07 + (i % 3) * 0.07, -0.04 + (i // 3) * 0.08
            disc(m, (80, 160, 70), (x, 0, z), 0.033, 0.014, 10)
            disc(m, (210, 235, 170), (x, 0.014, z), 0.026, 0.002, 10)
    return m


def long_bean(state):
    m = Model()
    green = (70, 170, 60)
    if state == "raw":
        for ry, z in ((0.0, 0.0), (0.25, 0.04), (-0.2, -0.04)):
            lay(m, [(0, -0.15), (0.009, -0.14), (0.009, 0.14), (0, 0.15)], green, (0, 0.01, z), 6, ry=ry)
    else:
        for i, (x, z) in enumerate(scatter(4, 10, 0.1, 0.07, 0.035)):
            lay(m, [(0, -0.02), (0.009, -0.018), (0.009, 0.018), (0, 0.02)], green, (x, 0.01, z), 6, ry=i * 0.7)
    return m


def kangkung(state):
    m = Model()
    stem, leaf = (170, 215, 120), (60, 150, 70)
    if state == "raw":
        for i, ry in enumerate((-0.45, -0.15, 0.15, 0.45)):
            lay(m, [(0.008, -0.09), (0.008, 0.09)], stem, (0, 0.012, 0.0), 6, ry=ry)
            ex, ez = 0.09 * math.cos(-ry), 0.09 * math.sin(-ry)
            for d in (0.0, 0.035):
                sphere(m, leaf, (ex * 1.0 + 0.03 * math.cos(-ry) * (1 + d * 10) * 0.3, 0.02, ez + 0.03 * math.sin(-ry) * (1 + d * 10) * 0.3 + d * 0.3), (0.04, 0.006, 0.03), 6, 2)
    else:
        for i, (x, z) in enumerate(scatter(5, 5, 0.09, 0.06, 0.04)):
            lay(m, [(0.008, -0.02), (0.008, 0.02)], stem, (x, 0.01, z), 6, ry=i)
        for i, (x, z) in enumerate(scatter(6, 4, 0.09, 0.06, 0.04)):
            sphere(m, leaf, (x + 0.01, 0.014, z + 0.05), (0.03, 0.006, 0.022), 6, 2, ry=i)
    return m


def chicken(state):
    m = Model()
    if state == "raw":
        pink = (235, 165, 150)
        sphere(m, pink, (-0.035, 0.055, 0), (0.07, 0.055, 0.055), 8, 4)
        lay(m, [(0, -0.01), (0.04, 0.0), (0.03, 0.04), (0.014, 0.1), (0, 0.105)], pink, (0.0, 0.04, 0), 8)
        lay(m, [(0.011, 0.1), (0.011, 0.14)], (245, 240, 225), (0, 0.04, 0), 6)
        sphere(m, (245, 240, 225), (0.147, 0.04, 0.008), (0.016, 0.014, 0.014), 6, 3)
        sphere(m, (245, 240, 225), (0.147, 0.04, -0.008), (0.016, 0.014, 0.014), 6, 3)
    else:
        a, b = ((235, 165, 150), (250, 200, 185)) if state == "chopped" else ((190, 115, 55), (150, 85, 40))
        for i, (x, z) in enumerate(scatter(7, 6, 0.09, 0.07, 0.06)):
            box(m, a, (x, 0.025, z), (0.05, 0.05, 0.045), ry=i * 0.8)
            box(m, b, (x, 0.052, z), (0.034, 0.008, 0.03), ry=i * 0.8)
    return m


def prawn(state):
    m = Model()
    body, shell = ((225, 190, 185), (200, 160, 160)) if state == "raw" else ((245, 115, 70), (215, 80, 45))
    R = 0.08
    for i in range(7):
        a = 0.15 + i * 0.4
        k = 0.036 - i * 0.0025
        sphere(m, body if i % 2 else shell, (R * math.cos(a), 0.036, R * math.sin(a)), (k, k, k), 7, 3)
    ae = 0.15 + 6 * 0.4
    for d in (-0.3, 0.3):
        sphere(m, shell, (R * math.cos(ae) - 0.02, 0.03, R * math.sin(ae) + d * 0.1), (0.014, 0.004, 0.025), 6, 2, ry=d)
    hx, hz = R * math.cos(0.15), R * math.sin(0.15)
    sphere(m, shell, (hx + 0.045, 0.04, hz - 0.01), (0.04, 0.04, 0.033), 7, 3)
    for d in (-0.012, 0.012):
        sphere(m, (30, 30, 30), (hx + 0.07, 0.05, hz - 0.01 + d), (0.006, 0.006, 0.006), 4, 2)
        lay(m, [(0.002, 0.0), (0.002, 0.1)], shell, (hx + 0.075, 0.045, hz - 0.01 + d * 1.5), 4, ry=d * 8)
    return m


def anchovy(state):
    m = Model()
    body, belly = ((170, 190, 205), (225, 235, 240)) if state == "raw" else ((215, 150, 60), (235, 190, 100))
    for i, (x, z) in enumerate(scatter(8, 6, 0.08, 0.07, 0.065)):
        ry = i * 0.9
        c, s = math.cos(ry), math.sin(ry)
        sphere(m, body, (x, 0.012, z), (0.05, 0.014, 0.016), 7, 3, ry=ry)
        sphere(m, belly, (x, 0.008, z), (0.045, 0.008, 0.014), 7, 2, ry=ry)
        sphere(m, body, (x - 0.055 * c, 0.012, z + 0.055 * s), (0.014, 0.008, 0.02), 6, 2, ry=ry)
        sphere(m, (20, 20, 20), (x + 0.036 * c, 0.022, z - 0.036 * s + 0.004), (0.005, 0.005, 0.005), 4, 2)
    return m


def peanut(state):
    m = Model()
    cols = ((225, 185, 120), (240, 210, 150)) if state == "raw" else ((170, 100, 50), (195, 130, 70))
    for i, (x, z) in enumerate(scatter(9, 9, 0.08, 0.07, 0.05)):
        ry = i * 0.7
        c, s = math.cos(ry), math.sin(ry)
        for d, k in ((-0.016, 1.0), (0.016, 0.85)):
            sphere(m, cols[i % 2], (x + d * c, 0.016, z - d * s), (0.022 * k, 0.016 * k, 0.016 * k), 7, 3, ry=ry)
    return m


def rice(state):
    m = Model()
    bowl(m, (160, 110, 70))
    if state == "raw":
        dome(m, (235, 225, 200), (0, 0.026, 0), (0.09, 0.03, 0.09), 10, 3)
    else:
        dome(m, (255, 255, 255), (0, 0.026, 0), (0.105, 0.085, 0.105), 12, 4)
        for x, z in ((0.03, 0.02), (-0.04, 0.0), (0.0, -0.04)):
            sphere(m, (245, 245, 240), (x, 0.1, z), (0.016, 0.01, 0.012), 5, 2)
    return m


def noodles(state):
    m = Model()
    if state == "raw":
        for i in range(6):
            box(m, (245, 220, 130), (0, 0.016, -0.075 + i * 0.03), (0.22, 0.028, 0.026), ry=0.04 * (i - 3))
        box(m, (200, 50, 45), (0, 0.032, 0), (0.05, 0.004, 0.2))
    else:
        for layer in range(3):
            R = 0.09 - layer * 0.02
            for j in range(10):
                a = 2 * math.pi * j / 10 + layer
                sphere(m, (250, 200, 90) if (j + layer) % 2 else (240, 175, 70),
                       (R * math.cos(a), 0.02 + layer * 0.03, R * math.sin(a)), (0.035, 0.02, 0.025), 6, 3, ry=-a + math.pi / 2)
        disc(m, (250, 200, 90), (0, 0.07, 0), 0.04, 0.02, 8)
        for x, z in ((0.0, 0.03), (-0.02, -0.02)):
            sphere(m, (110, 180, 80), (x, 0.095, z), (0.02, 0.006, 0.012), 5, 2)
    return m


def tofu(state):
    m = Model()
    if state == "raw":
        box(m, (245, 235, 190), (0, 0.03, 0), (0.14, 0.06, 0.10))
    else:
        a, b = ((245, 235, 190), (250, 245, 215)) if state == "chopped" else ((225, 170, 70), (190, 120, 45))
        for i in range(6):
            x, z = -0.065 + (i % 3) * 0.065, -0.035 + (i // 3) * 0.07
            box(m, a, (x, 0.02, z), (0.05, 0.04, 0.05), ry=0.1 * i)
            box(m, b, (x, 0.0405, z), (0.036, 0.003, 0.036), ry=0.1 * i)
    return m


def batter(state):
    m = Model()
    bowl(m, (110, 160, 200))
    if state == "raw":
        dome(m, (255, 255, 255), (-0.025, 0.026, 0.0), (0.055, 0.04, 0.055), 10, 3)
        sphere(m, (255, 190, 60), (0.035, 0.036, 0.02), (0.03, 0.016, 0.03), 8, 3)
        sphere(m, (255, 255, 255), (0.035, 0.03, 0.02), (0.04, 0.008, 0.04), 8, 2)
    else:
        disc(m, (250, 235, 180), (0, 0.04, 0), 0.085, 0.006, 12)
        disc(m, (255, 250, 225), (0, 0.046, 0), 0.04, 0.002, 12)
        sphere(m, (255, 250, 225), (0.0, 0.047, 0.0), (0.075, 0.004, 0.012), 8, 2, ry=0.6)
    return m


def sambal(state):
    m = Model()
    bowl(m, (200, 190, 175))
    if state == "raw":
        for i, (x, z) in enumerate(scatter(10, 11, 0.07, 0.07, 0.04)):
            rgb = ((215, 40, 35), (170, 80, 120), (250, 240, 200))[i % 3]
            box(m, rgb, (x, 0.04, z), (0.03, 0.025, 0.03), ry=i)
    else:
        disc(m, (205, 60, 40), (0, 0.04, 0), 0.085, 0.008, 12)
        sphere(m, (170, 40, 30), (0, 0.049, 0), (0.07, 0.004, 0.012), 8, 2, ry=0.4)
        for x, z in ((0.03, 0.02), (-0.04, -0.01), (0.01, -0.05)):
            sphere(m, (250, 225, 130), (x, 0.05, z), (0.006, 0.003, 0.006), 4, 2)
    return m


INGREDIENTS = {
    "chilli": (chilli, ("raw", "chopped")),
    "shallot": (shallot, ("raw", "chopped")),
    "garlic": (garlic, ("raw", "chopped")),
    "ginger": (ginger, ("raw", "chopped")),
    "lemongrass": (lemongrass, ("raw", "chopped")),
    "cucumber": (cucumber, ("raw", "chopped")),
    "long-bean": (long_bean, ("raw", "chopped")),
    "kangkung": (kangkung, ("raw", "chopped")),
    "chicken": (chicken, ("raw", "chopped", "cooked")),
    "prawn": (prawn, ("raw", "cooked")),
    "anchovy": (anchovy, ("raw", "cooked")),
    "peanut": (peanut, ("raw", "cooked")),
    "rice": (rice, ("raw", "cooked")),
    "noodles": (noodles, ("raw", "cooked")),
    "tofu": (tofu, ("raw", "chopped", "cooked")),
    "batter": (batter, ("raw", "mixed")),
    "sambal": (sambal, ("raw", "mixed")),
}

def counter():
    m = Model()
    box(m, (150, 105, 70), (0, 0.4, 0), (1.0, 0.8, 1.0))
    box(m, (205, 205, 210), (0, 0.84, 0), (1.04, 0.08, 1.04))
    box(m, (110, 75, 50), (0, 0.4, 0.502), (0.8, 0.5, 0.01))
    return m


def stove():
    m = Model()
    box(m, (70, 70, 80), (0, 0.4, 0), (1.0, 0.8, 1.0))
    box(m, (35, 35, 40), (0, 0.84, 0), (1.04, 0.08, 1.04))
    for x in (-0.22, 0.22):
        cyl(m, (200, 60, 40), (x, 0.88, -0.1), 0.17, 0.012, 12)
        cyl(m, (60, 60, 65), (x, 0.892, -0.1), 0.1, 0.012, 12)
    for x in (-0.3, 0, 0.3):
        cyl(m, (230, 230, 230), (x, 0.6, 0.51), 0.04, 0.03, 8)
    return m


def wok():
    m = Model()
    prof = [(0, 0), (0.07, 0), (0.15, 0.03), (0.21, 0.09), (0.24, 0.17), (0.232, 0.17), (0.2, 0.1), (0.14, 0.05), (0, 0.025)]
    lathe(m, prof, 14, (60, 60, 68), (0, 0, 0))
    lay(m, [(0.014, 0), (0.014, 0.25), (0.018, 0.27), (0, 0.27)], (110, 75, 50), (0.24, 0.17, 0), 6)
    return m


def sink():
    m = Model()
    box(m, (150, 105, 70), (0, 0.4, 0), (1.0, 0.8, 1.0))
    box(m, (205, 205, 210), (0, 0.84, 0), (1.04, 0.08, 1.04))
    box(m, (90, 150, 200), (0, 0.885, 0), (0.7, 0.01, 0.6))
    cyl(m, (200, 205, 215), (0, 0.89, -0.4), 0.03, 0.2, 8)
    lay(m, [(0.025, 0), (0.025, 0.14)], (200, 205, 215), (0, 1.09, -0.33), 8, ry=math.pi / 2)
    return m


def bin_():
    m = Model()
    prof = [(0, 0), (0.18, 0), (0.22, 0.5), (0.23, 0.5), (0.23, 0.52), (0.2, 0.52), (0.2, 0.49)]
    lathe(m, prof, 10, (90, 100, 110), (0, 0, 0))
    cyl(m, (60, 65, 70), (0, 0.5, 0), 0.19, 0.01, 10)
    return m


def rice_cooker():
    m = Model()
    lathe(m, [(0, 0), (0.2, 0), (0.24, 0.05), (0.24, 0.22), (0.2, 0.3), (0.08, 0.34), (0, 0.34)], 12, (250, 245, 235), (0, 0, 0))
    cyl(m, (200, 70, 60), (0, 0.34, 0), 0.025, 0.03, 6)
    box(m, (200, 70, 60), (0, 0.12, 0.235), (0.1, 0.05, 0.02))
    cyl(m, (60, 60, 65), (0, 0.0, 0), 0.19, 0.015, 12)
    return m


def hatch():
    m = Model()
    box(m, (150, 105, 70), (0, 0.4, 0), (1.0, 0.8, 1.0))
    box(m, (215, 190, 130), (0, 0.84, 0), (1.04, 0.08, 1.04))
    for x in (-0.46, 0.46):
        box(m, (200, 60, 50), (x, 1.2, 0), (0.06, 0.7, 0.06))
    box(m, (200, 60, 50), (0, 1.55, 0), (1.0, 0.08, 0.9))
    for i in range(5):
        box(m, (250, 235, 200) if i % 2 else (200, 60, 50), (-0.4 + i * 0.2, 1.48, 0.45), (0.2, 0.12, 0.02))
    return m


def mixing_bowl():
    m = Model()
    prof = [(0, 0), (0.07, 0), (0.14, 0.03), (0.2, 0.12), (0.21, 0.17), (0.2, 0.17), (0.19, 0.12), (0.13, 0.06), (0, 0.04)]
    lathe(m, prof, 14, (110, 160, 200), (0, 0, 0))
    return m


def teh_glass():
    m = Model()
    lathe(m, [(0, 0), (0.05, 0), (0.07, 0.02), (0.08, 0.2), (0.073, 0.2), (0.063, 0.03), (0, 0.025)], 12, (200, 225, 235), (0, 0, 0))
    return m


def teh_tarik():
    m = Model()
    lathe(m, [(0, 0), (0.05, 0), (0.07, 0.02), (0.08, 0.2), (0.073, 0.2), (0.063, 0.03), (0, 0.025)], 12, (200, 225, 235), (0, 0, 0))
    lathe(m, [(0, 0.03), (0.062, 0.03), (0.072, 0.15), (0, 0.15)], 12, (170, 110, 60), (0, 0, 0))
    lathe(m, [(0, 0.15), (0.072, 0.15), (0.07, 0.185), (0.04, 0.2), (0, 0.2)], 12, (250, 235, 205), (0, 0, 0))
    return m


def kettle():
    m = Model()
    lathe(m, [(0, 0), (0.14, 0), (0.17, 0.05), (0.17, 0.2), (0.12, 0.28), (0.05, 0.3), (0, 0.3)], 12, (200, 205, 215), (0, 0, 0))
    cyl(m, (60, 60, 65), (0, 0.3, 0), 0.03, 0.04, 6)
    lay(m, [(0.025, 0), (0.02, 0.08), (0.012, 0.13)], (200, 205, 215), (0.15, 0.14, 0), 6, ry=0)
    lay(m, [(0.012, 0), (0.012, 0.2)], (60, 60, 65), (-0.17, 0.1, 0), 6)
    return m


KITCHEN = {"counter": counter, "stove": stove, "wok": wok, "sink": sink, "bin": bin_,
           "rice-cooker": rice_cooker, "serving-hatch": hatch, "mixing-bowl": mixing_bowl,
           "teh-glass": teh_glass, "teh-tarik": teh_tarik, "kettle": kettle}


def write_glb(m, path, png):
    m.recenter()
    n = len(m.P)
    pos = b"".join(struct.pack("<3f", *p) for p in m.P)
    nor = b"".join(struct.pack("<3f", *p) for p in m.N)
    uvb = b"".join(struct.pack("<2f", *p) for p in m.T)
    idx = struct.pack("<%dH" % n, *range(n)) if n < 65536 else struct.pack("<%dI" % n, *range(n))
    pad = lambda b: b + b"\x00" * (-len(b) % 4)
    parts = [pos, nor, uvb, pad(idx), pad(png)]
    views, off = [], 0
    for b, tgt in zip(parts, (34962, 34962, 34962, 34963, None)):
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(b)}
        if tgt:
            v["target"] = tgt
        views.append(v)
        off += len(b)
    views[3]["byteLength"] = len(idx)
    views[4]["byteLength"] = len(png)
    mn = [min(p[i] for p in m.P) for i in range(3)]
    mx = [max(p[i] for p in m.P) for i in range(3)]
    name = os.path.splitext(os.path.basename(path))[0]
    j = {
        "asset": {"version": "2.0", "generator": "make_food_models.py"},
        "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0, "name": name}],
        "meshes": [{"name": name, "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
                                                  "indices": 3, "material": 0}]}],
        "materials": [{"name": "colormap", "doubleSided": True,
                       "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0,
                                                "roughnessFactor": 1.0}}],
        "textures": [{"source": 0, "sampler": 0}],
        "samplers": [{"magFilter": 9729, "minFilter": 9729, "wrapS": 33071, "wrapT": 33071}],
        "images": [{"bufferView": 4, "mimeType": "image/png"}],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": n, "type": "VEC3", "min": mn, "max": mx},
            {"bufferView": 1, "componentType": 5126, "count": n, "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": n, "type": "VEC2"},
            {"bufferView": 3, "componentType": 5123 if n < 65536 else 5125, "count": n, "type": "SCALAR"}],
        "bufferViews": views, "buffers": [{"byteLength": off}],
    }
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    binb = b"".join(parts)
    total = 12 + 8 + len(js) + 8 + len(binb)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON") + js)
        f.write(struct.pack("<I4s", len(binb), b"BIN\x00") + binb)
    print(name, n // 3, "tris,", total, "bytes")


os.makedirs(OUT_DIR, exist_ok=True)
png = open(TEX_PATH, "rb").read()
if len(sys.argv) > 3 and sys.argv[3] == "ingredients":
    for name, (build, states) in INGREDIENTS.items():
        for st in states:
            write_glb(build(st), os.path.join(OUT_DIR, "%s-%s.glb" % (name, st)), png)
elif len(sys.argv) > 3 and sys.argv[3] == "kitchen":
    for name, build in KITCHEN.items():
        write_glb(build(), os.path.join(OUT_DIR, name + ".glb"), png)
else:
    for fn, build in (("roti-jala", roti_jala), ("karipap", karipap), ("nasi-lemak", nasi_lemak)):
        write_glb(build(), os.path.join(OUT_DIR, fn + ".glb"), png)
