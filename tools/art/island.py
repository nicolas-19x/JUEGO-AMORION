"""Diseño de la isla inicial -> data/world/island_start.json

Materiales: 0 agua, 1 arena, 2 césped, 3 tierra, 4 adoquín, 5 madera.
El mapa se escribe como filas de dígitos para que sea legible y fácil de editar.
Los objetos se colocan por celda (esquina superior izquierda de su huella).
"""
import json
import math
import random

W, H = 56, 40
WATER, SAND, GRASS, DIRT, COBBLE, WOOD = range(6)


def make():
    r = random.Random(7)
    g = [[WATER] * W for _ in range(H)]

    def blob(cx, cy, rx, ry, val, jitter=0.0, cond=None):
        for y in range(H):
            for x in range(W):
                a = math.atan2(y - cy, x - cx)
                j = 1 + jitter * (math.sin(a * 3 + cx) * 0.5 + math.sin(a * 5 + cy) * 0.5)
                if ((x - cx) / (rx * j)) ** 2 + ((y - cy) / (ry * j)) ** 2 <= 1:
                    if cond is None or cond(g[y][x]):
                        g[y][x] = val

    # silueta de la isla (arena = costa)
    blob(27, 20, 23, 15.5, SAND, 0.08)
    blob(40, 9, 9, 6.5, SAND, 0.05)  # promontorio del mirador (noreste)
    blob(12, 27, 10, 8, SAND, 0.06)
    # interior de césped, dejando playa al sureste
    blob(26, 19, 20.5, 13, GRASS, 0.08)
    blob(40, 9.5, 7.2, 4.8, GRASS, 0.05)
    blob(12, 26, 8.5, 6.5, GRASS, 0.06)
    for y in range(H):  # playa amplia al sureste
        for x in range(W):
            if g[y][x] == GRASS and (x - 40) ** 2 / 90 + (y - 33) ** 2 / 30 < 1:
                g[y][x] = SAND
    # lago (suroeste) con orilla de césped y una pequeña playa
    blob(13, 26, 5.2, 3.4, WATER, 0.1)
    blob(15.5, 29.2, 2.2, 1.0, SAND, 0.0, cond=lambda v: v == GRASS)
    # plaza central
    blob(28, 20, 3.6, 2.8, COBBLE)

    def path(points, width=1):
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            steps = max(abs(x1 - x0), abs(y1 - y0)) * 2
            for i in range(steps + 1):
                t = i / max(1, steps)
                x = round(x0 + (x1 - x0) * t)
                y = round(y0 + (y1 - y0) * t)
                for dy in range(width):
                    for dx in range(width):
                        if g[y + dy][x + dx] in (GRASS, SAND):
                            g[y + dy][x + dx] = DIRT

    # caminos: casa -> plaza -> mirador / lago / playa
    path([(18, 15), (18, 18), (22, 19), (25, 20)], 2)
    path([(31, 18), (34, 15), (37, 12), (39, 10)], 2)
    path([(26, 23), (23, 25), (20, 27), (18, 27)], 2)
    path([(31, 22), (34, 25), (37, 28)], 2)
    # mirador: plataforma de adoquín sobre el promontorio
    blob(41.5, 7.5, 2.6, 1.9, COBBLE)
    # muelle de madera en el lago
    # muelle: entra al lago desde la orilla sur
    for y in range(25, 30):
        for x in range(11, 13):
            g[y][x] = WOOD
    # sin charcos sueltos: el agua aislada de una celda se vuelve césped
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if g[y][x] == WATER and sum(g[y + dy][x + dx] != WATER for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) >= 3:
                g[y][x] = GRASS
    # patio de tierra delante de la casa y huerto/jardín
    for y in range(14, 16):
        for x in range(14, 22):
            if g[y][x] == GRASS:
                g[y][x] = DIRT

    objects = []

    def put(item, x, y, **kw):
        o = {"item": item, "cell": [x, y]}
        o.update(kw)
        objects.append(o)

    # Casa (huella 6x3 celdas; tejado sobresale hacia arriba)
    put("house_cottage", 14, 10)
    put("mailbox", 21, 13)
    put("lamp_post", 13, 14)
    put("lamp_post", 22, 15)
    # jardín: arriates de flores frente a la casa (oeste)
    for i, v in enumerate([0, 1, 2, 3, 0, 4]):
        put("flowers", 9 + (i % 3), 14 + (i // 3), variant=v)
    for x in range(8, 13):
        put("fence", x, 17)
    put("fence", 8, 16, variant=1)
    put("fence", 8, 15, variant=1)
    put("fence", 8, 14, variant=1)
    put("bush_round", 12, 12)
    put("tree_blossom", 7, 10)
    # plaza
    put("fountain", 27, 19)
    put("bench", 25, 17)
    put("bench", 29, 22)
    put("lamp_post", 24, 21)
    put("lamp_post", 32, 18)
    put("flowers", 31, 21, variant=1)
    put("flowers", 24, 18, variant=3)
    # mirador
    put("telescope", 42, 6)
    put("bench", 39, 7)
    put("lamp_post", 44, 8)
    put("tree_blossom", 36, 7)
    put("rock_big", 45, 10)
    put("rock_small", 37, 5)
    put("rock_small", 46, 6)
    # lago
    put("reeds", 9, 23)
    put("reeds", 17, 24)
    put("reeds", 16, 27)
    put("lily_pad", 14, 24)
    put("lily_pad", 15, 26)
    put("lily_pad", 13, 28)
    put("bench", 10, 21)
    put("tree_oak", 18, 22)
    put("picnic_blanket", 20, 29)
    put("apple_crate", 22, 29)
    put("garden_lantern", 13, 22)
    put("flower_pot", 16, 13, variant=2)
    put("flower_pot", 19, 13, variant=0)
    put("birdhouse", 6, 12)
    put("planter", 23, 11)
    put("hydrangea", 12, 13)
    put("sunflower", 7, 13)
    # playa
    put("driftwood", 42, 31)
    put("rock_small", 47, 30)
    put("shell", 39, 34)
    put("shell", 44, 33)
    put("tree_palm", 46, 27)
    # árboles y arbustos (bosquecillo norte, bordes)
    trees = [
        ("tree_oak", 9, 7), ("tree_pine", 12, 6), ("tree_oak", 22, 7), ("tree_pine", 25, 8),
        ("tree_oak", 28, 6), ("tree_pine", 31, 9), ("tree_oak", 5, 18), ("tree_pine", 6, 22),
        ("tree_oak", 33, 26), ("tree_pine", 22, 31), ("tree_oak", 26, 30), ("tree_oak", 47, 19),
        ("tree_pine", 45, 15), ("tree_oak", 36, 16), ("tree_blossom", 20, 24), ("tree_pine", 4, 27),
        ("tree_oak", 18, 33), ("tree_pine", 8, 33),
    ]
    for t, x, y in trees:
        put(t, x, y)
    bushes = [(16, 7), (20, 9), (34, 11), (30, 26), (24, 27), (42, 18), (6, 15), (14, 31), (38, 22), (35, 6)]
    for i, (x, y) in enumerate(bushes):
        put("bush_round", x, y, variant=i % 2)
    tufts = [(r.randrange(4, 50), r.randrange(4, 36)) for _ in range(140)]
    occupied = set()
    for o in objects:
        occupied.add(tuple(o["cell"]))
    n = 0
    for x, y in tufts:
        if g[y][x] == GRASS and (x, y) not in occupied:
            put("grass_tuft", x, y, variant=0 if n % 4 else 1)
            occupied.add((x, y))
            n += 1

    return g, objects


if __name__ == "__main__":
    import sys

    g, objs = make()
    data = {
        "version": 1,
        "size": [W, H],
        "tile_size": 16,
        "spawn": [26 * 16, 24 * 16],
        "materials": ["water", "sand", "grass", "dirt", "cobble", "wood"],
        "terrain": ["".join(str(v) for v in row) for row in g],
        "objects": objs,
    }
    with open(sys.argv[1], "w") as f:
        json.dump(data, f, indent=1, ensure_ascii=False)
    for row in data["terrain"]:
        print(row.replace("0", "~").replace("1", ".").replace("2", ",").replace("3", "=").replace("4", "#").replace("5", "W"))
