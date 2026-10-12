"""Drawing toolkit for purplerepo: logo, tweak icons. Pure PIL + numpy."""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

S = 1024  # working resolution


# ---------------------------------------------------------------- basics
def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lin_grad(size, c1, c2, angle=135):
    w, h = size
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    a = math.radians(angle)
    dx, dy = math.cos(a), math.sin(a)
    span = abs(w * dx) + abs(h * dy)
    t = ((xs - w / 2) * dx + (ys - h / 2) * dy) / span + 0.5
    t = np.clip(t, 0, 1)[..., None]
    arr = np.array(c1, np.float32) * (1 - t) + np.array(c2, np.float32) * t
    return Image.fromarray(arr.astype(np.uint8), "RGB").convert("RGBA")


def radial_glow(size, center, radius, color, strength):
    w, h = size
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt((xs - center[0]) ** 2 + (ys - center[1]) ** 2) / radius
    a = np.clip(1 - d, 0, 1) ** 2 * strength
    layer = np.zeros((h, w, 4), np.float32)
    layer[..., 0], layer[..., 1], layer[..., 2] = color
    layer[..., 3] = a * 255
    return Image.fromarray(layer.astype(np.uint8), "RGBA")


def grain(img, amount=7, seed=3):
    rng = np.random.default_rng(seed)
    arr = np.array(img.convert("RGBA"), np.float32)
    n = rng.normal(0, amount, arr.shape[:2])[..., None]
    arr[..., :3] = np.clip(arr[..., :3] + n, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def squircle_mask(size, n=5.0, ss=2):
    w = size * ss
    ys, xs = np.mgrid[0:w, 0:w].astype(np.float32)
    x = (xs - w / 2 + 0.5) / (w / 2)
    y = (ys - w / 2 + 0.5) / (w / 2)
    inside = (np.abs(x) ** n + np.abs(y) ** n) <= 1.0
    m = Image.fromarray((inside * 255).astype(np.uint8), "L")
    return m.resize((size, size), Image.LANCZOS)


def squircle(img, n=5.0):
    """Cut an RGBA image to an iOS-style squircle (transparent corners)."""
    size = img.size[0]
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), squircle_mask(size, n))
    return out


def shadow(layer, offset=(0, 18), blur=22, opacity=0.35, color=(0, 0, 0)):
    a = layer.split()[3]
    sh = Image.new("RGBA", layer.size, color + (0,))
    sh.putalpha(a.point(lambda v: int(v * opacity)))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.alpha_composite(sh, offset)
    return out


def poly_layer(pts, fill, size=(S, S)):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m


def gradient_poly(pts, c1, c2, angle, size=(S, S)):
    base = lin_grad(size, c1, c2, angle)
    base.putalpha(poly_layer(pts, 255, size))
    return base


def font(name, px):
    paths = {
        "poppins-b": "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf",
        "poppins-m": "/usr/share/fonts/truetype/google-fonts/Poppins-Medium.ttf",
        "poppins-r": "/usr/share/fonts/truetype/google-fonts/Poppins-Regular.ttf",
        "mono": "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "mono-b": "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf",
    }
    return ImageFont.truetype(paths[name], px)


# ---------------------------------------------------------------- repo logo
def cube(cx, cy, s, light=None, mid=None, dark=None, edge=True, canvas=S):
    """Flat-faceted isometric cube, returns RGBA layer (canvas x canvas)."""
    light = light or ("#E4D2FF", "#BE9BFF")
    mid = mid or ("#9A66F7", "#7A3FE0")
    dark = dark or ("#5B2FBE", "#3B1A86")
    k = math.sqrt(3) / 2
    top = (cx, cy - s)
    rt = (cx + k * s, cy - s / 2)
    rb = (cx + k * s, cy + s / 2)
    bot = (cx, cy + s)
    lb = (cx - k * s, cy + s / 2)
    lt = (cx - k * s, cy - s / 2)
    ctr = (cx, cy)
    size = (canvas, canvas)
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    layer.alpha_composite(gradient_poly([top, rt, ctr, lt], hexc(light[0]), hexc(light[1]), 90, size))
    layer.alpha_composite(gradient_poly([lt, ctr, bot, lb], hexc(mid[0]), hexc(mid[1]), 60, size))
    layer.alpha_composite(gradient_poly([rt, rb, bot, ctr], hexc(dark[0]), hexc(dark[1]), 100, size))
    if edge:
        d = ImageDraw.Draw(layer)
        w = max(2, int(s * 0.018))
        d.line([lt, top, rt], fill=(255, 255, 255, 215), width=w, joint="curve")
        d.line([lt, ctr, rt], fill=(255, 255, 255, 80), width=max(1, w // 2))
        d.line([ctr, bot], fill=(255, 255, 255, 60), width=max(1, w // 2))
    return layer


def logo_classic(size=1024, rounded=False):
    bg = lin_grad((S, S), hexc("#241046"), hexc("#12082A"), 120)
    bg.alpha_composite(radial_glow((S, S), (S * 0.5, S * 0.42), S * 0.62, (124, 58, 237), 0.30))
    bg = grain(bg, 6)
    c = cube(S / 2, S * 0.50, S * 0.30)
    sh = shadow(c, offset=(0, 34), blur=30, opacity=0.45, color=(6, 2, 20))
    bg.alpha_composite(sh)
    bg.alpha_composite(c)
    out = bg.resize((size, size), Image.LANCZOS)
    return squircle(out) if rounded else out.convert("RGB")



# ---------------------------------------------------------------- character cube (from a hand drawing)
PURPLE = (134, 44, 237)
BLACK = (8, 6, 12)
OLIVE = (85, 117, 32)
WHITE = (252, 252, 252)


def _chaikin(pts, iters=3):
    pts = [tuple(p) for p in pts]
    for _ in range(iters):
        out = []
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            out.append((0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]))
            out.append((0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1]))
        pts = out
    return pts


def _wobble(pts, amp, seed, smooth=5):
    """Nudge a closed outline by a smooth random amount, so edges look hand-drawn."""
    rng = np.random.default_rng(seed)
    n = len(pts)
    off = rng.normal(0, 1, (n, 2))
    k = np.ones(smooth) / smooth
    for c in range(2):
        padded = np.concatenate([off[-smooth:, c], off[:, c], off[:smooth, c]])
        off[:, c] = np.convolve(padded, k, mode="same")[smooth:-smooth]
    off = off / (np.abs(off).max() + 1e-6) * amp
    return [(p[0] + o[0], p[1] + o[1]) for p, o in zip(pts, off)]


def _densify(pts, step):
    out = []
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        d = math.hypot(b[0] - a[0], b[1] - a[1])
        n = max(1, int(d / step))
        for j in range(n):
            t = j / n
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


def _round_rect(x0, y0, x1, y1, r, step=18):
    pts = []
    for cx, cy, a0 in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for k in range(0, 91, 10):
            a = math.radians(a0 + k)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return _densify(pts, step)


def _mask(pts, ss=2, size=S):
    m = Image.new("L", (size * ss, size * ss), 0)
    ImageDraw.Draw(m).polygon([(x * ss, y * ss) for x, y in pts], fill=255)
    return m.resize((size, size), Image.LANCZOS)


def _fill(layer, mask, color):
    solid = Image.new("RGBA", layer.size, color + (255,))
    solid.putalpha(mask)
    layer.alpha_composite(solid)


def _circle_pts(cx, cy, r, n=48):
    return [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def character_front(x0, y0, w, h, seed=7):
    """The front face, redrawn from the hand drawing. (x0,y0,w,h) is the face box on the S canvas."""
    k = w / 410.0                                    # the drawing's face is ~410 px wide
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    def P(ix, iy):                                   # drawing coordinates -> canvas
        return (x0 + (ix - 10) * k, y0 + (iy - 10) * k)

    face = _wobble(_round_rect(x0, y0, x0 + w, y0 + h, 24 * k), 3.5 * k, seed)
    fm = _mask(face)
    _fill(layer, fm, PURPLE)

    # black lower half with a slightly wavy top edge, as drawn
    top = [P(-40, 252), P(30, 236), P(120, 232), P(220, 226), P(320, 232), P(420, 240), P(470, 250)]
    band = _chaikin(top + [P(470, 480), P(-40, 480)], 2)
    bm = _mask(band)
    black_m = Image.new("L", (S, S), 0)
    black_m.paste(bm, (0, 0), fm)
    _fill(layer, black_m, BLACK)

    # moustache (olive)
    must = [P(72, 246), P(90, 232), P(122, 232), P(146, 214), P(176, 213), P(204, 224), P(236, 220),
            P(270, 230), P(296, 242), P(286, 258), P(262, 264), P(236, 274), P(206, 268),
            P(176, 276), P(140, 272), P(104, 274), P(80, 266)]
    _fill(layer, _mask(_wobble(_chaikin(must, 3), 2 * k, seed + 1)), OLIVE)

    # white mouth, two lobes at the bottom
    mouth = [P(150, 276), P(214, 276), P(236, 296), P(250, 330), P(248, 354), P(228, 368), P(204, 364),
             P(188, 350), P(176, 364), P(150, 368), P(130, 352), P(128, 322), P(134, 296)]
    _fill(layer, _mask(_wobble(_chaikin(mouth, 3), 2 * k, seed + 2)), WHITE)
    for cx, cy, r in ((176, 277, 4.5), (186, 320, 5.5)):
        _fill(layer, _mask(_circle_pts(*P(cx, cy), r * k)), BLACK)

    # eyes with their little highlights
    for cx, cy, hx in ((113, 115, 91), (328, 118, 352)):
        eye = _wobble(_circle_pts(*P(cx, cy), 33 * k, 56), 1.4 * k, seed + cx)
        _fill(layer, _mask(eye), BLACK)
        _fill(layer, _mask(_circle_pts(*P(hx, cy + 4), 4.2 * k, 20)), WHITE)
    return layer


def character_cube(canvas=S):
    """Cube: the drawn face on the front, lighter purple on top, darker side on the right."""
    w, h = 540, 482                                  # face box (keeps the drawing's proportions)
    x0, y0 = 170, 330
    dx, dy = 128, -104                               # depth offset
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    tl, tr, br, bl = (x0, y0), (x0 + w, y0), (x0 + w, y0 + h), (x0, y0 + h)
    top = [tl, tr, (tr[0] + dx, tr[1] + dy), (tl[0] + dx, tl[1] + dy)]
    side = [tr, br, (br[0] + dx, br[1] + dy), (tr[0] + dx, tr[1] + dy)]

    def soft(poly, seed, amp=3):
        return _wobble(_chaikin(_densify(poly, 24), 2), amp, seed)

    # top face (light purple, soft gradient)
    tm = _mask(soft(top, 11))
    g = lin_grad((S, S), hexc("#C9A2FF"), hexc("#A56BF7"), 70)
    g.putalpha(tm)
    layer.alpha_composite(g)

    # side face: deep purple above, black below (continuing the black band)
    sm = _mask(soft(side, 12))
    sg = lin_grad((S, S), hexc("#5E21B8"), hexc("#43168C"), 90)
    sg.putalpha(sm)
    layer.alpha_composite(sg)
    yb = y0 + 0.60 * h
    black_side = [(tr[0], yb), (tr[0] + dx, yb + dy), (br[0] + dx, br[1] + dy), br]
    bm = _mask(black_side)
    bmm = Image.new("L", (S, S), 0)
    bmm.paste(bm, (0, 0), sm)
    _fill(layer, bmm, BLACK)

    layer.alpha_composite(character_front(x0, y0, w, h))
    return layer


def logo(size=1024, rounded=False):
    bg = lin_grad((S, S), hexc("#4A2594"), hexc("#241052"), 125)
    bg.alpha_composite(radial_glow((S, S), (S * 0.5, S * 0.40), S * 0.70, (170, 110, 255), 0.34))
    bg = grain(bg, 6)
    c = character_cube()
    sh = shadow(c, offset=(10, 40), blur=34, opacity=0.50, color=(6, 2, 20))
    bg.alpha_composite(sh)
    bg.alpha_composite(c)
    out = bg.resize((size, size), Image.LANCZOS)
    return squircle(out) if rounded else out.convert("RGB")



# ---------------------------------------------------------------- tweak icons
class Glyph:
    """White glyph painter on a transparent layer."""

    def __init__(self, bgdark=(0, 0, 0)):
        self.l = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.l)
        self.bg = bgdark

    def rr(self, box, r, fill=None, outline=None, w=0):
        self.d.rounded_rectangle(box, r, fill=fill, outline=outline, width=w)

    def line(self, pts, w, fill=(255, 255, 255, 255)):
        self.d.line(pts, fill=fill, width=w, joint="curve")
        r = w / 2
        for p in (pts[0], pts[-1]):
            self.d.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=fill)

    def circle(self, c, r, fill=None, outline=None, w=0):
        self.d.ellipse((c[0] - r, c[1] - r, c[0] + r, c[1] + r), fill=fill, outline=outline, width=w)


W = (255, 255, 255, 255)


def g_tidy(g):
    # three tiles and one outlined "hidden" tile
    t, gap = 200, 56
    x0 = S / 2 - t - gap / 2
    y0 = S / 2 - t - gap / 2
    g.rr((x0, y0, x0 + t, y0 + t), 52, fill=W)
    g.rr((x0 + t + gap, y0, x0 + 2 * t + gap, y0 + t), 52, fill=W)
    g.rr((x0, y0 + t + gap, x0 + t, y0 + 2 * t + gap), 52, fill=W)
    g.rr((x0 + t + gap, y0 + t + gap, x0 + 2 * t + gap, y0 + 2 * t + gap), 52, outline=(255, 255, 255, 190), w=26)


def g_taplock(g):
    g.d.arc((352, 250, 672, 610), 180, 360, fill=W, width=64)
    g.line([(352, 430), (352, 520)], 64)
    g.line([(672, 430), (672, 520)], 64)
    g.rr((282, 470, 742, 800), 70, fill=W)
    g.circle((512, 600), 46, fill=g.bg + (255,))
    g.rr((492, 610, 532, 710), 18, fill=g.bg + (255,))


def g_quiet(g):
    sp = [(260, 420), (390, 420), (560, 270), (560, 754), (390, 604), (260, 604)]
    g.d.polygon(sp, fill=W)
    g.line([(250, 230), (790, 794)], 120, fill=g.bg + (255,))
    g.line([(250, 230), (790, 794)], 62, fill=W)


def g_tapfeel(g):
    g.circle((512, 512), 96, fill=W)
    g.circle((512, 512), 212, outline=(255, 255, 255, 235), w=34)
    g.circle((512, 512), 330, outline=(255, 255, 255, 130), w=30)


def g_battery(g):
    g.rr((210, 340, 780, 684), 84, outline=W, w=46)
    g.rr((796, 450, 850, 574), 22, fill=W)
    g.rr((268, 398, 600, 626), 36, fill=W)


def g_music(g):
    g.circle((380, 690), 92, fill=W)
    g.circle((650, 640), 92, fill=W)
    g.rr((444, 300, 488, 690), 18, fill=W)
    g.rr((714, 250, 758, 640), 18, fill=W)
    g.d.polygon([(444, 290), (758, 238), (758, 366), (444, 418)], fill=W)


def g_launch(g):
    g.circle((512, 512), 98, fill=W)
    g.circle((512, 512), 215, outline=(255, 255, 255, 240), w=34)
    for a in range(0, 360, 45):
        r1, r2 = 300, 372
        p1 = (512 + r1 * math.cos(math.radians(a)), 512 + r1 * math.sin(math.radians(a)))
        p2 = (512 + r2 * math.cos(math.radians(a)), 512 + r2 * math.sin(math.radians(a)))
        g.line([p1, p2], 32, fill=(255, 255, 255, 190))


def g_glass(g):
    g.rr((220, 270, 804, 754), 130, fill=(255, 255, 255, 62), outline=(255, 255, 255, 235), w=22)
    g.d.arc((232, 282, 560, 610), 180, 270, fill=(255, 255, 255, 255), width=26)
    g.rr((330, 640, 694, 678), 19, fill=(255, 255, 255, 120))


def g_link(g):
    g.rr((200, 380, 600, 644), 132, outline=W, w=52)
    g.rr((424, 380, 824, 644), 132, outline=W, w=52)


TWEAK_STYLES = {
    # id: (gradient c1, gradient c2, glyph fn)
    "tidy":         ("#2EC4B6", "#0B7A75", g_tidy),
    "taplock":      ("#6D5BFF", "#3A2BB5", g_taplock),
    "quiethud":     ("#5B6B86", "#2A3348", g_quiet),
    "tapfeel":      ("#FF6B8B", "#E8452C", g_tapfeel),
    "batteryline":  ("#6FD64A", "#1F9E4A", g_battery),
    "apptunes":     ("#FF8A3D", "#E0334C", g_music),
    "launchfx":     ("#7C3AED", "#3B1480", g_launch),
    "liquidglass":  ("#4DA3FF", "#6B4BFF", g_glass),
    "purplelink":   ("#8B5CF6", "#4C1D95", g_link),
}


def tweak_icon(key, size=1024, rounded=False):
    c1, c2, fn = TWEAK_STYLES[key]
    bg = lin_grad((S, S), hexc(c1), hexc(c2), 125)
    bg.alpha_composite(radial_glow((S, S), (S * 0.30, S * 0.18), S * 0.75, (255, 255, 255), 0.20))
    bg = grain(bg, 5, seed=hash(key) % 1000)
    darkest = tuple(int(v * 0.72) for v in hexc(c2))
    g = Glyph(bgdark=darkest)
    fn(g)
    bg.alpha_composite(shadow(g.l, offset=(0, 16), blur=16, opacity=0.28, color=(0, 0, 0)))
    bg.alpha_composite(g.l)
    out = bg.resize((size, size), Image.LANCZOS)
    return squircle(out) if rounded else out.convert("RGB")


# ---------------------------------------------------------------- banner
def banner(w=1600, h=480):
    bg = lin_grad((w, h), hexc("#1A0C38"), hexc("#0E0620"), 20)
    bg.alpha_composite(radial_glow((w, h), (w * 0.18, h * 0.5), h * 1.1, (124, 58, 237), 0.28))
    bg = grain(bg, 5)
    lg = logo(300, rounded=True)
    bg.alpha_composite(lg, (90, (h - 300) // 2))
    d = ImageDraw.Draw(bg)
    d.text((440, 120), "purplerepo", font=font("poppins-m", 128), fill=(245, 238, 255, 255))
    d.text((446, 285), "jailbreak tweaks & themes for iOS 12", font=font("mono", 36), fill=(190, 165, 245, 255))
    d.text((446, 345), "by purplesquarecube", font=font("mono", 30), fill=(130, 108, 190, 255))
    return bg.convert("RGB")


if __name__ == "__main__":
    import os
    os.makedirs("/home/claude/purple/out/preview", exist_ok=True)
    logo(512, True).save("/home/claude/purple/out/preview/logo.png")
    sheet = Image.new("RGBA", (4 * 270, 2 * 270), (22, 16, 36, 255))
    for i, k in enumerate(TWEAK_STYLES):
        sheet.alpha_composite(tweak_icon(k, 240, True), ((i % 4) * 270 + 15, (i // 4) * 270 + 15))
    sheet.save("/home/claude/purple/out/preview/tweaks.png")
    banner().save("/home/claude/purple/out/preview/banner.png")
    print("ok")
