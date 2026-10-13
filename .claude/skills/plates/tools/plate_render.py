"""Rasterise plate_dump.lua's out.txt to one PNG per page and print what
overlaps. Run through plates.sh, or: python3 -I plate_render.py <dir>

Draws, in page px (the right page, 466 x 534, from its top left): the page
edge and its 10 px margin, the not-kept line (OFF in UI/JournalJourney.lua,
x 246 y 512, shown with "Keep my own route" off) in red, each plate's card,
art box, photo corners and shadow (SHADOW/LIFT from the dump's CONST line),
headings (dark blue) and caption words (light blue) as boxes, margin notes
as cream boxes with their leaders.

Checks: plate x plate/caption/note overlaps (shadow included), a lifted
corner's shadow past the page, text past the foot (528), anything over the
not-kept line. Text widths are estimates: a hit near an edge is a hint to
look, a clean render is not proof (screenshots are).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngio import write_png  # noqa: E402

W, H = 466, 534
OX, OY = 30, 40
CW, CH = W + 2 * OX, H + OY + 40
OFF_X, OFF_Y = 246, 512
SHADOW_OUT, SHADOW_BLUR, GAIN, SPREAD, LIFT_H, REACH = 1.0, 3.5, 0.30, 0.60, 6, 46


def parse(path):
    global SHADOW_OUT, SHADOW_BLUR, GAIN, SPREAD, LIFT_H, REACH
    pages, cur = [], None
    for line in open(path):
        line = line.rstrip("\n")
        if line.startswith("CONST "):
            SHADOW_OUT, SHADOW_BLUR, GAIN, SPREAD, LIFT_H, REACH = [float(v) for v in line.split(" ")[1:]]
        elif line.startswith("PAGE "):
            _, label, pattern = line.split(" ", 2)
            cur = {"label": label, "pattern": pattern, "plates": [], "texts": [], "notes": [], "prints": []}
            pages.append(cur)
        elif line.startswith("PLATE "):
            p = line.split(" ")
            cur["plates"].append({"i": int(p[1]), "x": float(p[2]), "y": float(p[3]), "w": float(p[4]),
                                  "h": float(p[5]), "t": float(p[6]), "pad": float(p[7]), "pc": float(p[8]),
                                  "corners": [c for c in p[9].split(",") if c], "lift": None if p[10] == "-" else p[10]})
        elif line.startswith("TEXT "):
            head, text = line.split("|", 1)
            p = head.split(" ")
            cur["texts"].append({"kind": p[1], "x": float(p[2]), "y": float(p[3]), "w": float(p[4]),
                                 "h": float(p[5]), "align": p[6], "text": text})
        elif line.startswith("PRINTSLIP "):
            p = line.split(" ")
            v = [float(x) for x in p[3:]]
            cur["prints"].append({"i": int(p[1]), "part": p[2], "poly": [(v[k], v[k + 1]) for k in range(0, len(v), 2)]})
        elif line.startswith("NOTE "):
            p = [float(v) for v in line.split(" ")[1:]]
            cur["notes"].append({"x": p[0], "y": p[1], "w": p[2], "h": p[3], "mx": p[4], "my": p[5]})
    return pages


def to_page(pl, u, v):
    a = math.radians(pl["t"])
    cx, cy = pl["x"] + pl["w"] / 2, pl["y"] + pl["h"] / 2
    lx, ly = u - pl["w"] / 2, v - pl["h"] / 2
    return cx + lx * math.cos(a) - ly * math.sin(a), cy + lx * math.sin(a) + ly * math.cos(a)


def reach(pl, u, v):
    if not pl["lift"]:
        return SHADOW_OUT + SHADOW_BLUR
    cx = pl["w"] if pl["lift"] == "br" else 0
    d = max(abs(u - cx), abs(v - pl["h"]))
    h = LIFT_H * max(0.0, 1 - d / REACH)
    return SHADOW_OUT + SHADOW_BLUR + (GAIN + SPREAD) * h


def shadow_poly(pl):
    w, h = pl["w"], pl["h"]
    pts = [(0, 0), (w, 0)]
    n = 40
    for k in range(n + 1):
        v = h * k / n
        pts.append((w + reach(pl, w, v), v))
    pts.append((w + reach(pl, w, h), h + reach(pl, w, h)))
    for k in range(n, -1, -1):
        u = w * k / n
        pts.append((u, h + reach(pl, u, h)))
    pts.append((0, h))
    return [to_page(pl, u, v) for u, v in pts]


def card_poly(pl):
    w, h = pl["w"], pl["h"]
    return [to_page(pl, u, v) for u, v in ((0, 0), (w, 0), (w, h), (0, h))]


def art_poly(pl):
    w, h, p = pl["w"], pl["h"], pl["pad"]
    return [to_page(pl, u, v) for u, v in ((p, p), (w - p, p), (w - p, h - p), (p, h - p))]


def corner_polys(pl):
    w, h, L, o = pl["w"], pl["h"], 0.7 * pl["pc"], 3.5
    out = []
    for c in pl["corners"]:
        if c == "tl":
            q = [(-o, -o), (-o + L, -o), (-o, -o + L)]
        elif c == "tr":
            q = [(w + o, -o), (w + o - L, -o), (w + o, -o + L)]
        elif c == "bl":
            q = [(-o, h + o), (-o + L, h + o), (-o, h + o - L)]
        else:
            q = [(w + o, h + o), (w + o - L, h + o), (w + o, h + o - L)]
        out.append([to_page(pl, u, v) for u, v in q])
    return out


def inside(poly, x, y):
    c = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            c = not c
    return c


def mask(poly):
    xs, ys = [p[0] for p in poly], [p[1] for p in poly]
    m = set()
    for y in range(int(math.floor(min(ys))), int(math.ceil(max(ys))) + 1):
        for x in range(int(math.floor(min(xs))), int(math.ceil(max(xs))) + 1):
            if inside(poly, x + 0.5, y + 0.5):
                m.add((x, y))
    return m


def rect(x, y, w, h):
    return [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]


def text_rect(t):
    if t["kind"] == "headingPool":
        tw = min(t["w"], len(t["text"]) * 7)
    else:
        tw = t["w"] if t["h"] > 16 else min(t["w"], len(t["text"]) * 6.6)
    x = t["x"] + (t["w"] - tw if t["align"] == "RIGHT" else 0)
    return rect(x, t["y"], tw, t["h"])


def render(page, path):
    buf = [0.0] * (CW * CH * 3)

    def put(x, y, col, a=1.0):
        px, py = int(x) + OX, int(y) + OY
        if 0 <= px < CW and 0 <= py < CH:
            i = (py * CW + px) * 3
            for k in range(3):
                buf[i + k] = buf[i + k] * (1 - a) + col[k] * a

    for y in range(CH):
        for x in range(CW):
            col = (0.80, 0.72, 0.54) if (-20 <= y - OY < H + 14 and 0 <= x - OX < W + 20) else (0.25, 0.17, 0.10)
            i = (y * CW + x) * 3
            buf[i:i + 3] = col

    def fill(poly, col, a=1.0):
        for x, y in mask(poly):
            put(x, y, col, a)

    def outline(poly, col):
        n = len(poly)
        for i in range(n):
            x1, y1 = poly[i]
            x2, y2 = poly[(i + 1) % n]
            steps = int(max(abs(x2 - x1), abs(y2 - y1))) + 1
            for s in range(steps + 1):
                put(x1 + (x2 - x1) * s / steps, y1 + (y2 - y1) * s / steps, col)

    outline(rect(0, 0, W, H), (0.45, 0.35, 0.2))
    outline(rect(10, 10, W - 20, H - 20), (0.62, 0.52, 0.36))
    fill(rect(OFF_X, OFF_Y, 200, 14), (0.8, 0.2, 0.2), 0.25)
    for pl in page["plates"]:
        fill(shadow_poly(pl), (0.30, 0.22, 0.12), 0.45)
    for pl in page["plates"]:
        fill(card_poly(pl), (0.97, 0.94, 0.86))
        fill(art_poly(pl), (0.55, 0.60, 0.42))
        for c in corner_polys(pl):
            fill(c, (0.29, 0.19, 0.10))
    for t in page["texts"]:
        col = (0.2, 0.25, 0.7) if t["kind"] == "headingPool" else (0.15, 0.45, 0.75)
        fill(text_rect(t), col, 0.45)
    # Good luck on a print (S): the slip in the card's stock, its tag
    # fresher, the icon dark, each outlined.
    for pr in page["prints"]:
        col = {"label": (0.93, 0.87, 0.70), "tag": (1.0, 0.97, 0.88), "icon": (0.35, 0.25, 0.45)}[pr["part"]]
        fill(pr["poly"], col)
        outline(pr["poly"], (0.25, 0.15, 0.05))
    for n in page["notes"]:
        fill(rect(n["x"], n["y"], n["w"], n["h"]), (0.95, 0.90, 0.75), 0.9)
        outline(rect(n["x"], n["y"], n["w"], n["h"]), (0.3, 0.5, 0.2))
        cx, cy = min(max(n["mx"], n["x"]), n["x"] + n["w"]), min(max(n["my"], n["y"]), n["y"] + n["h"])
        outline([(cx, cy), (n["mx"], n["my"])], (0.3, 0.3, 0.3))
    write_png(path, CW, CH, buf)


def check(page):
    issues = []
    els = []
    for pl in page["plates"]:
        body = mask(card_poly(pl))
        for c in corner_polys(pl):
            body |= mask(c)
        els.append(("plate%d" % pl["i"], body, mask(shadow_poly(pl)) | body))
        if pl["lift"]:
            sp = shadow_poly(pl)
            mx, my, mn = max(p[0] for p in sp), max(p[1] for p in sp), min(p[0] for p in sp)
            corner = to_page(pl, pl["w"] if pl["lift"] == "br" else 0, pl["h"])
            issues.append("lift %s corner at %.1f,%.1f; shadow to x %.1f..%.1f, y %.1f" % (
                pl["lift"], corner[0], corner[1], mn, mx, my))
            if mx > W or my > H or mn < 0:
                issues.append("  !! lifted shadow past the frame")
    for k, t in enumerate(page["texts"]):
        r = text_rect(t)
        els.append(("text%d(%s)" % (k, t["text"][:18]), mask(r), mask(r)))
        if r[1][0] > OFF_X and r[2][1] > OFF_Y - 6 and r[0][0] < OFF_X + 200:
            issues.append("  ~ caption over the not-kept line (ends %.0f): %s" % (r[2][1], t["text"][:30]))
        if r[2][1] > 528:
            issues.append("  !! text past the foot: %s" % t["text"][:30])
    for k, n in enumerate(page["notes"]):
        r = rect(n["x"], n["y"], n["w"], n["h"])
        els.append(("note%d" % k, mask(r), mask(r)))
    # S on a print: its icon never on its tag; all of it on its print but
    # the tag's foot (PRINT: about 4 px past it, plus the turn); never over
    # a caption, another plate or the not-kept line.
    parts = {}
    for pr in page["prints"]:
        parts.setdefault(pr["i"], {})[pr["part"]] = pr["poly"]
    for i, ps in parts.items():
        pl = [p for p in page["plates"] if p["i"] == i][0]
        icon, tag, label = mask(ps["icon"]), mask(ps["tag"]), mask(ps["label"])
        if icon & tag:
            issues.append("  !! S on plate%d: its icon on its tag: %d px" % (i, len(icon & tag)))
        card = mask(card_poly(pl))
        for name in ("label", "icon"):
            off = mask(ps[name]) - card
            if off:
                issues.append("  !! S on plate%d: its %s off the print: %d px" % (i, name, len(off)))
        lowest = max(p[1] for p in ps["tag"])
        foot = max(p[1] for p in card_poly(pl))
        issues.append("S on plate%d: x %.1f..%.1f, tag foot y %.1f (the print's %.1f)" % (
            i, min(p[0] for p in ps["label"]), max(p[0] for p in ps["icon"]), lowest, foot))
        if lowest - foot > 8:
            issues.append("  !! S on plate%d: its tag hangs %.1f px past the print" % (i, lowest - foot))
        body = icon | tag | label
        els.append(("S%d" % i, body, body))
    # The not-kept line and its link (OFF: x 246, y 512), shown with the
    # setting off; notes then stop at 506 (offLimit), so only plates and
    # captions are asked of it.
    off = mask(rect(OFF_X, OFF_Y, 210, 30))
    for name, body, reach in els:
        if name.startswith("note"):
            continue
        if body & off:
            issues.append("  !! %s over the not-kept line: %d px" % (name, len(body & off)))
        elif reach & off:
            issues.append("  ~ %s's shadow over the not-kept line: %d px" % (name, len(reach & off)))
    for pl in page["plates"]:
        ys = [p[1] for p in card_poly(pl)] + [p[1] for c in corner_polys(pl) for p in c]
        xs = [p[0] for p in card_poly(pl)] + [p[0] for c in corner_polys(pl) for p in c]
        issues.append("plate%d spans x %.1f..%.1f, y %.1f..%.1f" % (pl["i"], min(xs), max(xs), min(ys), max(ys)))
    for i in range(len(els)):
        for j in range(i + 1, len(els)):
            a, b = els[i], els[j]
            # S lies on its own print.
            if {a[0], b[0]} == {"plate" + a[0][1:], "S" + a[0][1:]} or {a[0], b[0]} == {"plate" + b[0][1:], "S" + b[0][1:]}:
                continue
            hit = len(a[1] & b[2]) + len(b[1] & a[2])
            if hit:
                issues.append("  !! %s x %s: %d px" % (a[0], b[0], hit))
    return issues


out_dir = sys.argv[1] if len(sys.argv) > 1 else "/tmp/sd-plates"
only = set(sys.argv[2:])
for page in parse(os.path.join(out_dir, "out.txt")):
    if only and page["label"] not in only and page["pattern"] not in only:
        continue
    render(page, os.path.join(out_dir, "%s.png" % page["label"].replace("+", "p")))
    print("==", page["label"], page["pattern"])
    for line in check(page):
        print("  ", line)
