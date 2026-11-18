"""Atlas de terreno con sistema dual-grid.

Cada material tiene un atlas de 20 columnas x 4 filas de tiles de 16x16:
- columnas 0..15: las 16 combinaciones de esquinas (bit0=TL, bit1=TR, bit2=BL, bit3=BR)
- columnas 16..19: variantes decoradas del tile lleno (combinación 15)
- filas 0..3: fase del patrón (el relleno es periódico cada 32px, así se repite menos)
  fila = (px % 2) + 2 * (py % 2) de la celda de visualización.

La celda de visualización (i, j) se dibuja en (i*16 - 8, j*16 - 8) y sus cuatro
esquinas son las celdas de material (i-1,j-1), (i,j-1), (i-1,j), (i,j).
"""
import numpy as np
from palette import ramp, SHADOW
from pix import Canvas, periodic_noise, dither_pick, rng, save

T = 16
PERIOD = 32
COLS = 20
ROWS = 4


def _edt(inside):
    """Distancia euclídea con signo (negativa dentro)."""
    try:
        from scipy.ndimage import distance_transform_edt as dte

        return np.where(inside, -dte(inside) + 0.5, dte(~inside) - 0.5)
    except ImportError:
        pass
    h, w = inside.shape
    ys, xs = np.mgrid[0:h, 0:w]
    pts_in = np.stack([ys[inside], xs[inside]], 1)
    pts_out = np.stack([ys[~inside], xs[~inside]], 1)
    grid = np.stack([ys.ravel(), xs.ravel()], 1)

    def mind(pts):
        if len(pts) == 0:
            return np.full(h * w, 1e3)
        d = np.sqrt(((grid[:, None, :] - pts[None, :, :]) ** 2).sum(-1))
        return d.min(1)

    d_in = mind(pts_in).reshape(h, w)  # distancia al interior más cercano
    d_out = mind(pts_out).reshape(h, w)
    return np.where(inside, -d_out + 0.5, d_in - 0.5)


_mask_cache = {}
_field_cache = {}


def shape_mask(cfg, phase, roundness, noise_amp, noise_seed):
    key = (cfg, phase, roundness, noise_amp, noise_seed)
    if key in _mask_cache:
        return _mask_cache[key]
    S = 48
    o = 16
    inside = np.zeros((S, S), bool)
    for Y in range(S):
        for X in range(S):
            x, y = X - o, Y - o
            left = x < 8
            top = y < 8
            bit = (0 if top else 2) + (0 if left else 1)
            inside[Y, X] = bool(cfg & (1 << bit))
    if cfg == 0:
        m = np.zeros((T, T), bool)
    elif cfg == 15:
        m = np.ones((T, T), bool)
    else:
        r = roundness
        if (cfg, r) not in _field_cache:
            d = _edt(inside)
            if r > 0:
                # cierre (redondea esquinas cóncavas) y apertura (redondea convexas)
                closed = _edt(d <= r) <= -r
                ero = _edt(closed) <= -r
                opened = _edt(ero) <= r
                d = _edt(opened)
            _field_cache[(cfg, r)] = d
        d3 = _field_cache[(cfg, r)]
        px, py = phase % 2, phase // 2
        nz = periodic_noise(PERIOD, 4, noise_seed, octaves=2)
        m = np.zeros((T, T), bool)
        for y in range(T):
            for x in range(T):
                u = (px * T + x) % PERIOD
                v = (py * T + y) % PERIOD
                n = (nz[v, u] - 0.5) * 2 * noise_amp
                m[y, x] = d3[y + o, x + o] + n < 0
    _mask_cache[key] = m
    return m


# --------------------------------------------------------------- rellenos
def fill_grass(seed=11):
    g = ramp("grass")
    n1 = periodic_noise(PERIOD, 4, seed, 2)
    n2 = periodic_noise(PERIOD, 8, seed + 1, 1)
    r = rng(seed)
    c = Canvas(PERIOD, PERIOD)
    for y in range(PERIOD):
        for x in range(PERIOD):
            v = n1[y, x] * 0.8 + n2[y, x] * 0.2
            # dos tonos con transición suave: superficie tranquila, sin ruido
            lvl = dither_pick(min(1, max(0, (v - 0.32) * 1.9)), x, y, 2)
            c.put(x, y, g[2 + lvl] if lvl == 0 else g[3])
    # briznas: trazos de 2px con luz arriba y sombra abajo
    for _ in range(26):
        x, y = r.randrange(PERIOD), r.randrange(PERIOD)
        c.put(x, y, g[4])
        c.put(x, (y + 1) % PERIOD, g[3])
        c.put(x, (y + 2) % PERIOD, g[2])
    for _ in range(6):
        x, y = r.randrange(PERIOD), r.randrange(PERIOD)
        c.put(x, y, g[5])
    return c


def fill_sand(seed=21):
    s = ramp("sand")
    n1 = periodic_noise(PERIOD, 4, seed, 2)
    r = rng(seed)
    c = Canvas(PERIOD, PERIOD)
    for y in range(PERIOD):
        for x in range(PERIOD):
            v = n1[y, x]
            lvl = dither_pick(min(1, max(0, (v - 0.3) * 1.8)), x, y, 2)
            c.put(x, y, s[3 + lvl])
    # ondulaciones del viento
    for k in range(5):
        y0 = r.randrange(PERIOD)
        x0 = r.randrange(PERIOD)
        for i in range(r.randrange(4, 8)):
            c.put((x0 + i) % PERIOD, (y0 + (i // 3)) % PERIOD, s[2])
    for _ in range(14):
        x, y = r.randrange(PERIOD), r.randrange(PERIOD)
        c.put(x, y, s[5] if r.random() < 0.6 else s[1])
    return c


def fill_dirt(seed=31):
    d = ramp("dirt")
    n1 = periodic_noise(PERIOD, 4, seed, 2)
    r = rng(seed)
    c = Canvas(PERIOD, PERIOD)
    for y in range(PERIOD):
        for x in range(PERIOD):
            lvl = dither_pick(min(1, max(0, (n1[y, x] - 0.3) * 1.7)), x, y, 2)
            c.put(x, y, d[3 + lvl] if lvl else d[3])
    for _ in range(9):  # guijarros
        x, y = r.randrange(PERIOD), r.randrange(PERIOD)
        c.put(x, y, d[5])
        c.put((x + 1) % PERIOD, y, d[4])
        c.put(x, (y + 1) % PERIOD, d[1])
        c.put((x + 1) % PERIOD, (y + 1) % PERIOD, d[1])
    for _ in range(10):
        x, y = r.randrange(PERIOD), r.randrange(PERIOD)
        c.put(x, y, d[2] if r.random() < 0.5 else d[4])
    return c


def fill_cobble(seed=41):
    """Adoquines irregulares de la plaza (piedra cálida)."""
    s = ramp("cobble")
    r = rng(seed)
    c = Canvas(PERIOD, PERIOD)
    c.rect(0, 0, PERIOD, PERIOD, s[1])  # junta
    rows = [(0, 7), (8, 7), (16, 7), (24, 7)]
    for ri, (y0, hgt) in enumerate(rows):
        off = 0 if ri % 2 == 0 else 5
        x = off - 10
        while x < PERIOD + 10:
            w = r.choice([7, 8, 9, 10])
            tone = r.choice([3, 3, 4, 2])
            for yy in range(y0, y0 + hgt):
                for xx in range(x, x + w - 1):
                    # esquinas recortadas
                    if (yy in (y0, y0 + hgt - 1)) and (xx in (x, x + w - 2)):
                        continue
                    col = s[tone]
                    if yy == y0 or xx == x:
                        col = s[min(5, tone + 1)]
                    if yy == y0 + hgt - 1 or xx == x + w - 2:
                        col = s[max(2, tone - 1)]
                    c.put(xx % PERIOD, yy % PERIOD, col)
            x += w
    for _ in range(12):
        x, y = r.randrange(PERIOD), r.randrange(PERIOD)
        if c.get(x, y) != s[1]:
            c.put(x, y, s[2])
    return c


def fill_wood(seed=51):
    """Tablones (muelle y suelos de madera)."""
    w = ramp("wood")
    r = rng(seed)
    c = Canvas(PERIOD, PERIOD)
    for y in range(PERIOD):
        plank = y // 5
        tone = 3 if plank % 2 == 0 else 4
        for x in range(PERIOD):
            col = w[tone]
            if y % 5 == 4:
                col = w[1]
            elif y % 5 == 0:
                col = w[5] if tone == 4 else w[4]
            c.put(x, y, col)
    for p in range(7):
        y0 = p * 5
        seam = r.randrange(PERIOD)
        for yy in range(y0, min(PERIOD, y0 + 4)):
            c.put(seam, yy, w[1])
        c.put((seam + 3) % PERIOD, min(PERIOD - 1, y0 + 2), w[2])
    return c


def decorate_grass(base, seed):
    g = ramp("grass")
    r = rng(seed)
    c = Canvas(PERIOD, PERIOD)
    c.blit(base, 0, 0)
    flowers = [ramp("flower_white"), ramp("flower_yellow"), ramp("flower_lilac"), ramp("flower_blue")]
    for _ in range(r.randrange(2, 5)):
        x, y = r.randrange(2, PERIOD - 2), r.randrange(2, PERIOD - 2)
        f = r.choice(flowers)
        c.put(x, y + 1, g[1])
        c.put(x, y, f[2])
        c.put(x - 1, y, f[3] if r.random() < 0.5 else f[2])
        c.put(x, y - 1, f[3])
    for _ in range(r.randrange(1, 3)):  # pequeño trébol
        x, y = r.randrange(2, PERIOD - 2), r.randrange(2, PERIOD - 2)
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            c.put(x + dx, y + dy, g[4] if dy == 0 else g[3])
        c.put(x, y + 2, g[1])
    return c


# ------------------------------------------------------------- materiales
MATERIALS = {
    # nombre: (relleno, redondez, ruido, estilo de borde)
    "sand": dict(fill=fill_sand, round=8, noise=1.6, style="shore"),
    "grass": dict(fill=fill_grass, round=8, noise=1.3, style="raised"),
    "dirt": dict(fill=fill_dirt, round=8, noise=1.0, style="sunken"),
    "cobble": dict(fill=fill_cobble, round=7, noise=0.4, style="curb"),
    "wood": dict(fill=fill_wood, round=0, noise=0.0, style="deck"),
}


def build_material(name, seed):
    spec = MATERIALS[name]
    fill = spec["fill"]()
    deco_fills = []
    if name == "grass":
        deco_fills = [decorate_grass(fill, 900 + i) for i in range(4)]
    atlas = Canvas(COLS * T, ROWS * T)
    for phase in range(4):
        px, py = phase % 2, phase // 2
        for cfg in range(16):
            m = shape_mask(cfg, phase, spec["round"], spec["noise"], seed)
            tile = render_tile(name, spec, fill, m, px, py)
            atlas.blit(tile, cfg * T, phase * T)
        for k in range(4):
            src = deco_fills[k] if deco_fills else fill
            m = shape_mask(15, phase, spec["round"], spec["noise"], seed)
            tile = render_tile(name, spec, src, m, px, py)
            atlas.blit(tile, (16 + k) * T, phase * T)
    return atlas


def render_tile(name, spec, fill, m, px, py):
    c = Canvas(T, T)
    style = spec["style"]

    def ins(x, y):
        if 0 <= x < T and 0 <= y < T:
            return m[y, x]
        return None  # desconocido fuera del tile

    for y in range(T):
        for x in range(T):
            u = (px * T + x) % PERIOD
            v = (py * T + y) % PERIOD
            if m[y, x]:
                c.put(x, y, fill.get(u, v))
    if m.all() or not m.any():
        return c

    def edge_dist(x, y, dirs):
        for d in (1, 2, 3):
            for dx, dy in dirs:
                q = ins(x + dx * d, y + dy * d)
                if q is False:
                    return d
        return 99

    four = ((1, 0), (-1, 0), (0, 1), (0, -1))
    if style == "raised":  # césped: borde oscuro, flequillo de briznas y sombra al sur
        g = ramp("grass")
        for y in range(T):
            for x in range(T):
                if m[y, x]:
                    if ins(x, y + 1) is False:
                        c.put(x, y, g[1])
                    elif ins(x, y + 2) is False:
                        c.put(x, y, g[2])
                    elif edge_dist(x, y, four) == 1:
                        c.put(x, y, g[2])
                else:
                    if ins(x, y - 1) is True:
                        u = (px * T + x) % PERIOD
                        if u % 3 != 1:
                            c.put(x, y, g[1])  # briznas colgantes
                        else:
                            c.put(x, y, SHADOW)
                    elif ins(x, y - 2) is True:
                        c.put(x, y, SHADOW)
                    elif edge_dist(x, y, ((1, 0), (-1, 0))) == 1:
                        c.put(x, y, (24, 18, 40, 50))
    elif style == "shore":  # arena: borde húmedo y más oscuro
        s = ramp("sand")
        for y in range(T):
            for x in range(T):
                if m[y, x]:
                    d = edge_dist(x, y, four)
                    if d == 1:
                        c.put(x, y, s[1])
                    elif d == 2:
                        c.put(x, y, s[2])
    elif style == "sunken":  # tierra: hundida, sombra del césped en el borde norte
        d_ = ramp("dirt")
        for y in range(T):
            for x in range(T):
                if m[y, x]:
                    if ins(x, y - 1) is False:
                        c.put(x, y, d_[1])
                    elif ins(x, y - 2) is False:
                        c.put(x, y, d_[2])
                    elif edge_dist(x, y, four) == 1:
                        c.put(x, y, d_[2])
    elif style == "curb":  # adoquín: bordillo claro y sombra al sur
        s = ramp("cobble")
        for y in range(T):
            for x in range(T):
                if m[y, x]:
                    if edge_dist(x, y, four) == 1:
                        c.put(x, y, s[4] if ins(x, y + 1) is not False else s[1])
                elif ins(x, y - 1) is True:
                    c.put(x, y, SHADOW)
    elif style == "deck":  # madera: canto oscuro y sombra sobre el agua
        w = ramp("wood")
        for y in range(T):
            for x in range(T):
                if m[y, x]:
                    if ins(x, y + 1) is False:
                        c.put(x, y, w[1])
                    elif ins(x, y + 2) is False:
                        c.put(x, y, w[2])
                    elif edge_dist(x, y, ((1, 0), (-1, 0))) == 1:
                        c.put(x, y, w[2])
                else:
                    if ins(x, y - 1) is True or ins(x, y - 2) is True:
                        c.put(x, y, (16, 20, 48, 110))
    return c


def build_all(out_dir):
    seeds = {"sand": 101, "grass": 202, "dirt": 303, "cobble": 404, "wood": 505}
    for name, seed in seeds.items():
        atlas = build_material(name, seed)
        save(atlas, f"{out_dir}/terrain_{name}.png")
        print("terreno", name)


if __name__ == "__main__":
    import sys

    build_all(sys.argv[1])
