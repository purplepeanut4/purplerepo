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


def logo(size=1024, rounded=False):
    bg = lin_grad((S, S), hexc("#241046"), hexc("#12082A"), 120)
    bg.alpha_composite(radial_glow((S, S), (S * 0.5, S * 0.42), S * 0.62, (124, 58, 237), 0.30))
    bg = grain(bg, 6)
    c = cube(S / 2, S * 0.50, S * 0.30)
    sh = shadow(c, offset=(0, 34), blur=30, opacity=0.45, color=(6, 2, 20))
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
