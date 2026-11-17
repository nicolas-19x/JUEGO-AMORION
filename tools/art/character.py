"""Hojas de sprites de personaje por capas (cuerpo, ropa, pelo).

Cada capa se exporta en «índices de rampa»: el canal R guarda el índice del tono
(0..4) multiplicado por 50, y G=B=R. En el juego un shader (palette_swap) asigna
la rampa de color elegida, así la personalización no necesita nuevas imágenes.

Hoja: frames de 16x32. Columnas: idle0, idle1, walk0, walk1, walk2, walk3, sit.
Filas: abajo, arriba, izquierda, derecha.
"""
from PIL import Image

FW, FH = 16, 32
COLS = 7
DIRS = ["down", "up", "left", "right"]

# Tonos: '0' contorno, '1' sombra, '2' base, '3' luz, '4' brillo
# Capa por símbolo: S=piel (s1 S2 k=rubor->3), E=ojo (piel tono 0)
# Para cada capa, símbolos -> índice de tono

HEAD_DOWN = [
    "....aaaaaaaa....",
    "...aSSSSSSSSa...",
    "..aSSSSSSSSSSa..",
    "..aSSSSSSSSSSa..",
    "..aSSSSSSSSSSa..",
    "..aSSESSSSESSa..",
    "..aSSESSSSESSa..",
    "..aSKSSSSSSKSa..",
    "...asSSSSSSsa...",
    ".....aassaa.....",
]
HEAD_UP = [
    "....aaaaaaaa....",
    "...aSSSSSSSSa...",
    "..aSSSSSSSSSSa..",
    "..aSSSSSSSSSSa..",
    "..aSSSSSSSSSSa..",
    "..aSSSSSSSSSSa..",
    "..aSSSSSSSSSSa..",
    "..asSSSSSSSSsa..",
    "...assSSSSssa...",
    ".....aassaa.....",
]
HEAD_LEFT = [
    "....aaaaaaa.....",
    "...aSSSSSSSa....",
    "..aSSSSSSSSSa...",
    "..aSSSSSSSSSSa..",
    "..aSSSSSSSSSSa..",
    ".aSESSSSSSSSSa..",
    ".aSESSSSSSSSSa..",
    ".aSSKSSSSSSSsa..",
    "..asSSSSSSSsa...",
    ".....aasssa.....",
]

TORSO_DOWN = [
    "....oCCCCCCo....",
    "...oCCCCCCCCo...",
    "..oCCDCCCCCCco..",
    "..oCCCCCCCCCco..",
    "..ocCCCCCCCCco..",
    "..aSocccccccSa..",
]
TORSO_UP = [
    "....oCCCCCCo....",
    "...oCCCCCCCCo...",
    "..oCCCCCCCCCCo..",
    "..ocCCCCCCCCco..",
    "..occCCCCCCcco..",
    "..aSocccccccSa..",
]
TORSO_LEFT = [
    ".....oCCCCo.....",
    "....oCCCCCCo....",
    "....oCDCCCco....",
    "....oCCCCCco....",
    "....occCCcco....",
    "....oaSScco.....",
]

LEGS_DOWN = {
    "stand": [
        "....pPPPPPPp....",
        "....pPPppPPp....",
        "....pPp..pPp....",
        "....pPp..pPp....",
        "...bBBb..bBBb...",
        "...bbbb..bbbb...",
    ],
    "stepL": [
        "....pPPPPPPp....",
        "....pPPppPPp....",
        "....pPp..pPp....",
        "...bBBb..pPp....",
        "...bbbb.bBBb....",
        ".........bbbb...",
    ],
    "stepR": [
        "....pPPPPPPp....",
        "....pPPppPPp....",
        "....pPp..pPp....",
        "....pPp..bBBb...",
        "...bBBb..bbbb...",
        "...bbbb.........",
    ],
    "sit": [
        "....pPPPPPPp....",
        "...pPPPppPPPp...",
        "...bBBb..bBBb...",
        "...bbbb..bbbb...",
        "................",
        "................",
    ],
}
LEGS_LEFT = {
    "stand": [
        ".....pPPPPp.....",
        ".....pPPPPp.....",
        ".....pPPpPp.....",
        ".....pPp.pp.....",
        "....bBBb.bb.....",
        "....bbbbbbb.....",
    ],
    "stepL": [
        ".....pPPPPp.....",
        "....pPPppPp.....",
        "....pPp.pPp.....",
        "...bBBb..pPp....",
        "...bbbb.bBBb....",
        "........bbbb....",
    ],
    "stepR": [
        ".....pPPPPp.....",
        ".....pPPPPp.....",
        ".....pPPPPp.....",
        ".....pPpPp......",
        "....bBBbBBb.....",
        "....bbbbbbb.....",
    ],
    "sit": [
        ".....pPPPPp.....",
        "..ppPPPPPPp.....",
        ".bBBpppppp......",
        ".bbbb...........",
        "................",
        "................",
    ],
}

# Pelo: H base, h sombra, L luz, x contorno
HAIR = {
    "short": {
        "down": [
            ".....xxxxxx.....",
            "...xxHHHHHHxx...",
            "..xHHLLHHHHHHx..",
            ".xHHLHHHHHHHHHx.",
            ".xHHHHHhHHhHHHx.",
            ".xhHxhhxxhhxHhx.",
            ".xhx........xhx.",
            "..x..........x..",
        ],
        "up": [
            ".....xxxxxx.....",
            "...xxHHHHHHxx...",
            "..xHHLLHHHHHHx..",
            ".xHHLHHHHHHHHHx.",
            ".xHHHHHHHHHHHHx.",
            ".xhHHHHHHHHHHhx.",
            ".xhhHHHHHHHHhhx.",
            "..xhhhhhhhhhhx..",
            "...xxxxxxxxxx...",
        ],
        "left": [
            "....xxxxxxx.....",
            "...xHHHHHHHxx...",
            "..xHLLHHHHHHHx..",
            ".xHLHHHHHHHHHHx.",
            ".xHxxhHHHHHHHHx.",
            "..x...xhHHHHHhx.",
            "......xhHHHhhx..",
            ".......xhhhhx...",
            "........xxxx....",
        ],
    },
    "long": {
        "down": [
            ".....xxxxxx.....",
            "...xxHHHHHHxx...",
            "..xHHLLHHHHHHx..",
            ".xHHLHHHHHHHHHx.",
            ".xHHHHHhHHhHHHx.",
            ".xHHxhhxxhhxHHx.",
            ".xHx........xHx.",
            ".xHx........xHx.",
            ".xHx........xHx.",
            ".xhx........xhx.",
            ".xhx........xhx.",
            ".xhx........xhx.",
            "..x..........x..",
        ],
        "up": [
            ".....xxxxxx.....",
            "...xxHHHHHHxx...",
            "..xHHLLHHHHHHx..",
            ".xHHLHHHHHHHHHx.",
            ".xHHHHHHHHHHHHx.",
            ".xHHHHHHHHHHHHx.",
            ".xHHHHHHHHHHHHx.",
            ".xhHHHHHHHHHHhx.",
            ".xhHHHHHHHHHHhx.",
            ".xhhHHHHHHHHhhx.",
            ".xhhhHHHHHHhhhx.",
            "..xhhhhhhhhhhx..",
            "...xxxxxxxxxx...",
        ],
        "left": [
            "....xxxxxxx.....",
            "...xHHHHHHHxx...",
            "..xHLLHHHHHHHx..",
            ".xHLHHHHHHHHHHx.",
            ".xHxxhHHHHHHHHx.",
            "..x...xhHHHHHHx.",
            "......xhHHHHHHx.",
            "......xhHHHHHhx.",
            "......xhHHHHHhx.",
            "......xhhHHHhhx.",
            ".......xhhhhhx..",
            "........xxxxx...",
        ],
    },
}

BODY_KEY = {"a": 0, "s": 1, "S": 3, "K": 2}
EYES_KEY = {"E": 0}
OUTFIT_KEY = {"o": 0, "c": 1, "C": 2, "D": 3, "p": 0, "P": 2, "b": 0, "B": 2}
# ropa: la camiseta y el pantalón son capas distintas para poder combinarlas
SHIRT_KEY = {"o": 0, "c": 1, "C": 2, "D": 3}
PANTS_KEY = {"p": 0, "P": 2}
SHOES_KEY = {"b": 0, "B": 2}
HAIR_KEY = {"x": 0, "h": 1, "H": 2, "L": 3}

HEAD_Y = 9
TORSO_Y = 19
LEGS_Y = 25


def code(idx):
    v = idx * 50 + 2
    return (v, v, v, 255)


def stamp(img, rows, key, ox, oy, flip=False):
    for y, r in enumerate(rows):
        if flip:
            r = r[::-1]
        for x, ch in enumerate(r):
            if ch in key:
                px, py = ox + x, oy + y
                if 0 <= px < img.width and 0 <= py < img.height:
                    img.putpixel((px, py), code(key[ch]))


def frame_parts(direction, col):
    """Devuelve (cabeza, torso, piernas, desplazamiento_y, desplazamiento_mano)."""
    if direction == "down":
        head, torso, legs = HEAD_DOWN, TORSO_DOWN, LEGS_DOWN
    elif direction == "up":
        head, torso, legs = HEAD_UP, TORSO_UP, LEGS_DOWN
    else:
        head, torso, legs = HEAD_LEFT, TORSO_LEFT, LEGS_LEFT
    bob = 0
    pose = "stand"
    if col == 1:
        bob = 1  # respiración: la parte superior baja 1px
    elif col in (2, 4):
        pose = "stand"
    elif col == 3:
        pose = "stepL"
        bob = -1
    elif col == 5:
        pose = "stepR"
        bob = -1
    elif col == 6:
        pose = "sit"
        bob = 2
    return head, torso, legs[pose], bob


def build(out_dir):
    layers = {n: Image.new("RGBA", (FW * COLS, FH * 4), (0, 0, 0, 0)) for n in ["body", "eyes", "shirt", "pants", "shoes"]}
    hair_layers = {s: Image.new("RGBA", (FW * COLS, FH * 4), (0, 0, 0, 0)) for s in HAIR}
    for row, d in enumerate(DIRS):
        flip = d == "right"
        for col in range(COLS):
            head, torso, legs, bob = frame_parts(d, col)
            ox, oy = col * FW, row * FH
            # en «sentado» todo el cuerpo baja; las piernas se recogen
            leg_oy = oy + LEGS_Y + (2 if col == 6 else 0)
            stamp(layers["pants"], legs, PANTS_KEY, ox, leg_oy, flip)
            stamp(layers["shoes"], legs, SHOES_KEY, ox, leg_oy, flip)
            stamp(layers["body"], torso, BODY_KEY, ox, oy + TORSO_Y + bob, flip)
            stamp(layers["shirt"], torso, SHIRT_KEY, ox, oy + TORSO_Y + bob, flip)
            stamp(layers["body"], head, BODY_KEY, ox, oy + HEAD_Y + bob, flip)
            stamp(layers["eyes"], head, EYES_KEY, ox, oy + HEAD_Y + bob, flip)
            hd = "left" if d in ("left", "right") else d
            for style, tpl in HAIR.items():
                stamp(hair_layers[style], tpl[hd], HAIR_KEY, ox, oy + HEAD_Y - 1 + bob, flip)
    for n, im in layers.items():
        im.save(f"{out_dir}/char_{n}.png")
    for s, im in hair_layers.items():
        im.save(f"{out_dir}/char_hair_{s}.png")
    print("personaje: capas", list(layers) + ["hair_" + s for s in HAIR])


def ramp_png(out_dir):
    """Texturas de rampa (5x1) para el shader de intercambio de paleta."""
    from palette import RAMPS

    for name, cols in RAMPS.items():
        if not (name.startswith(("skin", "hair", "cloth", "shoe", "eye"))):
            continue
        im = Image.new("RGBA", (5, 1))
        for i in range(5):
            im.putpixel((i, 0), cols[min(i, len(cols) - 1)])
        im.save(f"{out_dir}/ramps/{name}.png")


def preview(out_path, combos):
    """Compone personajes con rampas para revisión visual (no se usa en el juego)."""
    from palette import RAMPS
    import os

    d = os.path.dirname(out_path) or "."
    base = "assets/characters"
    sheets = []
    for combo in combos:
        canvas = Image.new("RGBA", (FW * COLS, FH * 4), (0, 0, 0, 0))
        for layer, rampname in combo:
            im = Image.open(f"{base}/{layer}.png")
            rc = RAMPS[rampname]
            out = Image.new("RGBA", im.size, (0, 0, 0, 0))
            for y in range(im.height):
                for x in range(im.width):
                    p = im.getpixel((x, y))
                    if p[3]:
                        out.putpixel((x, y), rc[min(len(rc) - 1, round(p[0] / 50))])
            canvas.alpha_composite(out)
        sheets.append(canvas)
    W = sum(s.width for s in sheets) + 8 * len(sheets)
    o = Image.new("RGBA", (W, FH * 4), (110, 160, 90, 255))
    x = 0
    for s in sheets:
        o.alpha_composite(s, (x, 0))
        x += s.width + 8
    o.resize((o.width * 4, o.height * 4), Image.NEAREST).save(out_path)


if __name__ == "__main__":
    import sys, os

    out = sys.argv[1]
    os.makedirs(out + "/ramps", exist_ok=True)
    build(out)
    ramp_png(out)
    if len(sys.argv) > 2:
        preview(
            sys.argv[2],
            [
                [("char_body", "skin_a"), ("char_eyes", "eye_dark"), ("char_pants", "cloth_denim"), ("char_shoes", "shoe_brown"), ("char_shirt", "cloth_sage"), ("char_hair_short", "hair_brown")],
                [("char_body", "skin_c"), ("char_eyes", "eye_dark"), ("char_pants", "cloth_cream"), ("char_shoes", "shoe_white"), ("char_shirt", "cloth_rose"), ("char_hair_long", "hair_auburn")],
            ],
        )
