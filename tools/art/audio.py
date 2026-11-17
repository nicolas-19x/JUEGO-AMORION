"""Sonidos originales sintetizados (sin licencias de terceros).

Son provisionales de calidad aceptable: ambientación suave y efectos discretos.
Se marcan como «provisionales» en la documentación hasta tener audio definitivo.
"""
import wave
import numpy as np

SR = 22050


def write(path, x, sr=SR):
    x = np.clip(x, -1, 1)
    data = (x * 32000).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


def lowpass(x, a):
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def env(n, attack, release):
    e = np.ones(n)
    a = int(attack * SR)
    r = int(release * SR)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[-r:] *= np.linspace(1, 0, r) ** 2
    return e


def seamless(x, fade=1.0):
    """Hace un bucle sin cortes mezclando el final con el principio."""
    f = int(fade * SR)
    head = x[:f].copy()
    x = x[f:]
    ramp = np.linspace(0, 1, f)
    x[-f:] = x[-f:] * (1 - ramp) + head * ramp
    return x


def waves(seconds=24, seed=1):
    rng = np.random.default_rng(seed)
    n = SR * seconds
    noise = rng.standard_normal(n)
    soft = lowpass(noise, 0.035)
    t = np.arange(n) / SR
    # oleaje: envolventes lentas e irregulares
    swell = 0.55 + 0.45 * np.sin(2 * np.pi * t / 6.0) * np.sin(2 * np.pi * t / 9.7 + 1)
    swell = np.clip(swell, 0.1, 1) ** 1.5
    hiss = lowpass(noise, 0.25) - lowpass(noise, 0.06)
    x = soft * 2.2 * swell + hiss * 0.25 * swell ** 3
    x = x / np.max(np.abs(x)) * 0.5
    return seamless(x)


def night(seconds=16, seed=2):
    rng = np.random.default_rng(seed)
    n = SR * seconds
    t = np.arange(n) / SR
    x = lowpass(rng.standard_normal(n), 0.02) * 0.6
    # grillos: pulsos agudos en grupos
    for k in range(int(seconds * 1.6)):
        start = rng.uniform(0, seconds - 0.4)
        f = rng.uniform(4200, 4800)
        for j in range(3):
            s = int((start + j * 0.06) * SR)
            m = int(0.035 * SR)
            tt = np.arange(m) / SR
            x[s:s + m] += np.sin(2 * np.pi * f * tt) * np.sin(np.pi * tt / 0.035) * 0.06
    x = x / np.max(np.abs(x)) * 0.35
    return seamless(x)


def bird(seed):
    rng = np.random.default_rng(seed)
    out = []
    for k in range(rng.integers(2, 5)):
        d = rng.uniform(0.06, 0.14)
        m = int(d * SR)
        tt = np.arange(m) / SR
        f0 = rng.uniform(2600, 3600)
        f1 = f0 * rng.uniform(1.15, 1.5)
        f = np.linspace(f0, f1, m) if k % 2 == 0 else np.linspace(f1, f0, m)
        ph = 2 * np.pi * np.cumsum(f) / SR
        out.append(np.sin(ph) * np.sin(np.pi * tt / d) ** 2 * 0.3)
        out.append(np.zeros(int(rng.uniform(0.03, 0.09) * SR)))
    return np.concatenate(out)


def step(seed, kind):
    rng = np.random.default_rng(seed)
    m = int(0.09 * SR)
    noise = rng.standard_normal(m)
    a = {"grass": 0.18, "sand": 0.12, "dirt": 0.22, "stone": 0.45, "wood": 0.3}[kind]
    x = lowpass(noise, a) * env(m, 0.004, 0.07)
    if kind == "wood":
        tt = np.arange(m) / SR
        x += np.sin(2 * np.pi * 180 * tt) * np.exp(-tt * 60) * 0.5
    if kind == "stone":
        x = x - lowpass(x, 0.1)
    return x / np.max(np.abs(x)) * 0.35


def tone(freq, dur, vol=0.3, harm=(1, 0.3, 0.1), decay=6.0):
    m = int(dur * SR)
    tt = np.arange(m) / SR
    x = sum(a * np.sin(2 * np.pi * freq * (i + 1) * tt) for i, a in enumerate(harm))
    return x * np.exp(-tt * decay) * env(m, 0.003, 0.02) * vol


def ui_tap():
    return tone(880, 0.08, 0.22, (1, 0.2), 30)


def ui_open():
    return np.concatenate([tone(660, 0.07, 0.18, (1, 0.2), 25), tone(990, 0.16, 0.18, (1, 0.25), 18)])


def chime():
    a = tone(1046.5, 1.2, 0.18, (1, 0.35, 0.12), 3.5)
    b = np.concatenate([np.zeros(int(0.12 * SR)), tone(1318.5, 1.1, 0.14, (1, 0.3, 0.1), 3.5)])
    n = max(len(a), len(b))
    return np.pad(a, (0, n - len(a))) + np.pad(b, (0, n - len(b)))


def click():
    return tone(1400, 0.05, 0.2, (1, 0.5), 60)


def music_box(seconds_per_beat=0.5):
    """Melodía original de caja de música (do mayor, I-vi-IV-V), en bucle."""
    notes = {"C4": 261.6, "D4": 293.7, "E4": 329.6, "F4": 349.2, "G4": 392.0, "A4": 440.0, "B4": 493.9,
             "C5": 523.3, "D5": 587.3, "E5": 659.3, "G5": 784.0, "A3": 220.0, "F3": 174.6, "G3": 196.0, "C3": 130.8, "E3": 164.8}
    melody = ["E5", "-", "G5", "E5", "D5", "-", "C5", "-", "A4", "-", "C5", "D5", "E5", "-", "-", "-",
              "C5", "-", "A4", "C5", "D5", "-", "E5", "D5", "B4", "-", "G4", "-", "D5", "-", "-", "-",
              "E5", "-", "G5", "A5" if False else "G5", "E5", "-", "D5", "C5", "A4", "-", "G4", "A4", "C5", "-", "-", "-",
              "D5", "-", "E5", "D5", "C5", "-", "B4", "-", "C5", "-", "-", "-", "-", "-", "-", "-"]
    bass = ["C3", "A3", "F3", "G3"]
    beat = seconds_per_beat / 2
    total = len(melody) * beat
    n = int(total * SR) + SR * 2
    out = np.zeros(n)
    for i, nm in enumerate(melody):
        if nm == "-":
            continue
        s = int(i * beat * SR)
        x = tone(notes[nm], 1.6, 0.16, (1, 0.4, 0.15, 0.05), 2.6)
        out[s:s + len(x)] += x[: max(0, min(len(x), n - s))]
    bars = len(melody) // 8
    for b in range(bars):
        nm = bass[b % 4]
        for k in (0, 4):
            s = int((b * 8 + k) * beat * SR)
            x = tone(notes[nm], 2.0, 0.10, (1, 0.2), 1.5)
            out[s:s + len(x)] += x[: max(0, min(len(x), n - s))]
    loop_len = int(total * SR)
    tail = out[loop_len:]
    out = out[:loop_len]
    out[: len(tail)] += tail  # la cola de las notas finales suena sobre el inicio
    return out / np.max(np.abs(out)) * 0.5


def build(out):
    write(f"{out}/amb_waves.wav", waves())
    write(f"{out}/amb_night.wav", night())
    for i in range(3):
        write(f"{out}/bird_{i}.wav", bird(10 + i))
    for kind in ["grass", "sand", "dirt", "stone", "wood"]:
        for i in range(2):
            write(f"{out}/step_{kind}_{i}.wav", step(20 + i, kind))
    write(f"{out}/ui_tap.wav", ui_tap())
    write(f"{out}/ui_open.wav", ui_open())
    write(f"{out}/chime.wav", chime())
    write(f"{out}/click.wav", click())
    write(f"{out}/music_island.wav", music_box())
    print("audio ok")


if __name__ == "__main__":
    import sys

    build(sys.argv[1])
