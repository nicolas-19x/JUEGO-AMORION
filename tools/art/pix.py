"""Utilidades de dibujo pixel a pixel (sin interpolaciones, sin antialias)."""
import random
import numpy as np
from PIL import Image
from palette import CLEAR


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[CLEAR for _ in range(w)] for _ in range(h)]

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return CLEAR

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            if len(c) == 4 and c[3] < 255 and c[3] > 0:
                # mezcla alfa simple (solo para sombras / brillos)
                b = self.px[y][x]
                if b[3] == 0:
                    self.px[y][x] = c
                    return
                a = c[3] / 255.0
                self.px[y][x] = (
                    int(b[0] * (1 - a) + c[0] * a),
                    int(b[1] * (1 - a) + c[1] * a),
                    int(b[2] * (1 - a) + c[2] * a),
                    255,
                )
            else:
                self.px[y][x] = c

    def opaque(self, x, y):
        return self.get(x, y)[3] > 0

    def rect(self, x0, y0, w, h, c):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                self.put(x, y, c)

    def hline(self, x0, x1, y, c):
        for x in range(x0, x1 + 1):
            self.put(x, y, c)

    def vline(self, x, y0, y1, c):
        for y in range(y0, y1 + 1):
            self.put(x, y, c)

    def blit(self, other, ox, oy):
        for y in range(other.h):
            for x in range(other.w):
                c = other.px[y][x]
                if c[3] > 0:
                    self.put(ox + x, oy + y, c)

    def outline(self, c, only_empty=True):
        """Contorno exterior de 1px alrededor de los pixeles opacos."""
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.opaque(x, y):
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if self.opaque(x + dx, y + dy):
                        add.append((x, y))
                        break
        for x, y in add:
            self.put(x, y, c)

    def to_image(self):
        img = Image.new("RGBA", (self.w, self.h))
        img.putdata([c for row in self.px for c in row])
        return img

    @staticmethod
    def from_image(img):
        img = img.convert("RGBA")
        c = Canvas(img.width, img.height)
        data = list(img.getdata())
        for y in range(img.height):
            for x in range(img.width):
                c.px[y][x] = data[y * img.width + x]
        return c

    def flipped(self):
        c = Canvas(self.w, self.h)
        for y in range(self.h):
            c.px[y] = list(reversed(self.px[y]))
        return c


def from_ascii(rows, key):
    """Convierte arte ASCII en Canvas. key: dict carácter -> color (o None)."""
    h = len(rows)
    w = max(len(r) for r in rows)
    c = Canvas(w, h)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            col = key.get(ch)
            if col is not None:
                c.put(x, y, col)
    return c


def periodic_noise(size, cells, seed, octaves=1):
    """Ruido de valor periódico (tileable) en [0,1], shape (size,size)."""
    rng = np.random.default_rng(seed)
    total = np.zeros((size, size))
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        n = cells * (2 ** o)
        lat = rng.random((n, n))
        ys, xs = np.mgrid[0:size, 0:size] / size * n
        x0 = np.floor(xs).astype(int)
        y0 = np.floor(ys).astype(int)
        fx = xs - x0
        fy = ys - y0
        fx = fx * fx * (3 - 2 * fx)
        fy = fy * fy * (3 - 2 * fy)
        x1 = (x0 + 1) % n
        y1 = (y0 + 1) % n
        x0 %= n
        y0 %= n
        v = (lat[y0, x0] * (1 - fx) + lat[y0, x1] * fx) * (1 - fy) + (
            lat[y1, x0] * (1 - fx) + lat[y1, x1] * fx
        ) * fy
        total += v * amp
        norm += amp
        amp *= 0.5
    return total / norm


BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def dither_pick(value, x, y, levels):
    """Cuantiza value∈[0,1] en `levels` niveles con dithering ordenado suave."""
    v = value * (levels - 1)
    base = int(np.floor(v))
    frac = v - base
    if frac > BAYER4[y % 4][x % 4] * 0.9 + 0.05:
        base += 1
    return max(0, min(levels - 1, base))


def rng(seed):
    return random.Random(seed)


def save(canvas_or_img, path, scale=1):
    img = canvas_or_img.to_image() if isinstance(canvas_or_img, Canvas) else canvas_or_img
    if scale != 1:
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    img.save(path)
