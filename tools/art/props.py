"""Objetos del mundo: vegetación, casa, mobiliario exterior y efectos.

Reglas: luz desde arriba-izquierda, contorno = tono más oscuro de la rampa del
material, sombras proyectadas violeta semitransparente. El origen de cada sprite
(sus pies) es el centro inferior de la imagen; el juego lo alinea con la base
de la huella del objeto.
"""
import math
import numpy as np
from PIL import Image
from palette import ramp, SHADOW, CLEAR
from pix import Canvas, BAYER4, rng, save


# ------------------------------------------------------------ copas (volumen)
def shade_blobs(w, h, blobs, tones, seed, light=(-0.55, -0.75, 0.6), outline=True, speckle=0.06):
    """Dibuja un volumen formado por esferas. blobs: (cx, cy, r)."""
    L = np.array(light)
    L = L / np.linalg.norm(L)
    r_ = rng(seed)
    c = Canvas(w, h)
    height = np.full((h, w), -1.0)
    shade = np.zeros((h, w))
    for (cx, cy, rad) in blobs:
        for y in range(max(0, int(cy - rad - 1)), min(h, int(cy + rad + 2))):
            for x in range(max(0, int(cx - rad - 1)), min(w, int(cx + rad + 2))):
                dx, dy = (x + 0.5 - cx) / rad, (y + 0.5 - cy) / rad
                d2 = dx * dx + dy * dy
                if d2 <= 1:
                    z = math.sqrt(1 - d2)
                    hz = z * rad + (h - cy) * 0.15  # las esferas más bajas quedan detrás
                    if hz > height[y, x]:
                        height[y, x] = hz
                        n = np.array([dx, dy, z])
                        shade[y, x] = max(0.0, float(n @ L))
    n_t = len(tones)
    for y in range(h):
        for x in range(w):
            if height[y, x] < 0:
                continue
            v = shade[y, x] * 0.85 + 0.12
            # oclusión: zonas bajas de la copa más oscuras
            v -= max(0, (y / h) - 0.55) * 0.5
            lv = v * (n_t - 2) + 1
            base = int(lv)
            if lv - base > BAYER4[y % 4][x % 4]:
                base += 1
            base = max(1, min(n_t - 1, base))
            c.put(x, y, tones[base])
    # bordes internos entre esferas (sensación de racimos de hojas)
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if height[y, x] >= 0 and height[y - 1, x] >= 0:
                if height[y - 1, x] - height[y, x] > 2.2:
                    c.put(x, y, tones[1])
    for _ in range(int(w * h * speckle)):
        x, y = r_.randrange(w), r_.randrange(h)
        if height[y, x] >= 0 and shade[y, x] > 0.55:
            c.put(x, y, tones[-1])
            if y + 1 < h and height[y + 1, x] >= 0:
                c.put(x, y + 1, tones[-2])
    if outline:
        c.outline(tones[0])
    return c


def drop_shadow(c, cx, cy, rx, ry):
    for y in range(c.h):
        for x in range(c.w):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                if not c.opaque(x, y):
                    c.put(x, y, SHADOW)


def trunk(c, x0, y0, hgt, wd, tones):
    for y in range(y0, y0 + hgt):
        flare = 1 if y > y0 + hgt - 3 else 0
        for x in range(x0 - flare, x0 + wd + flare):
            t = 3 if x == x0 else (1 if x >= x0 + wd - 1 else 2)
            c.put(x, y, tones[t])
        c.put(x0 - 1 - flare, y, tones[0])
        c.put(x0 + wd + flare, y, tones[0])
    c.hline(x0 - 2, x0 + wd + 1, y0 + hgt, tones[0])


def tree_oak(seed=1, leaf="leaf"):
    w, h = 40, 52
    c = Canvas(w, h)
    drop_shadow(c, 20, 48, 13, 3.5)
    trunk(c, 17, 30, 18, 6, ramp("wood"))
    r = rng(seed)
    blobs = [(20, 18, 12), (12, 22, 8.5), (28, 22, 8.5), (16, 12, 8), (25, 11, 8), (20, 26, 9)]
    blobs = [(x + r.uniform(-1, 1), y + r.uniform(-1, 1), rad) for x, y, rad in blobs]
    canopy = shade_blobs(w, 36, blobs, ramp(leaf), seed)
    c.blit(canopy, 0, 0)
    return c


def tree_blossom(seed=3):
    w, h = 40, 52
    c = Canvas(w, h)
    drop_shadow(c, 20, 48, 13, 3.5)
    trunk(c, 18, 30, 18, 5, ramp("wood"))
    # ramas visibles
    wd = ramp("wood")
    for i in range(5):
        c.put(16 - i, 30 - i, wd[1])
        c.put(23 + i, 30 - i, wd[1])
    blobs = [(20, 17, 11), (11, 21, 8), (29, 21, 8), (15, 11, 7.5), (26, 10, 7.5), (20, 24, 8)]
    canopy = shade_blobs(w, 36, blobs, ramp("blossom"), seed, speckle=0.09)
    c.blit(canopy, 0, 0)
    return c


def tree_pine(seed=5):
    w, h = 32, 56
    c = Canvas(w, h)
    drop_shadow(c, 16, 52, 10, 3)
    trunk(c, 14, 40, 12, 4, ramp("wood"))
    tones = ramp("leaf_teal")
    layers = [(16, 10, 5), (16, 17, 8), (16, 25, 11), (16, 33, 14)]
    body = Canvas(w, 46)
    for i, (cx, top, half) in enumerate(reversed(layers)):
        hgt = 11
        for y in range(hgt):
            span = half * (y + 2) / (hgt + 1)
            for x in range(int(cx - span), int(cx + span) + 1):
                yy = top - 6 + y
                rel = (x - cx) / max(1, span)
                v = 0.65 - rel * 0.45 - y / hgt * 0.35
                lv = v * (len(tones) - 2) + 1
                b = int(lv) + (1 if lv - int(lv) > BAYER4[yy % 4][x % 4] else 0)
                b = max(1, min(len(tones) - 1, b))
                if y == hgt - 1 and (x % 3 == 0):
                    b = 1
                body.put(x, yy, tones[b])
    body.put(16, 2, tones[3])
    body.put(16, 3, tones[3])
    body.outline(tones[0])
    c.blit(body, 0, 0)
    return c


def tree_palm(seed=9):
    w, h = 40, 56
    c = Canvas(w, h)
    drop_shadow(c, 20, 52, 9, 2.5)
    wd = ramp("wood_light")
    # tronco curvo segmentado
    for y in range(18, 52):
        x = 18 + int(3 * math.sin((y - 18) / 34 * 1.6))
        for dx in range(4):
            t = 3 if dx == 0 else (1 if dx == 3 else 2)
            if (y % 4) == 0:
                t = max(0, t - 1)
            c.put(x + dx, y, wd[t])
        c.put(x - 1, y, wd[0])
        c.put(x + 4, y, wd[0])
    tones = ramp("leaf")
    fronds = Canvas(w, 30)
    for ang in [-160, -120, -60, -20, 20, 160, -90]:
        a = math.radians(ang)
        for t in range(0, 17):
            x = 20 + math.cos(a) * t
            y = 16 + math.sin(a) * t * 0.6 + (t / 16) ** 2 * 7
            for k in range(-1, 2):
                wdt = max(0, 2 - t // 7)
                if abs(k) <= wdt:
                    fronds.put(int(x), int(y + k), tones[3 if k < 0 else 2])
    fronds.outline(tones[0])
    c.blit(fronds, 0, 2)
    return c


def bush(seed=11, berries=False):
    w, h = 20, 18
    c = Canvas(w, h)
    drop_shadow(c, 10, 15, 8, 2.5)
    blobs = [(10, 9, 6.5), (5.5, 11, 4.5), (14.5, 11, 4.5), (10, 5.5, 4.5)]
    b = shade_blobs(w, 16, blobs, ramp("leaf"), seed, speckle=0.05)
    c.blit(b, 0, 0)
    if berries:
        fr = ramp("flower_red")
        r = rng(seed)
        for _ in range(7):
            x, y = r.randrange(4, 16), r.randrange(4, 13)
            if c.opaque(x, y):
                c.put(x, y, fr[2])
                c.put(x, y - 1, fr[3])
    return c


def flower_clump(name, seed):
    f = ramp(name)
    g = ramp("leaf")
    c = Canvas(16, 16)
    r = rng(seed)
    pts = [(4, 9), (8, 6), (11, 10), (7, 11), (12, 6)]
    for x, y in pts:  # tallos y hojas
        c.vline(x, y + 1, 14, g[2])
        c.put(x - 1, 12, g[3])
        c.put(x + 1, 13, g[2])
    for x, y in pts:  # corolas de 3x3 con centro
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            c.put(x + dx, y + dy, f[2])
        c.put(x - 1, y - 1, f[3])
        c.put(x, y, ramp("flower_yellow")[3] if name != "flower_yellow" else ramp("flower_orange")[2])
        c.put(x + 1, y + 1, f[1])
    c.outline((f[0][0], f[0][1], f[0][2], 255))
    return c


def grass_tuft(seed):
    g = ramp("grass")
    c = Canvas(12, 10)
    r = rng(seed)
    for i, x in enumerate([2, 4, 5, 7, 9]):
        hgt = r.randrange(4, 8)
        lean = r.choice([-1, 0, 1])
        for t in range(hgt):
            xx = x + (lean if t > hgt * 0.6 else 0)
            c.put(xx, 9 - t, g[4] if t > hgt - 2 else (g[3] if t > 1 else g[2]))
    return c


def wildflowers(seed):
    c = grass_tuft(seed)
    r = rng(seed)
    cols = [ramp("flower_white")[3], ramp("flower_yellow")[2], ramp("flower_lilac")[3]]
    for _ in range(3):
        x, y = r.randrange(2, 10), r.randrange(1, 5)
        c.put(x, y, r.choice(cols))
    return c


def reeds(seed):
    g = ramp("grass")
    d = ramp("dirt")
    c = Canvas(14, 22)
    r = rng(seed)
    for x in [2, 4, 6, 8, 10, 11]:
        hgt = r.randrange(12, 20)
        for t in range(hgt):
            c.put(x + (1 if t > hgt * 0.7 and x % 4 == 0 else 0), 21 - t, g[3] if t > 4 else g[2])
        if r.random() < 0.6:  # espadañas
            for k in range(3):
                c.put(x, 21 - hgt + k, d[2])
            c.put(x, 21 - hgt - 1, g[4])
    return c


def lily_pad(seed):
    g = ramp("leaf")
    c = Canvas(16, 10)
    for y in range(10):
        for x in range(16):
            if ((x - 7.5) / 6.5) ** 2 + ((y - 5) / 3.5) ** 2 <= 1:
                c.put(x, y, g[3] if y < 5 else g[2])
    for y in range(5, 3, -1):
        c.put(8, y, CLEAR)
        c.put(9, y - 1, CLEAR)
    c.outline(g[1])
    if seed % 2 == 0:
        f = ramp("blossom")
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, -1)):
            c.put(5 + dx, 4 + dy, f[4])
        c.put(5, 3, f[5])
    return c


def rock(big, seed):
    s = ramp("stone")
    w, h = (26, 18) if big else (14, 10)
    c = Canvas(w, h)
    drop_shadow(c, w / 2, h - 2.5, w / 2 - 1, 2.5)
    blobs = [(w * 0.45, h * 0.55, h * 0.42), (w * 0.62, h * 0.62, h * 0.33)] if big else [(w * 0.5, h * 0.55, h * 0.4)]
    b = shade_blobs(w, h - 1, blobs, s, seed, speckle=0.02)
    c.blit(b, 0, 0)
    if big:  # musgo
        g = ramp("grass")
        for x in range(6, 14):
            c.put(x, 4 + (x % 2), g[3])
    return c


def driftwood():
    w = ramp("wood_light")
    c = Canvas(30, 10)
    drop_shadow(c, 15, 8, 13, 2)
    for x in range(2, 28):
        y = 4 + int(math.sin(x / 5) * 1.2)
        c.put(x, y, w[3])
        c.put(x, y + 1, w[2])
        c.put(x, y + 2, w[1])
    c.put(8, 2, w[2])
    c.put(9, 3, w[2])
    c.outline(w[0])
    return c


def shell():
    s = ramp("blossom")
    c = Canvas(8, 6)
    rows = ["..XX....", ".XooX...", "XoOoOX..", "XOoOoX..", ".XXXX..."]
    key = {"X": s[2], "o": s[4], "O": s[5]}
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in key:
                c.put(x + 1, y, key[ch])
    return c


# -------------------------------------------------------------- mobiliario
def fence():
    w = ramp("wood")
    c = Canvas(16, 20)
    for px in (2, 12):
        c.rect(px, 3, 3, 15, w[3])
        c.vline(px, 3, 17, w[4])
        c.vline(px + 2, 3, 17, w[2])
        c.put(px + 1, 2, w[4])
    for ry in (7, 12):
        c.rect(0, ry, 16, 2, w[3])
        c.hline(0, 15, ry, w[4])
        c.hline(0, 15, ry + 2, w[1])
    c.outline(w[0])
    for x in range(1, 16):
        c.put(x, 19, SHADOW)
    return c


def fence_v():
    """Tramo de valla visto de lado (para vallas que van de norte a sur)."""
    w = ramp("wood")
    c = Canvas(16, 24)
    # larguero que une con el tramo de arriba
    c.rect(7, 0, 2, 20, w[3])
    c.vline(7, 0, 19, w[4])
    c.rect(6, 6, 4, 15, w[3])
    c.vline(6, 6, 20, w[4])
    c.vline(9, 6, 20, w[2])
    c.hline(6, 9, 5, w[5])
    c.outline(w[0])
    for x in range(5, 12):
        c.put(x, 23, SHADOW)
    return c


def lamp_post():
    i = ramp("iron")
    l = ramp("light")
    c = Canvas(12, 34)
    c.rect(5, 10, 2, 21, i[2])
    c.vline(5, 10, 30, i[3])
    c.rect(3, 30, 6, 2, i[1])
    # farol
    c.rect(2, 2, 8, 2, i[1])
    c.rect(3, 4, 6, 6, l[2])
    c.vline(3, 4, 9, l[1])
    c.put(5, 5, l[3])
    c.put(6, 5, l[3])
    c.rect(3, 9, 6, 1, i[1])
    c.put(5, 0, i[2])
    c.put(6, 0, i[2])
    c.hline(4, 7, 1, i[2])
    c.outline(i[0])
    for x in range(2, 10):
        c.put(x, 33, SHADOW)
    return c


def bench():
    w = ramp("wood")
    i = ramp("iron")
    c = Canvas(32, 22)
    for x in range(2, 31):
        c.put(x, 20, SHADOW)
        c.put(x, 21, SHADOW)
    # respaldo
    for ry in (3, 7):
        c.rect(2, ry, 28, 3, w[3])
        c.hline(2, 29, ry, w[4])
        c.hline(2, 29, ry + 2, w[2])
    # asiento
    c.rect(1, 12, 30, 4, w[3])
    c.hline(1, 30, 12, w[5])
    c.hline(1, 30, 15, w[1])
    for lx in (3, 27):
        c.rect(lx, 2, 2, 18, i[2])
        c.vline(lx, 2, 19, i[3])
    c.outline(w[0])
    return c


def mailbox():
    w = ramp("wood")
    m = ramp("roof")
    c = Canvas(14, 28)
    for x in range(2, 12):
        c.put(x, 27, SHADOW)
    c.rect(6, 12, 3, 15, w[3])
    c.vline(6, 12, 26, w[4])
    # caja con tapa redondeada
    c.rect(1, 4, 12, 8, m[3])
    c.hline(2, 11, 3, m[3])
    c.hline(3, 10, 2, m[4])
    c.hline(2, 11, 4, m[4])
    c.rect(1, 10, 12, 2, m[2])
    c.rect(4, 6, 6, 3, m[1])
    c.hline(4, 9, 6, m[0])
    # banderita
    c.vline(12, 1, 7, ramp("flower_yellow")[2])
    c.rect(12, 1, 2, 2, ramp("flower_yellow")[3])
    c.outline(m[0])
    return c


def fountain():
    s = ramp("cobble")
    wt = ramp("water")
    c = Canvas(48, 40)
    for y in range(c.h):
        for x in range(c.w):
            if ((x + 0.5 - 24) / 23) ** 2 + ((y + 0.5 - 30) / 9) ** 2 <= 1:
                c.put(x, y, SHADOW)
    # pileta
    for y in range(16, 38):
        for x in range(2, 46):
            e = ((x + 0.5 - 24) / 21.5) ** 2 + ((y + 0.5 - 26) / 9) ** 2
            if e <= 1:
                c.put(x, y, s[3] if y < 26 else s[2])
            if e <= 0.62 and y < 30:
                c.put(x, y, wt[4] if (x + y) % 7 else wt[5])
    # borde frontal (canto de piedra)
    for x in range(3, 45):
        yb = 26 + int(9 * math.sqrt(max(0, 1 - ((x + 0.5 - 24) / 21.5) ** 2)))
        for k in range(4):
            c.put(x, yb - k, s[2] if k == 0 else s[3] if k < 3 else s[4])
    # columna central y copa
    c.rect(21, 8, 6, 18, s[3])
    c.vline(21, 8, 25, s[4])
    c.vline(26, 8, 25, s[1])
    c.rect(17, 6, 14, 3, s[4])
    c.hline(17, 30, 8, s[2])
    c.rect(22, 2, 4, 4, wt[6])
    c.put(23, 1, wt[7])
    c.outline(s[0])
    return c


def telescope():
    i = ramp("iron")
    b = ramp("light")
    c = Canvas(18, 28)
    for x in range(4, 15):
        c.put(x, 27, SHADOW)
    # trípode
    for t in range(12):
        c.put(9 - t // 3, 15 + t, i[2])
        c.put(9 + t // 3, 15 + t, i[2])
        c.put(9, 15 + t, i[1])
    # tubo de latón
    for t in range(14):
        x, y = 2 + t, 12 - t // 2
        for k in range(3):
            c.put(x, y + k, b[1] if k == 2 else b[2] if k == 1 else b[3])
    c.rect(14, 4, 3, 4, b[0])
    c.outline(i[0])
    return c


def house_cottage():
    """Casa de campo, 6 celdas de ancho. Vista 3/4 (tejado inclinado hacia el espectador)."""
    W, H = 104, 112
    c = Canvas(W, H)
    pl = ramp("plaster")
    wd = ramp("wood")
    rf = ramp("roof")
    st = ramp("stone")
    lt = ramp("light")
    # sombra al pie
    for y in range(H - 8, H):
        for x in range(6, W - 2):
            c.put(x, y, SHADOW)
    wall_top, wall_bot = 58, H - 6
    wx0, wx1 = 8, W - 9
    # zócalo de piedra
    for y in range(wall_bot - 7, wall_bot + 1):
        for x in range(wx0, wx1 + 1):
            row = (y - (wall_bot - 7)) // 4
            brick = ((x + (row % 2) * 4) // 8)
            col = st[3] if (brick + row) % 3 else st[4]
            if (x + (row % 2) * 4) % 8 == 0 or (y - (wall_bot - 7)) % 4 == 3:
                col = st[1]
            c.put(x, y, col)
    # muro de yeso con entramado de madera
    for y in range(wall_top, wall_bot - 7):
        for x in range(wx0, wx1 + 1):
            col = pl[4]
            if (x * 7 + y * 13) % 29 == 0:
                col = pl[3]
            if y < wall_top + 4:
                col = pl[2]  # sombra del alero
            c.put(x, y, col)
    for x in (wx0, wx0 + 30, wx1 - 30, wx1):
        c.rect(x - 1, wall_top, 3, wall_bot - 7 - wall_top, wd[2])
        c.vline(x - 1, wall_top, wall_bot - 8, wd[3])
    c.rect(wx0, wall_top + 18, wx1 - wx0, 3, wd[2])
    c.hline(wx0, wx1, wall_top + 18, wd[3])

    def window(x0, y0):
        c.rect(x0 - 1, y0 - 1, 16, 15, wd[1])
        c.rect(x0, y0, 14, 12, (54, 70, 104, 255))
        for yy in range(y0, y0 + 12):
            for xx in range(x0, x0 + 14):
                if (xx - x0) + (yy - y0) in (3, 4, 11):
                    c.put(xx, yy, (120, 150, 190, 255))  # reflejo
        c.vline(x0 + 7, y0, y0 + 11, wd[3])
        c.hline(x0, x0 + 13, y0 + 6, wd[3])
        c.rect(x0 - 2, y0 + 12, 18, 2, wd[4])  # alféizar
        c.hline(x0 - 2, x0 + 15, y0 + 14, wd[1])
        # jardinera con flores
        c.rect(x0, y0 + 14, 14, 3, wd[2])
        fl = ramp("flower_red")
        for k in range(0, 14, 2):
            c.put(x0 + k, y0 + 13, fl[2] if k % 4 else ramp("flower_yellow")[2])
            c.put(x0 + k + 1, y0 + 13, ramp("leaf")[3])

    window(wx0 + 7, wall_top + 24)
    window(wx1 - 21, wall_top + 24)
    # puerta
    dx0, dw = W // 2 - 8, 16
    c.rect(dx0 - 2, wall_top + 12, dw + 4, wall_bot - wall_top - 12, wd[1])
    for y in range(wall_top + 14, wall_bot):
        for x in range(dx0, dx0 + dw):
            col = wd[3] if (x - dx0) % 4 else wd[2]
            if y < wall_top + 18 and abs(x - (dx0 + dw / 2 - 0.5)) > (y - wall_top - 13) * 2.2:
                col = wd[1]
            c.put(x, y, col)
    c.rect(dx0 + 3, wall_top + 20, 10, 6, (70, 86, 120, 255))
    c.hline(dx0 + 3, dx0 + 12, wall_top + 20, wd[1])
    c.put(dx0 + 12, wall_top + 34, lt[2])  # pomo
    c.put(dx0 + 12, wall_top + 35, lt[0])
    # escalón
    c.rect(dx0 - 4, wall_bot - 1, dw + 8, 3, st[4])
    c.hline(dx0 - 4, dx0 + dw + 3, wall_bot + 1, st[2])
    # farolillo junto a la puerta
    c.rect(dx0 + dw + 4, wall_top + 16, 3, 4, lt[2])
    c.put(dx0 + dw + 5, wall_top + 15, ramp("iron")[1])

    # tejado: tejas en hileras que se solapan, más claras arriba (luz)
    roof_top, roof_bot = 10, wall_top + 4
    for y in range(roof_top, roof_bot):
        t = (y - roof_top) / (roof_bot - roof_top)
        inset = int((1 - t) * 10)
        for x in range(2 + inset, W - 2 - inset):
            row = (y - roof_top) // 6
            within = (y - roof_top) % 6
            shift = 3 if row % 2 else 0
            tile_x = (x + shift) % 6
            tone = 4 if t < 0.3 else 3 if t < 0.75 else 2
            if within == 5:
                tone = 1
            elif within == 0:
                tone = min(5, tone + 1)
            if tile_x == 0 and within < 5:
                tone = max(1, tone - 1)
            if x < 6 + inset or x > W - 7 - inset:
                tone = max(1, tone - 1)
            c.put(x, y, rf[tone])
    # alero (canto inferior grueso y sombra)
    c.rect(0, roof_bot, W, 3, rf[1])
    c.hline(0, W - 1, roof_bot, rf[2])
    c.hline(0, W - 1, roof_bot + 2, rf[0])
    # cumbrera
    c.rect(12, roof_top - 3, W - 24, 4, rf[2])
    c.hline(12, W - 13, roof_top - 3, rf[4])
    # buhardilla con ventana redonda
    bx = W // 2
    for y in range(roof_top + 10, roof_top + 31):
        half = min(12, (y - roof_top - 8) * 1.2)
        for x in range(int(bx - half), int(bx + half)):
            c.put(x, y, (pl[4] if x > bx - half + 1 else pl[3]) if y > roof_top + 16 else rf[3])
    for y in range(roof_top + 6, roof_top + 18):
        half = (y - roof_top - 5) * 1.25
        for x in range(int(bx - half), int(bx + half)):
            c.put(x, y, rf[4] if x < bx else rf[3])
    # ventana redonda con marco de madera y cruz
    wy = roof_top + 23
    for y in range(wy - 6, wy + 6):
        for x in range(bx - 6, bx + 6):
            d2 = (x + 0.5 - bx) ** 2 + (y + 0.5 - wy) ** 2
            if d2 <= 30:
                c.put(x, y, wd[2])
            if d2 <= 18:
                c.put(x, y, (54, 70, 104, 255))
    c.vline(bx, wy - 4, wy + 3, wd[3])
    c.hline(bx - 4, bx + 3, wy, wd[3])
    c.put(bx - 2, wy - 2, (120, 150, 190, 255))
    c.put(bx - 3, wy - 1, (120, 150, 190, 255))
    # jardinera bajo la ventana
    c.rect(bx - 7, roof_top + 30, 14, 2, wd[3])
    for k in range(-6, 7, 2):
        c.put(bx + k, roof_top + 29, ramp("flower_red")[2] if k % 4 else ramp("leaf")[3])
    # chimenea
    cx = W - 30
    c.rect(cx, 0, 10, 22, st[3])
    for y in range(0, 22):
        for x in range(cx, cx + 10):
            if y % 4 == 3 or (x + (y // 4) * 3) % 6 == 0:
                c.put(x, y, st[2])
    c.vline(cx, 0, 21, st[4])
    c.rect(cx - 1, 0, 12, 2, st[4])
    c.outline((40, 22, 34, 255))
    return c


def house_window_glow():
    """Capa de luz cálida de las ventanas (se muestra de noche, aditiva)."""
    W, H = 104, 112
    c = Canvas(W, H)
    l = ramp("light")
    wall_top = 58

    def win(x0, y0, w, h):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                c.put(x, y, l[2] if (x + y) % 5 else l[3])

    win(8 + 7, wall_top + 24, 14, 12)
    win(W - 9 - 21, wall_top + 24, 14, 12)
    win(W // 2 - 5, wall_top + 20, 10, 6)
    for y in range(10 + 17, 10 + 30):
        for x in range(W // 2 - 5, W // 2 + 5):
            if (x + 0.5 - W // 2) ** 2 + (y + 0.5 - 33) ** 2 <= 18 and x != W // 2 and y != 33:
                c.put(x, y, l[2])
    c.rect(W // 2 + 12, wall_top + 16, 3, 4, l[3])
    return c


# -------------------------------------------------------------------- efectos
def radial_light(size=128):
    img = Image.new("RGBA", (size, size))
    for y in range(size):
        for x in range(size):
            d = math.hypot(x + 0.5 - size / 2, y + 0.5 - size / 2) / (size / 2)
            # escalones suaves para que la luz respete la estética pixel
            v = max(0.0, 1 - d)
            v = round(v ** 1.6 * 6) / 6
            a = int(255 * v)
            img.putpixel((x, y), (255, 255, 255, a))
    return img


def soft_particle():
    c = Canvas(3, 3)
    w = (255, 255, 255, 255)
    c.put(1, 0, w)
    c.put(0, 1, w)
    c.put(1, 1, w)
    c.put(2, 1, w)
    c.put(1, 2, w)
    return c


def petal():
    b = ramp("blossom")
    c = Canvas(3, 2)
    c.put(0, 0, b[4])
    c.put(1, 0, b[5])
    c.put(1, 1, b[3])
    c.put(2, 1, b[4])
    return c


def smoke_puff():
    c = Canvas(6, 6)
    for y in range(6):
        for x in range(6):
            if (x - 2.5) ** 2 + (y - 2.5) ** 2 <= 6.5:
                c.put(x, y, (235, 230, 240, 255) if x + y < 5 else (190, 186, 205, 255))
    return c


def butterfly():
    """2 frames de 7x5 (alas abiertas / cerradas)."""
    f = ramp("flower_yellow")
    c = Canvas(14, 5)
    openw = ["X.....X", "XX.o.XX", ".XXoXX.", "XX.o.XX", "......."]
    closed = ["...X...", "..XoX..", "..XoX..", "...o...", "......."]
    key = {"X": f[2], "o": (60, 40, 50, 255)}
    for k, rows in enumerate((openw, closed)):
        for y, r in enumerate(rows):
            for x, ch in enumerate(r):
                if ch in key:
                    c.put(k * 7 + x, y, key[ch])
    return c


def player_shadow():
    c = Canvas(14, 5)
    for y in range(5):
        for x in range(14):
            if ((x + 0.5 - 7) / 6.5) ** 2 + ((y + 0.5 - 2.5) / 2.3) ** 2 <= 1:
                c.put(x, y, SHADOW)
    return c


def build_all(root):
    env = f"{root}/environment"
    veg = f"{root}/vegetation"
    bld = f"{root}/buildings"
    fur = f"{root}/furniture"
    fx = f"{root}/fx"
    out = {
        f"{veg}/tree_oak.png": tree_oak(1),
        f"{veg}/tree_oak_b.png": tree_oak(2, "leaf_teal"),
        f"{veg}/tree_blossom.png": tree_blossom(),
        f"{veg}/tree_pine.png": tree_pine(),
        f"{veg}/tree_palm.png": tree_palm(),
        f"{veg}/bush_round.png": bush(11),
        f"{veg}/bush_berry.png": bush(12, True),
        f"{veg}/grass_tuft.png": grass_tuft(3),
        f"{veg}/wildflowers.png": wildflowers(4),
        f"{veg}/reeds.png": reeds(5),
        f"{veg}/lily_pad.png": lily_pad(2),
        f"{env}/rock_big.png": rock(True, 7),
        f"{env}/rock_small.png": rock(False, 8),
        f"{env}/driftwood.png": driftwood(),
        f"{env}/shell.png": shell(),
        f"{fur}/fence.png": fence(),
        f"{fur}/fence_v.png": fence_v(),
        f"{fur}/lamp_post.png": lamp_post(),
        f"{fur}/bench.png": bench(),
        f"{fur}/mailbox.png": mailbox(),
        f"{fur}/fountain.png": fountain(),
        f"{fur}/telescope.png": telescope(),
        f"{bld}/house_cottage.png": house_cottage(),
        f"{bld}/house_cottage_glow.png": house_window_glow(),
        f"{fx}/soft_particle.png": soft_particle(),
        f"{fx}/petal.png": petal(),
        f"{fx}/smoke.png": smoke_puff(),
        f"{fx}/butterfly.png": butterfly(),
        f"{fx}/player_shadow.png": player_shadow(),
    }
    for name in ["flower_red", "flower_yellow", "flower_lilac", "flower_white", "flower_blue"]:
        out[f"{veg}/{name}.png"] = flower_clump(name, hash(name) % 100)
    for p, c in out.items():
        save(c, p)
    radial_light().save(f"{fx}/light_radial.png")
    print("objetos:", len(out) + 1)


if __name__ == "__main__":
    import sys

    build_all(sys.argv[1])
