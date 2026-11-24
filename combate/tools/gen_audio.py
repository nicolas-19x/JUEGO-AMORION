#!/usr/bin/env python3
"""Sintetiza todos los sonidos del prototipo (originales, sin muestras externas).

Uso: python3 tools/gen_audio.py assets/audio
Cada impacto tiene varias variantes para que dos golpes iguales nunca suenen
idénticos; el juego además varía el tono y elige sin repetir la anterior.
"""
import sys, os, wave
import numpy as np

SR = 44100
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(d, a=0.002, decay=10.0):
    x = t(d)
    e = np.exp(-x * decay)
    att = np.clip(x / max(a, 1e-4), 0, 1)
    return e * att


def lowpass(x, cut):
    a = np.exp(-2 * np.pi * cut / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cut):
    return x - lowpass(x, cut)


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def sweep(d, f0, f1, curve=8.0):
    x = t(d)
    f = f1 + (f0 - f1) * np.exp(-x * curve)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph)


def pad(x, d):
    n = int(SR * d)
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def mix(*xs):
    n = max(len(x) for x in xs)
    out = np.zeros(n)
    for x in xs:
        out[: len(x)] += x
    return out


def save(path, x, peak=0.9):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    # micro fundido final para evitar clics
    f = min(200, len(x))
    x[-f:] *= np.linspace(1, 0, f)
    data = (x * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def impact(weight, var):
    """weight 0..1: de golpe seco a golpe pesado."""
    d = 0.25 + weight * 0.45
    body_f0 = 140 - weight * 60 + var * 9
    body = sweep(d, body_f0 * 2.2, body_f0 * 0.6, 18 - weight * 8) * env(d, 0.001, 16 - weight * 9)
    snap_d = 0.05 + weight * 0.03
    snap = highpass(noise(snap_d), 1800 - weight * 600) * env(snap_d, 0.0005, 70 - weight * 25)
    slap = lowpass(noise(0.12), 2600 + var * 300) * env(0.12, 0.0008, 38)
    crunch = lowpass(noise(0.2), 900) * env(0.2, 0.002, 22) * weight
    sub = np.sin(2 * np.pi * (48 + var * 3) * t(d)) * env(d, 0.004, 7) * weight
    return pad(mix(body * 0.9, snap * (0.55 - weight * 0.2), slap * 0.5, crunch * 0.6, sub * 0.9), d)


def block(var):
    d = 0.25
    thud = sweep(d, 260 + var * 20, 110, 25) * env(d, 0.001, 24)
    pad_n = lowpass(noise(d), 700 + var * 80) * env(d, 0.001, 30)
    clack = highpass(noise(0.03), 2500) * env(0.03, 0.0003, 120)
    return mix(thud * 0.8, pad_n * 0.8, clack * 0.25)


def whoosh(length, var):
    d = length
    n = noise(d)
    x = t(d)
    shape = np.sin(np.pi * np.clip(x / d, 0, 1)) ** 2
    # barrido de filtro: el aire se corta más rápido en el centro
    out = np.zeros_like(n)
    lo = lowpass(n, 500 + var * 60)
    hi = lowpass(n, 2200 + var * 150) - lowpass(n, 700)
    k = shape
    out = lo * (1 - k) * 0.6 + hi * k * 1.2
    return out * shape


def step(var):
    d = 0.09
    s = lowpass(noise(d), 1500 + var * 250) * env(d, 0.003, 45)
    tap = sweep(d, 180, 90, 40) * env(d, 0.001, 60)
    return mix(s * 0.8, tap * 0.4)


def main(out):
    os.makedirs(out, exist_ok=True)
    for i in range(4):
        save(f"{out}/hit_l_{i}.wav", impact(0.1 + 0.05 * i, i))
    for i in range(3):
        save(f"{out}/hit_m_{i}.wav", impact(0.45 + 0.05 * i, i))
    for i in range(3):
        save(f"{out}/hit_h_{i}.wav", impact(0.85 + 0.05 * i, i))
    for i in range(3):
        save(f"{out}/block_{i}.wav", block(i))
    for i, d in enumerate([0.16, 0.22, 0.34]):
        save(f"{out}/whoosh_{i}.wav", whoosh(d, i), 0.6)
    for i in range(4):
        save(f"{out}/step_{i}.wav", step(i), 0.5)
    # capa húmeda para golpes fuertes: impacto carnoso corto
    for i in range(3):
        d = 0.18
        sq = lowpass(noise(d), 1200 + i * 250) * env(d, 0.001, 32)
        body = sweep(d, 220 - i * 20, 80, 30) * env(d, 0.001, 40)
        save(f"{out}/wet_{i}.wav", mix(sq * 0.9, body * 0.6), 0.8)
    # parada: brillo metálico + golpe de aire
    d = 0.7
    ting = sum(np.sin(2 * np.pi * f * t(d)) * env(d, 0.001, k) * a
               for f, k, a in [(1320, 7, 0.6), (1985, 9, 0.35), (2790, 12, 0.25), (660, 5, 0.3)])
    save(f"{out}/parry.wav", mix(ting, impact(0.2, 1) * 0.6))
    # caída al suelo
    d = 0.6
    fall = mix(sweep(d, 120, 45, 9) * env(d, 0.002, 7), lowpass(noise(d), 500) * env(d, 0.003, 9) * 0.8)
    save(f"{out}/fall.wav", fall)
    # contra la pared: golpe pesado + polvo/gravilla
    d = 0.9
    debris = np.zeros(int(SR * d))
    for _ in range(26):
        p = int(rng.uniform(0.02, 0.6) * SR)
        g = highpass(noise(0.02), 1500) * env(0.02, 0.0002, 160) * rng.uniform(0.1, 0.4)
        debris[p:p + len(g)] += g[: len(debris) - p]
    save(f"{out}/wall.wav", mix(impact(1.0, 2), debris))
    # KO: golpe grande y cola grave
    d = 1.8
    tail = sweep(d, 90, 38, 2) * env(d, 0.01, 2.2)
    save(f"{out}/ko.wav", mix(impact(1.0, 0) * 1.2, tail * 0.8))
    # objeto de madera golpeado
    d = 0.3
    wood = sum(np.sin(2 * np.pi * f * t(d)) * env(d, 0.0005, k) for f, k in [(420, 25), (870, 35), (1530, 50)])
    save(f"{out}/prop.wav", mix(wood * 0.5, lowpass(noise(d), 1200) * env(d, 0.001, 30) * 0.6))
    # interfaz
    save(f"{out}/ui_tap.wav", np.sin(2 * np.pi * 880 * t(0.06)) * env(0.06, 0.001, 60), 0.4)
    save(f"{out}/ui_go.wav", mix(sweep(0.5, 220, 440, 6) * env(0.5, 0.005, 5) * 0.6, impact(0.6, 1) * 0.5), 0.7)
    # ambiente: viento suave sobre la ciudad, bucle de 12 s
    d = 12.0
    wind = lowpass(noise(d), 380)
    mod = 0.6 + 0.4 * np.sin(2 * np.pi * t(d) / 6.0) * np.sin(2 * np.pi * t(d) / 4.0 + 1)
    hum = np.sin(2 * np.pi * 55 * t(d)) * 0.04 + np.sin(2 * np.pi * 82.5 * t(d)) * 0.02
    amb = wind * mod + hum
    # campanillas lejanas
    for p in [1.3, 5.2, 8.9]:
        dd = 2.0
        ch = sum(np.sin(2 * np.pi * f * t(dd)) * env(dd, 0.002, 2.5) for f in [1568, 2093, 2637]) * 0.05
        i = int(p * SR)
        amb[i:i + len(ch)] += ch[: len(amb) - i]
    # cierre del bucle sin costura
    f = int(0.5 * SR)
    amb[:f] = amb[:f] * np.linspace(0, 1, f) + amb[-f:] * np.linspace(1, 0, f)
    amb = amb[:-f]
    save(f"{out}/ambience.wav", amb, 0.5)
    # pulso de combate: tambores graves espaciados, 92 bpm, 8 compases de 4/4
    bpm = 92
    beat = 60 / bpm
    d = beat * 16
    drum = np.zeros(int(SR * d))
    pattern = [0, 1.5, 2, 3.5, 4, 5.5, 6, 6.75, 7.5, 8, 9.5, 10, 11.5, 12, 13.5, 14, 14.5, 15, 15.5]
    for i, b in enumerate(pattern):
        dd = 0.6
        strength = 1.0 if b % 4 == 0 else 0.6
        k = sweep(dd, 150, 52, 14) * env(dd, 0.002, 6) * strength
        k = mix(k, lowpass(noise(0.08), 900) * env(0.08, 0.001, 40) * 0.3 * strength)
        p = int(b * beat * SR)
        drum[p:p + len(k)] += k[: len(drum) - p]
    save(f"{out}/drums.wav", drum, 0.55)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "assets/audio")
