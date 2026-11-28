#!/usr/bin/env python3
"""Prepara un modelo GLB sin esqueleto (malla con colores por vértice) para el rig del juego.

Uso:  python3 -I tools/model_prep.py modelo.glb salida.bin [celda]

· Une todas las mallas del GLB, gira el modelo para que mire a -Z (delante en Godot) y lo
  escala; decima la malla grande por agrupación de vértices (celda en unidades del modelo).
· Coloca un esqueleto con las mismas piezas que FighterRig (caderas, columna, pecho, cabeza,
  brazo, antebrazo, mano, muslo, espinilla, pie) en las articulaciones del modelo, medidas
  sobre la nube de puntos, y calcula pesos suaves por zonas con mezcla en las articulaciones.
· Cada hueso lleva una escala a lo largo de su eje para que el modelo ocupe las longitudes del
  rig (piernas, brazos, tronco) sin cambiar la lógica del combate.
· Escribe un binario simple que lee tools/build_model.gd para crear el ArrayMesh de Godot.
"""
import json
import struct
import sys

import numpy as np

S = 0.92            # escala general del modelo → metros del juego
CELL = 0.0075       # celda de decimado (unidades del modelo)

# Medidas del rig (scripts/fighter/rig.gd)
SPINE_OFS, CHEST_OFS, NECK_OFS = 0.12, 0.20, 0.25
SHOULDER = (0.19, 0.17)
HIP_SOCKET = (0.10, -0.06)
UPPER_ARM, FOREARM, THIGH, SHIN = 0.29, 0.27, 0.44, 0.44

BONES = ["hips", "spine", "chest", "head",
         "upper_l", "fore_l", "hand_l", "upper_r", "fore_r", "hand_r",
         "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
B = {n: i for i, n in enumerate(BONES)}

CT = {5126: np.float32, 5121: np.uint8, 5123: np.uint16, 5125: np.uint32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
LIP = (0.62, 0.36, 0.34)


def load_glb(path):
    d = open(path, "rb").read()
    jl = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + jl])
    bin_off = 20 + jl + 8

    def acc(i):
        a = j["accessors"][i]
        bv = j["bufferViews"][a["bufferView"]]
        off = bin_off + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        n = a["count"] * NC[a["type"]]
        arr = np.frombuffer(d, dtype=CT[a["componentType"]], count=n, offset=off)
        arr = arr.reshape(a["count"], NC[a["type"]]) if NC[a["type"]] > 1 else arr
        if a.get("normalized"):
            arr = arr.astype(np.float64) / np.iinfo(arr.dtype).max
        return np.array(arr)

    meshes = []
    for m in j["meshes"]:
        for p in m["primitives"]:
            if p.get("mode", 4) != 4:
                continue
            pos = acc(p["attributes"]["POSITION"]).astype(np.float64)
            if "COLOR_0" in p["attributes"]:
                col = acc(p["attributes"]["COLOR_0"])[:, :3].astype(np.float64)
            else:
                col = np.tile(np.array(LIP), (len(pos), 1))
            idx = acc(p["indices"]).astype(np.int64).reshape(-1, 3) if "indices" in p \
                else np.arange(len(pos)).reshape(-1, 3)
            meshes.append((m["name"], pos, col, idx))
    return meshes


def cluster(pos, col, idx, cell):
    """Decimado por rejilla: un vértice por celda ocupada (media de posición y color)."""
    key = np.floor(pos / cell).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    n = inv.max() + 1
    cnt = np.bincount(inv, minlength=n).astype(np.float64)
    newp = np.stack([np.bincount(inv, pos[:, k], n) for k in range(3)], 1) / cnt[:, None]
    newc = np.stack([np.bincount(inv, col[:, k], n) for k in range(3)], 1) / cnt[:, None]
    f = inv[idx]
    ok = (f[:, 0] != f[:, 1]) & (f[:, 1] != f[:, 2]) & (f[:, 0] != f[:, 2])
    f = f[ok]
    f = np.unique(np.sort(f, 1), axis=0, return_index=True)[1]
    f = inv[idx][ok][np.sort(f)]
    return newp, newc, f


def normals(pos, idx):
    n = np.zeros_like(pos)
    fn = np.cross(pos[idx[:, 1]] - pos[idx[:, 0]], pos[idx[:, 2]] - pos[idx[:, 0]])
    for k in range(3):
        np.add.at(n, idx[:, k], fn)
    ln = np.linalg.norm(n, axis=1, keepdims=True)
    return n / np.maximum(ln, 1e-12)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def seg_basis(a, b, perp):
    """Igual que en el rig (modo modelo): -Y de a hacia b, Z hacia el lado del codo/rodilla."""
    y = a - b
    y = y / np.linalg.norm(y)
    x = np.cross(perp, y)
    x = x / np.linalg.norm(x)
    z = np.cross(x, y)
    return np.stack([x, y, z], 1)   # columnas = ejes


def main():
    src, out = sys.argv[1], sys.argv[2]
    cell = float(sys.argv[3]) if len(sys.argv) > 3 else CELL
    meshes = load_glb(src)
    P, C, I = [], [], []
    base = 0
    raw_all = np.concatenate([m[1] for m in meshes])
    for name, pos, col, idx in meshes:
        if len(pos) > 3000:
            pos, col, idx = cluster(pos, col, idx, cell)
        P.append(pos), C.append(col), I.append(idx + base)
        base += len(pos)
    P = np.concatenate(P)
    C = np.concatenate(C)
    I = np.concatenate(I)

    # ---- medidas sobre la nube original (unidades y ejes del modelo: mira a +Z) ----
    R = raw_all
    floor = R[:, 1].min()

    def slab(y0, y1, cond=None):
        m = (R[:, 1] >= y0) & (R[:, 1] < y1)
        if cond is not None:
            m &= cond(R)
        return R[m]

    torso = slab(0.3, 0.45)
    cx = 0.5 * (torso[:, 0].min() + torso[:, 0].max())
    cz = 0.5 * (torso[:, 2].min() + torso[:, 2].max())
    y_hs = floor + 0.83          # cavidad de la cadera
    y_neck = floor + 1.63        # base del cuello
    y_ank = floor + 0.08

    def leg_c(y, side):
        s = slab(y - 0.02, y + 0.02, lambda r: (r[:, 0] - cx) * side > 0.03)
        return np.array([s[:, 0].mean(), y, s[:, 2].mean()])

    def arm_c(y, side):
        s = slab(y - 0.015, y + 0.015, lambda r: (r[:, 0] - cx) * side > 0.30)
        return np.array([s[:, 0].mean(), y, s[:, 2].mean()])

    lm = {}
    for side, tag in ((1, "a"), (-1, "b")):
        hip = leg_c(y_hs - 0.12, side)
        hip[1] = y_hs
        ank = leg_c(y_ank + 0.02, side)
        ank[1] = y_ank
        knee = leg_c(0.5 * (y_hs + y_ank), side)
        knee[2] = max(knee[2], 0.5 * (hip[2] + ank[2]))
        # brazo: línea por los centros bajo la axila, prolongada hasta el hombro
        ys = np.arange(0.02, 0.24, 0.02)
        cs = np.array([arm_c(y, side) for y in ys])
        A = np.vstack([ys, np.ones_like(ys)]).T
        kx = np.linalg.lstsq(A, cs[:, 0], rcond=None)[0]
        kz = np.linalg.lstsq(A, cs[:, 2], rcond=None)[0]
        y_sh = y_neck - 0.11
        y_wr = 0.0
        sh = np.array([kx[0] * y_sh + kx[1], y_sh, cz])
        sh[0] = cx + np.sign(sh[0] - cx) * min(abs(sh[0] - cx), 0.235)
        wr = np.array([kx[0] * y_wr + kx[1], y_wr, kz[0] * y_wr + kz[1]])
        el = sh + (wr - sh) * 0.5
        el[2] -= 0.02            # codo algo atrás
        lm[tag] = dict(hip=hip, knee=knee, ank=ank, sh=sh, el=el, wr=wr)

    # ---- al marco del rig: girar 180° (mirar a -Z), centrar, escalar, pies en y=0 ----
    def to_rig(p):
        p = np.atleast_2d(p).astype(np.float64)
        q = np.empty_like(p)
        q[:, 0] = -(p[:, 0] - cx) * S
        q[:, 1] = (p[:, 1] - floor) * S
        q[:, 2] = -(p[:, 2] - cz) * S
        return q

    P = to_rig(P)
    N = normals(P, I)            # glTF: antihorario hacia fuera
    I = I[:, [0, 2, 1]]          # Godot toma el orden horario como cara frontal
    J = {}
    for tag in ("a", "b"):
        for k, v in lm[tag].items():
            J[k + "_" + tag] = to_rig(v)[0]
    # lado "l" del rig = x negativo
    side_of = {}
    for tag in ("a", "b"):
        side_of[tag] = "l" if J["sh_" + tag][0] < 0 else "r"
    JR = {}
    for tag, s in side_of.items():
        for k in ("hip", "knee", "ank", "sh", "el", "wr"):
            JR[k + "_" + s] = J[k + "_" + tag]

    y_hs_r = (y_hs - floor) * S
    y_neck_r = (y_neck - floor) * S
    kt = (NECK_OFS + CHEST_OFS + SPINE_OFS - HIP_SOCKET[1]) / (y_neck_r - y_hs_r)
    o_hips = y_hs_r - HIP_SOCKET[1] / kt
    o_spine = o_hips + SPINE_OFS / kt
    o_chest = o_spine + CHEST_OFS / kt
    o_neck = o_chest + NECK_OFS / kt
    zc = 0.0
    k_side = 0.92

    rest = {}       # hueso → (origen, base 3x3, escala xyz)
    I3 = np.eye(3)
    rest["hips"] = (np.array([0, o_hips, zc]), I3, (k_side, kt, k_side))
    rest["spine"] = (np.array([0, o_spine, zc]), I3, (k_side, kt, k_side))
    rest["chest"] = (np.array([0, o_chest, zc]), I3, (k_side, kt, k_side))
    rest["head"] = (np.array([0, o_neck, zc]), I3, (0.94, 0.94, 0.94))
    for s in ("l", "r"):
        sd = -1.0 if s == "l" else 1.0
        sh, el, wr = JR["sh_" + s], JR["el_" + s], JR["wr_" + s]
        arm_perp = np.array([0.35 * sd, -0.2, 1.0])
        # el pole del rig se proyecta perpendicular al brazo (como en two_bone)
        d = (wr - sh) / np.linalg.norm(wr - sh)
        pp = arm_perp - d * arm_perp.dot(d)
        pp /= np.linalg.norm(pp)
        rest["upper_" + s] = (sh, seg_basis(sh, el, pp), (1.0, UPPER_ARM / np.linalg.norm(el - sh), 1.0))
        rest["fore_" + s] = (el, seg_basis(el, wr, pp), (1.0, FOREARM / np.linalg.norm(wr - el), 1.0))
        rest["hand_" + s] = (wr, seg_basis(el, wr, pp), (1.0, 1.0, 1.0))
        hip, kn, an = JR["hip_" + s], JR["knee_" + s], JR["ank_" + s]
        d = (an - hip) / np.linalg.norm(an - hip)
        leg_perp = np.array([0.0, 0.0, -1.0])
        pp = leg_perp - d * leg_perp.dot(d)
        pp /= np.linalg.norm(pp)
        rest["thigh_" + s] = (hip, seg_basis(hip, kn, pp), (1.0, THIGH / np.linalg.norm(kn - hip), 1.0))
        rest["shin_" + s] = (kn, seg_basis(kn, an, pp), (1.0, SHIN / np.linalg.norm(an - kn), 1.0))
        rest["foot_" + s] = (an, I3, (1.0, 1.0, 1.0))

    # ---- pesos ----
    n = len(P)
    W = np.zeros((n, len(BONES)))
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    ax = np.abs(x)
    # brazo frente a tronco: frontera que sube desde la axila hasta el hombro
    y_pit = (0.27 - floor) * S
    y_top = (y_neck - 0.04 - floor) * S
    # bajo la axila la frontera va por el hueco entre tronco y brazo, que se abre hacia la mano
    y_low = (-0.15 - floor) * S
    below = 0.235 * S + np.clip((y_pit - y) / (y_pit - y_low), 0.0, 1.0) * 0.125 * S
    bound = np.where(y < y_pit, below, 0.235 * S - (y - y_pit) / (y_top - y_pit) * 0.045 * S)
    arm_w = smooth(-0.015, 0.02, ax - bound) * smooth(y_top + 0.02, y_top - 0.03, y)
    # piernas frente a cadera
    leg_w = smooth(y_hs_r + 0.07, y_hs_r - 0.09, y)
    # tronco por alturas
    head_w = smooth(o_neck - 0.01, o_neck + 0.06, y)
    rad = np.sqrt(x ** 2 + (z - 0.0) ** 2)
    head_w = np.where(y < o_neck + 0.09, head_w * smooth(0.11, 0.075, rad), head_w)
    t_sp = smooth(o_spine - 0.05, o_spine + 0.05, y)
    t_ch = smooth(o_chest - 0.06, o_chest + 0.06, y)
    trunk = (1 - arm_w) * (1 - leg_w)
    W[:, B["hips"]] = trunk * (1 - head_w) * (1 - t_sp)
    W[:, B["spine"]] = trunk * (1 - head_w) * t_sp * (1 - t_ch)
    W[:, B["chest"]] = trunk * (1 - head_w) * t_sp * t_ch
    W[:, B["head"]] = trunk * head_w
    for s in ("l", "r"):
        sd = -1.0 if s == "l" else 1.0
        on = ((x > 0) if sd > 0 else (x <= 0)).astype(np.float64)
        sh, el, wr = JR["sh_" + s], JR["el_" + s], JR["wr_" + s]
        # parámetro a lo largo de cada tramo
        du = (el - sh) / np.linalg.norm(el - sh)
        df = (wr - el) / np.linalg.norm(wr - el)
        te = (P - el) @ df
        tw = (P - wr) @ df
        w_fore = smooth(-0.035, 0.035, te)
        w_hand = smooth(-0.012, 0.015, tw)
        aw = arm_w * on
        # cerca del hombro, el pecho se queda con lo que está por encima de la articulación
        ts = (P - sh) @ du
        aw = aw * smooth(-0.04, 0.03, ts)
        W[:, B["chest"]] += arm_w * on - aw
        W[:, B["upper_" + s]] = aw * (1 - w_fore)
        W[:, B["fore_" + s]] = aw * w_fore * (1 - w_hand)
        W[:, B["hand_" + s]] = aw * w_fore * w_hand
        hip, kn, an = JR["hip_" + s], JR["knee_" + s], JR["ank_" + s]
        lw = leg_w * (1 - arm_w) * on
        w_shin = smooth(kn[1] + 0.04, kn[1] - 0.04, y)
        w_foot = smooth(an[1] + 0.03, an[1] - 0.015, y)
        W[:, B["thigh_" + s]] = lw * (1 - w_shin)
        W[:, B["shin_" + s]] = lw * w_shin * (1 - w_foot)
        W[:, B["foot_" + s]] = lw * w_shin * w_foot
    tot = W.sum(1, keepdims=True)
    assert (tot > 0.5).all(), "vértices sin peso: %d" % int((tot <= 0.5).sum())
    W = W / np.maximum(tot, 1e-12)
    order = np.argsort(-W, axis=1)[:, :4]
    wi = np.take_along_axis(W, order, 1)
    wi = wi / wi.sum(1, keepdims=True)

    # piel (para el daño): tonos cálidos claros
    lin = C
    skin = ((lin[:, 0] > 0.55) & (lin[:, 0] > lin[:, 2] + 0.12) & (lin[:, 1] > 0.38)).astype(np.float64)

    # ---- escribir ----
    meta = {"bones": [], "count": int(n), "tris": int(len(I))}
    for name in BONES:
        o, b, sc = rest[name]
        meta["bones"].append({"name": name, "origin": [float(v) for v in o],
                              "basis": [[float(b[r, c]) for c in range(3)] for r in range(3)],
                              "scale": [float(v) for v in sc]})
    meta["joints"] = {k: [float(t) for t in v] for k, v in JR.items()}
    face = {}
    named = {m[0]: m[1] for m in meshes}
    for key, names in (("nose", ["face_nose_tip"]), ("mouth", ["face_mouth_seam"]),
                       ("eye_a", ["face_eye_sclera_L"]), ("eye_b", ["face_eye_sclera_R"]),
                       ("brow_a", ["face_eyebrow_L"]), ("brow_b", ["face_eyebrow_R"])):
        pts = np.concatenate([named[nm] for nm in names if nm in named])
        c = to_rig(0.5 * (pts.min(0) + pts.max(0)))[0]
        if key in ("nose",):
            c = to_rig(pts[np.argmax(pts[:, 2])])[0]   # punta
        face[key] = [float(t) for t in c]
    meta["face"] = face
    print("cara", {k: np.round(v, 3).tolist() for k, v in face.items()})
    js = json.dumps(meta).encode()
    with open(out, "wb") as f:
        f.write(struct.pack("<I", len(js)))
        f.write(js)
        f.write(P.astype(np.float32).tobytes())
        f.write(N.astype(np.float32).tobytes())
        f.write(np.hstack([C, skin[:, None]]).astype(np.float32).tobytes())
        f.write(order.astype(np.int32).tobytes())
        f.write(wi.astype(np.float32).tobytes())
        f.write(I.astype(np.int32).tobytes())
    print("vértices", n, "triángulos", len(I), "kt %.3f" % kt)
    for name in BONES:
        o, b, sc = rest[name]
        print(" %-8s origen %s escala %s peso %.0f" % (name, np.round(o, 3), np.round(sc, 2), W[:, B[name]].sum()))


if __name__ == "__main__":
    main()
