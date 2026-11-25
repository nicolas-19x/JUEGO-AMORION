#!/usr/bin/env python3
"""Prepara los audios generados con ElevenLabs para el juego.

Uso: python3 -I tools/process_audio.py <carpeta_mp3_originales> <carpeta_salida>

Para cada original (nombre_N.mp3):
  · recorta el silencio del principio y del final,
  · lo pasa a mono (efectos y voces) o lo deja en estéreo (música y ambiente),
  · normaliza el pico (efectos −1,5 dB, voces −3 dB, música −4 dB),
  · aplica fundidos cortos para evitar clics,
  · en música y ambiente crea un bucle sin costura (fundido cruzado cola → cabeza),
  · lo guarda como OGG Vorbis.
Necesita ffmpeg y numpy.
"""
import os
import subprocess
import sys

import numpy as np

SR = 44100


def decode(path, channels):
    cmd = ["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", str(channels), "-ar", str(SR), "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    a = np.frombuffer(raw, dtype=np.float32)
    return a.reshape(-1, channels).copy()


def trim(a, thresh_db=-48.0, keep_head=0.004, keep_tail=0.08):
    level = np.max(np.abs(a), axis=1)
    thr = 10 ** (thresh_db / 20)
    idx = np.where(level > thr)[0]
    if len(idx) == 0:
        return a
    s = max(0, idx[0] - int(keep_head * SR))
    e = min(len(a), idx[-1] + int(keep_tail * SR))
    return a[s:e]


def fade(a, head=0.002, tail=0.06):
    n_h = min(len(a) // 4, int(head * SR))
    n_t = min(len(a) // 2, int(tail * SR))
    if n_h:
        a[:n_h] *= np.linspace(0, 1, n_h)[:, None]
    if n_t:
        a[-n_t:] *= np.linspace(1, 0, n_t)[:, None]
    return a


def normalize(a, peak_db):
    m = float(np.max(np.abs(a)))
    if m < 1e-6:
        return a
    return a * (10 ** (peak_db / 20) / m)


def make_loop(a, seconds):
    """Fundido cruzado de la cola sobre la cabeza: el final enlaza con el principio."""
    n = int(seconds * SR)
    if len(a) < n * 3:
        return a
    head, body, tail = a[:n], a[n:-n], a[-n:]
    t = np.linspace(0, 1, n)[:, None]
    # potencia constante
    mix = tail * np.cos(t * np.pi / 2) + head * np.sin(t * np.pi / 2)
    return np.concatenate([mix, body], axis=0)


def encode(a, path, q=5):
    cmd = ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", str(a.shape[1]), "-i", "-",
           "-c:a", "libvorbis", "-q:a", str(q), path]
    subprocess.run(cmd, input=a.astype(np.float32).tobytes(), check=True)


# duración máxima (s) por familia; si se pasa, se corta con un fundido más largo
MAX_LEN = {"whoosh_p": 0.5, "whoosh_k": 0.8, "step": 0.35, "block": 0.45, "winded": 2.5, "spit": 2.2,
           "breath": 6.0, "effort": 0.7, "pain": 1.0, "scream": 2.0, "parry": 0.5, "fall": 1.6}


def cap_length(a, name):
    for pre, mx in MAX_LEN.items():
        if name.startswith(pre + "_"):
            n = int(mx * SR)
            if len(a) > n:
                a = a[:n].copy()
                f = min(n // 2, int(0.18 * SR))
                a[-f:] *= np.linspace(1, 0, f)[:, None]
            break
    return a


def kind_of(name):
    if name.startswith(("music_",)):
        return "music"
    if name.startswith("amb_"):
        return "ambience"
    if name.startswith(("vo_", "effort", "pain", "winded", "scream", "breath", "spit")):
        return "voice"
    return "sfx"


def main(src, dst):
    os.makedirs(dst, exist_ok=True)
    total = 0
    for f in sorted(os.listdir(src)):
        if not f.endswith(".mp3"):
            continue
        name = f[:-4]
        kind = kind_of(name)
        a = decode(os.path.join(src, f), 2 if kind in ("music", "ambience") else 1)
        a = trim(a, -55.0 if kind in ("music", "ambience") else -48.0)
        a = cap_length(a, name)
        if kind == "music":
            a = make_loop(a, 3.0)
            a = normalize(a, -4.0)
            q = 4
        elif kind == "ambience":
            a = make_loop(a, 2.0)
            a = normalize(a, -6.0)
            q = 4
        elif kind == "voice":
            a = normalize(fade(a), -3.0)
            q = 5
        else:
            a = normalize(fade(a), -1.5)
            q = 5
        out = os.path.join(dst, name + ".ogg")
        encode(a, out, q)
        size = os.path.getsize(out)
        total += size
        print("%-16s %-8s %6.2f s  %7d B" % (name, kind, len(a) / SR, size))
    print("total: %.2f MB" % (total / 1e6))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
