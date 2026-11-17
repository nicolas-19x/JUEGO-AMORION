"""Paleta maestra de «Nuestro pequeño universo».

Todas las imágenes del juego se generan a partir de estas rampas. Cada rampa va
de oscuro a claro. Regla: la luz viene de arriba a la izquierda; el contorno de
cada material es el tono más oscuro de su propia rampa (sel-out), nunca negro.
"""


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


RAMPS = {
    # Vegetación
    "grass": ["#1f3d36", "#2b5c44", "#3f7f4c", "#62a356", "#94c869", "#c5e38a"],
    "leaf": ["#1c3532", "#24503f", "#33704a", "#4f9152", "#79b35e", "#a9d27a"],
    "leaf_teal": ["#1a3338", "#1f4d4c", "#2d6c62", "#46907a", "#6fb593"],
    "blossom": ["#5e2f4c", "#8c4468", "#bd6386", "#e391a6", "#f7c4c9", "#fff0ec"],
    "autumn": ["#4f2a2a", "#83402f", "#b8623a", "#e0924c", "#f4c46d"],
    # Suelo
    "dirt": ["#3f2a2a", "#5c3b32", "#7d543d", "#a0714c", "#c39565", "#e0bb87"],
    "sand": ["#8a6a4c", "#b08a5f", "#cfaa76", "#e6c890", "#f4e1af", "#fdf3d4"],
    "stone": ["#2f2e3d", "#4a4858", "#686676", "#8c8a97", "#b1afb8", "#d6d4d9"],
    "cobble": ["#3a3440", "#57505a", "#7a7078", "#9d9399", "#c2b9bb", "#e3dcdb"],
    # Agua
    "water": ["#16284f", "#1d3d6b", "#24578a", "#2f78a6", "#4a9fc0", "#7fc8d6", "#c4ece6", "#f1fbf6"],
    # Materiales construidos
    "wood": ["#33201f", "#4f3027", "#724532", "#965f40", "#ba8253", "#dca972"],
    "wood_light": ["#5b3b2c", "#86583c", "#ad7b51", "#cfa06c", "#ead08f"],
    "roof": ["#3e1f2c", "#622a34", "#8a3a3d", "#b2524a", "#d2735a", "#eba07a"],
    "plaster": ["#7a6a66", "#a39188", "#c9b8a6", "#e4d6bf", "#f6ecd7", "#fffaf0"],
    "iron": ["#1f1d29", "#34313f", "#4c4858", "#6c687a"],
    # Personajes
    "skin_a": ["#5a3330", "#8c5443", "#c07e62", "#e2a988", "#f6cfb0"],
    "skin_b": ["#3d2520", "#6b3e2f", "#9a6045", "#c48a64", "#e0b38c"],
    "skin_c": ["#5e3a36", "#9a6656", "#d29b80", "#f0c3a6", "#fde3cf"],
    "hair_brown": ["#24171a", "#3e2522", "#5f3a2d", "#85563b", "#a97852"],
    "hair_black": ["#141220", "#221f30", "#353247", "#4f4b63", "#6c6880"],
    "hair_auburn": ["#2e1418", "#57222a", "#843a32", "#b05a3c", "#d6844f"],
    "hair_blonde": ["#5a3e2a", "#8a6538", "#b88f4e", "#dcb86c", "#f2dc98"],
    "cloth_sage": ["#1f3330", "#2f4c45", "#466b5e", "#64907a", "#8fb79a"],
    "cloth_rose": ["#4a2433", "#733448", "#9f4c5f", "#c87580", "#e8a7a6"],
    "cloth_cream": ["#6f625d", "#9c8f84", "#c7baa8", "#e6dcc8", "#fbf5e6"],
    "cloth_navy": ["#151a30", "#1f2a48", "#2e3f66", "#46598a", "#6b80ad"],
    "cloth_mustard": ["#4d3520", "#7b5528", "#a87a33", "#d2a547", "#ecc96d"],
    "cloth_denim": ["#18223a", "#243556", "#344d78", "#4b6a98", "#7090bb"],
    "shoe_brown": ["#211616", "#3b2621", "#5c3d31", "#80583f"],
    "shoe_white": ["#4f4c5a", "#8b8896", "#c8c5cc", "#f0eef0"],
    # Flores y acentos
    "flower_red": ["#6a1f33", "#a8324a", "#e0566a", "#f68b8e"],
    "flower_yellow": ["#7a5320", "#c08a2a", "#f0c24a", "#fbe58a"],
    "flower_lilac": ["#3f2a5c", "#6a4690", "#9b74c4", "#cfaee6"],
    "flower_white": ["#6f7486", "#a9adbb", "#e2e4ea", "#ffffff"],
    "flower_blue": ["#1f2f66", "#3654a6", "#5d86da", "#9dc0f4"],
    "flower_orange": ["#6b2c1d", "#b5502a", "#ee8a3f", "#fbbf6e"],
    "light": ["#c26a3a", "#f0a14c", "#ffd27a", "#fff1bf"],
    "night": ["#141634", "#1f2552", "#2e3872", "#3e4c8e"],
}

RAMPS = {k: [hx(c) for c in v] for k, v in RAMPS.items()}
CLEAR = (0, 0, 0, 0)
SHADOW = (24, 18, 40, 90)  # sombra proyectada semitransparente (violeta, no negra)


def ramp(name):
    return RAMPS[name]


def all_colors():
    out = []
    for r in RAMPS.values():
        out.extend(r)
    return out
