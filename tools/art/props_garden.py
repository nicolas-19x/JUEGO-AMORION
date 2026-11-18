"""Catálogo acogedor para el modo construcción: jardín, picnic, luces pequeñas,
mobiliario y detalles. Mismas reglas que props.py (luz arriba-izquierda,
contorno con el tono más oscuro del material, sombras violeta).
"""
import math
from palette import ramp, SHADOW, CLEAR
from pix import Canvas, BAYER4, rng, save
from props import shade_blobs, drop_shadow, trunk

FLOWERS = ["flower_red", "flower_yellow", "flower_lilac", "flower_white", "flower_blue"]


def gingham(c, x0, y0, w, h, col_a, col_b, cream):
    """Tela de cuadros vichy (mantel, manta)."""
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            a = ((x - x0) // 3) % 2
            b = ((y - y0) // 3) % 2
            c.put(x, y, col_a if a and b else (col_b if a or b else cream))


def flower_pot(flower="flower_red", seed=1):
    t = ramp("roof")  # terracota
    f = ramp(flower)
    g = ramp("leaf")
    c = Canvas(14, 18)
    drop_shadow(c, 7, 16, 6, 1.8)
    # maceta troncocónica
    for y in range(9, 17):
        inset = (y - 9) // 3
        for x in range(2 + inset, 12 - inset):
            tone = 4 if x < 5 + inset else (2 if x > 9 - inset else 3)
            c.put(x, y, t[tone])
    c.hline(1, 12, 9, t[4])
    c.hline(1, 12, 10, t[3])
    # hojas y flores
    for (x, y) in [(4, 7), (9, 7), (6, 5), (7, 8)]:
        c.put(x, y, g[3])
        c.put(x + 1, y, g[2])
    for (x, y) in [(4, 4), (8, 3), (10, 6), (6, 6)]:
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            c.put(x + dx, y + dy, f[2])
        c.put(x - 1, y - 1, f[3])
        c.put(x, y, ramp("flower_yellow")[3] if flower != "flower_yellow" else ramp("flower_orange")[2])
    c.outline(t[0])
    return c


def planter(flower="flower_lilac"):
    w = ramp("wood")
    f = ramp(flower)
    g = ramp("leaf")
    c = Canvas(34, 20)
    for x in range(2, 33):
        c.put(x, 19, SHADOW)
    c.rect(2, 10, 30, 9, w[3])
    for x in range(2, 32):
        if x % 6 == 2:
            c.vline(x, 10, 18, w[2])
    c.hline(1, 32, 9, w[5])
    c.hline(1, 32, 10, w[4])
    c.hline(2, 31, 18, w[1])
    r = rng(5)
    for x in range(3, 31, 2):
        c.put(x, 8, g[2])
        c.put(x + 1, 7, g[3])
    for x in range(4, 30, 4):
        y = 5 + r.randrange(0, 3)
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            c.put(x + dx, y + dy, f[2])
        c.put(x - 1, y - 1, f[3])
        c.put(x, y, ramp("flower_yellow")[3])
    c.outline(w[0])
    return c


def stepping_stone(seed=3):
    s = ramp("stone")
    c = Canvas(16, 12)
    for y in range(12):
        for x in range(16):
            e = ((x + 0.5 - 8) / 6.8) ** 2 + ((y + 0.5 - 6) / 4.6) ** 2
            if e <= 1:
                c.put(x, y, s[4] if y < 5 else s[3])
    for (x, y) in [(5, 4), (9, 6), (11, 4)]:
        c.put(x, y, s[2])
    c.put(4, 3, s[5])
    c.put(5, 3, s[5])
    for x in range(3, 14):
        c.put(x, 11, SHADOW)
    c.outline(s[1])
    return c


def garden_lantern():
    """Farolillo bajo de jardín (luz cálida pequeña)."""
    i = ramp("iron")
    l = ramp("light")
    c = Canvas(10, 22)
    for x in range(1, 9):
        c.put(x, 21, SHADOW)
    c.rect(4, 11, 2, 10, i[2])
    c.vline(4, 11, 20, i[3])
    c.rect(2, 4, 6, 7, l[2])
    c.vline(2, 4, 10, l[1])
    c.put(4, 6, l[3])
    c.put(5, 6, l[3])
    c.hline(1, 8, 3, i[1])
    c.hline(2, 7, 2, i[2])
    c.put(4, 1, i[2])
    c.put(5, 1, i[2])
    c.hline(2, 7, 10, i[1])
    c.outline(i[0])
    return c


def picnic_table():
    w = ramp("wood_light")
    rd = ramp("flower_red")
    cr = ramp("plaster")
    c = Canvas(44, 30)
    for y in range(c.h):
        for x in range(c.w):
            if ((x + 0.5 - 22) / 21) ** 2 + ((y + 0.5 - 26) / 4) ** 2 <= 1:
                c.put(x, y, SHADOW)
    # bancos
    for by in (6, 22):
        c.rect(3, by, 38, 3, w[3])
        c.hline(3, 40, by, w[4])
        c.hline(3, 40, by + 2, w[1])
    # mesa con mantel de cuadros
    c.rect(5, 9, 34, 11, w[2])
    gingham(c, 6, 9, 32, 9, rd[2], rd[3], cr[4])
    c.hline(6, 37, 18, rd[1])
    # patas
    for lx in (8, 34):
        c.rect(lx, 19, 2, 6, w[1])
    # una cesta pequeña y un vaso
    c.rect(12, 6, 7, 5, ramp("wood")[3])
    c.hline(12, 18, 6, ramp("wood")[4])
    c.put(14, 5, ramp("wood")[2])
    c.put(15, 4, ramp("wood")[2])
    c.put(16, 5, ramp("wood")[2])
    c.rect(28, 8, 3, 4, ramp("water")[5])
    c.outline(ramp("wood")[0])
    return c


def picnic_blanket():
    b = ramp("flower_blue")
    cr = ramp("plaster")
    c = Canvas(36, 22)
    for x in range(3, 35):
        c.put(x, 21, SHADOW)
    gingham(c, 2, 2, 32, 18, b[1], b[2], cr[4])
    for x in range(2, 34):  # flecos
        if x % 2 == 0:
            c.put(x, 1, cr[3])
            c.put(x, 20, cr[3])
    c.outline(b[0])
    return c


def chair():
    w = ramp("wood")
    c = Canvas(14, 22)
    for x in range(2, 12):
        c.put(x, 21, SHADOW)
    c.rect(3, 2, 8, 9, w[3])
    c.hline(3, 10, 2, w[4])
    for x in (5, 8):
        c.vline(x, 4, 10, w[2])
    c.rect(2, 11, 10, 3, w[4])
    c.hline(2, 11, 11, w[5])
    c.hline(2, 11, 13, w[2])
    for lx in (3, 10):
        c.rect(lx, 14, 1, 6, w[1])
    c.outline(w[0])
    return c


def birdhouse():
    w = ramp("wood")
    rf = ramp("roof")
    c = Canvas(16, 32)
    for x in range(4, 12):
        c.put(x, 31, SHADOW)
    c.rect(7, 14, 2, 17, w[3])
    c.vline(7, 14, 30, w[4])
    # caseta
    c.rect(3, 7, 10, 8, ramp("plaster")[4])
    c.vline(3, 7, 14, ramp("plaster")[5])
    c.vline(12, 7, 14, ramp("plaster")[2])
    for y in range(2, 8):
        half = (y - 1) * 1.2
        for x in range(int(8 - half) - 1, int(8 + half) + 1):
            c.put(x, y, rf[4] if x < 8 else rf[3])
    c.rect(6, 9, 4, 4, w[0])
    c.rect(7, 10, 2, 2, (40, 28, 40, 255))
    c.hline(6, 9, 13, w[4])
    c.outline(w[0])
    return c


def well():
    s = ramp("stone")
    w = ramp("wood")
    rf = ramp("roof")
    c = Canvas(34, 42)
    for y in range(c.h):
        for x in range(c.w):
            if ((x + 0.5 - 17) / 15) ** 2 + ((y + 0.5 - 38) / 3.2) ** 2 <= 1:
                c.put(x, y, SHADOW)
    # brocal de piedra
    for y in range(24, 39):
        for x in range(4, 30):
            row = (y - 24) // 4
            brick = (x + (row % 2) * 3) // 6
            col = s[3] if (brick + row) % 2 else s[4]
            if (x + (row % 2) * 3) % 6 == 0 or (y - 24) % 4 == 3:
                col = s[2]
            c.put(x, y, col)
    for x in range(5, 29):
        c.put(x, 23, s[5])
        c.put(x, 24, ramp("water")[1] if 8 < x < 26 else s[4])
    # postes y tejadillo
    for px in (5, 27):
        c.rect(px, 8, 2, 16, w[3])
        c.vline(px, 8, 23, w[4])
    c.hline(6, 27, 12, w[2])
    c.rect(15, 12, 4, 6, w[1])  # cubo colgando
    c.hline(15, 18, 12, w[3])
    for y in range(1, 9):
        half = 4 + y * 1.8
        for x in range(int(17 - half), int(17 + half)):
            c.put(x, y, rf[4] if y < 4 else rf[3])
    c.hline(1, 32, 9, rf[1])
    c.outline(w[0])
    return c


def signpost():
    w = ramp("wood_light")
    c = Canvas(22, 28)
    for x in range(6, 16):
        c.put(x, 27, SHADOW)
    c.rect(10, 8, 2, 19, w[2])
    c.vline(10, 8, 26, w[3])
    c.rect(2, 3, 18, 8, w[3])
    c.hline(2, 19, 3, w[4])
    c.hline(2, 19, 10, w[1])
    for x in range(5, 17, 3):  # «letras»
        c.hline(x, x + 1, 6, w[0])
        c.hline(x, x + 1, 8, w[1])
    c.outline(ramp("wood")[0])
    return c


def hedge(seed=13):
    c = Canvas(18, 18)
    drop_shadow(c, 9, 15.5, 8.5, 2)
    blobs = [(5, 9, 5), (12, 9, 5), (9, 6, 5.5), (9, 11, 5.5)]
    b = shade_blobs(18, 17, blobs, ramp("leaf_teal"), seed, speckle=0.04)
    c.blit(b, 0, 0)
    return c


def hydrangea(color="flower_blue", seed=17):
    c = Canvas(20, 18)
    drop_shadow(c, 10, 15, 8, 2.3)
    blobs = [(10, 9, 6.5), (5.5, 11, 4.5), (14.5, 11, 4.5), (10, 5.5, 4.5)]
    b = shade_blobs(20, 16, blobs, ramp("leaf"), seed, speckle=0.0)
    c.blit(b, 0, 0)
    f = ramp(color)
    r = rng(seed)
    for (cx, cy) in [(7, 6), (12, 5), (14, 10), (6, 11), (10, 9)]:
        for dy in range(-1, 2):
            for dx in range(-1, 2):
                if r.random() < 0.85:
                    c.put(cx + dx, cy + dy, f[3] if dy < 0 else f[2])
        c.put(cx - 1, cy - 1, f[3])
    return c


def sapling(seed=19):
    c = Canvas(16, 22)
    drop_shadow(c, 8, 20, 5, 1.5)
    trunk(c, 7, 12, 8, 2, ramp("wood"))
    b = shade_blobs(16, 14, [(8, 8, 5.5), (5, 10, 3.5), (11, 10, 3.5)], ramp("leaf"), seed, speckle=0.05)
    c.blit(b, 0, 0)
    return c


def mushrooms():
    rd = ramp("flower_red")
    cr = ramp("plaster")
    c = Canvas(14, 12)
    for x in range(2, 12):
        c.put(x, 11, SHADOW)
    for (x, y, r_) in [(4, 6, 3), (9, 4, 4), (11, 8, 2)]:
        c.vline(x, y + 1, 10, cr[4])
        for dy in range(-r_ + 1, 1):
            for dx in range(-r_, r_ + 1):
                if dx * dx + dy * dy * 2 <= r_ * r_:
                    c.put(x + dx, y + dy, rd[2] if dx > -r_ + 1 else rd[3])
        c.put(x - 1, y - 1, cr[5])
        c.put(x + 1, y, cr[5])
    c.outline(rd[0])
    return c


def sunflower():
    y_ = ramp("flower_yellow")
    g = ramp("leaf")
    c = Canvas(14, 30)
    for x in range(3, 11):
        c.put(x, 29, SHADOW)
    c.vline(7, 9, 28, g[2])
    c.vline(8, 12, 28, g[3])
    for (x, y, d) in [(4, 18, -1), (10, 22, 1)]:
        c.hline(min(x, 7), max(x, 7), y, g[3])
        c.put(x + d, y - 1, g[3])
    for a in range(12):
        ang = a / 12 * math.tau
        c.put(int(7.5 + math.cos(ang) * 4.6), int(6 + math.sin(ang) * 4.2), y_[2] if a % 2 else y_[3])
        c.put(int(7.5 + math.cos(ang) * 3.4), int(6 + math.sin(ang) * 3.0), y_[2])
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if dx * dx + dy * dy <= 5:
                c.put(7 + dx, 6 + dy, ramp("dirt")[1] if (dx + dy) % 2 else ramp("dirt")[2])
    c.outline(g[0])
    return c


def apple_crate():
    w = ramp("wood_light")
    rd = ramp("flower_red")
    c = Canvas(16, 16)
    for x in range(1, 15):
        c.put(x, 15, SHADOW)
    c.rect(1, 6, 14, 9, w[2])
    for y in (6, 10):
        c.hline(1, 14, y, w[3])
    c.hline(1, 14, 14, w[1])
    for (x, y) in [(3, 4), (6, 3), (9, 4), (12, 4), (5, 5), (10, 5)]:
        c.rect(x, y, 2, 2, rd[2])
        c.put(x, y, rd[3])
    c.put(6, 2, ramp("leaf")[3])
    c.outline(ramp("wood")[0])
    return c


def watering_can():
    i = ramp("cloth_sage")
    c = Canvas(14, 10)
    for x in range(2, 12):
        c.put(x, 9, SHADOW)
    c.rect(3, 3, 6, 5, i[3])
    c.hline(3, 8, 3, i[4])
    c.put(2, 3, i[2])
    c.put(2, 4, i[2])
    for t in range(4):
        c.put(9 + t, 5 - t // 2, i[2])
    c.hline(4, 7, 1, i[1])
    c.put(4, 2, i[1])
    c.put(7, 2, i[1])
    c.outline(i[0])
    return c


def fence_side():
    """Valla de norte a sur: poste y largueros vistos de lado."""
    w = ramp("wood")
    c = Canvas(16, 24)
    for rx in (6, 9):
        c.rect(rx, 0, 2, 19, w[3])
        c.vline(rx, 0, 18, w[4])
    c.rect(5, 8, 6, 13, w[3])
    c.vline(5, 8, 20, w[4])
    c.vline(10, 8, 20, w[2])
    c.hline(5, 10, 7, w[5])
    c.put(7, 6, w[4])
    c.put(8, 6, w[4])
    c.outline(w[0])
    for x in range(4, 13):
        c.put(x, 23, SHADOW)
    return c


def build_all(root):
    veg = f"{root}/vegetation"
    fur = f"{root}/furniture"
    out = {
        f"{fur}/planter.png": planter(),
        f"{fur}/planter_rose.png": planter("flower_red"),
        f"{fur}/stepping_stone.png": stepping_stone(),
        f"{fur}/garden_lantern.png": garden_lantern(),
        f"{fur}/picnic_table.png": picnic_table(),
        f"{fur}/picnic_blanket.png": picnic_blanket(),
        f"{fur}/chair.png": chair(),
        f"{fur}/birdhouse.png": birdhouse(),
        f"{fur}/well.png": well(),
        f"{fur}/signpost.png": signpost(),
        f"{fur}/apple_crate.png": apple_crate(),
        f"{fur}/watering_can.png": watering_can(),
        f"{fur}/fence_v.png": fence_side(),
        f"{veg}/hedge.png": hedge(),
        f"{veg}/hydrangea_blue.png": hydrangea("flower_blue"),
        f"{veg}/hydrangea_lilac.png": hydrangea("flower_lilac", 18),
        f"{veg}/sapling.png": sapling(),
        f"{veg}/mushrooms.png": mushrooms(),
        f"{veg}/sunflower.png": sunflower(),
    }
    for fl in FLOWERS:
        out[f"{fur}/flower_pot_{fl.split('_')[1]}.png"] = flower_pot(fl)
    for p, c in out.items():
        save(c, p)
    print("jardín:", len(out))


if __name__ == "__main__":
    import sys

    build_all(sys.argv[1])
