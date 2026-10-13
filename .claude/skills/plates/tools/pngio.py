"""Tiny PNG reader/writer, standard library only (zlib, struct).

Reads 8-bit RGB/RGBA non-interlaced PNGs (what macOS screenshots are) into
rows of floats 0..1, writes 8-bit RGB. Used by render_ink_trail.py.
"""
import struct
import zlib


def read_png(path):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    pos, idat, w = 8, [], None
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            w, h, depth, ctype, _, _, inter = struct.unpack(">IIBBBBB", chunk)
            assert depth == 8 and ctype in (2, 6) and inter == 0, (depth, ctype, inter)
            bpp = 3 if ctype == 2 else 4
        elif kind == b"IDAT":
            idat.append(chunk)
        elif kind == b"IEND":
            break
    raw = zlib.decompress(b"".join(idat))
    stride = w * bpp
    rows, prev, i = [], bytearray(stride), 0
    for _ in range(h):
        f = raw[i]
        line = bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        if f == 1:
            for x in range(bpp, stride):
                line[x] = (line[x] + line[x - bpp]) & 255
        elif f == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 255
        elif f == 3:
            for x in range(stride):
                left = line[x - bpp] if x >= bpp else 0
                line[x] = (line[x] + ((left + prev[x]) >> 1)) & 255
        elif f == 4:
            for x in range(stride):
                a = line[x - bpp] if x >= bpp else 0
                b = prev[x]
                c = prev[x - bpp] if x >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        rows.append(line)
        prev = line
    return w, h, bpp, rows


def pixel(img, x, y):
    """RGB floats at integer x, y (clamped)."""
    w, h, bpp, rows = img
    x = min(max(int(x), 0), w - 1)
    y = min(max(int(y), 0), h - 1)
    r = rows[y]
    o = x * bpp
    return r[o] / 255.0, r[o + 1] / 255.0, r[o + 2] / 255.0


def bilinear(img, x, y):
    x0, y0 = int(x), int(y)
    fx, fy = x - x0, y - y0
    a, b = pixel(img, x0, y0), pixel(img, x0 + 1, y0)
    c, d = pixel(img, x0, y0 + 1), pixel(img, x0 + 1, y0 + 1)
    return tuple((a[k] * (1 - fx) + b[k] * fx) * (1 - fy) + (c[k] * (1 - fx) + d[k] * fx) * fy for k in range(3))


def write_png(path, w, h, buf):
    """buf: flat list of floats r, g, b per pixel, row-major, 0..1."""
    out = bytearray()
    for y in range(h):
        out.append(0)
        base = y * w * 3
        for i in range(w * 3):
            v = buf[base + i]
            out.append(0 if v <= 0 else (255 if v >= 1 else int(v * 255 + 0.5)))

    def chunk(kind, payload):
        c = struct.pack(">I", len(payload)) + kind + payload
        return c + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(out), 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)
