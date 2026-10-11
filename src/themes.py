"""purplerepo themes: draws app glyphs once, renders them in five styles."""
import colorsys
import math
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

from art import S, grain, hexc, lin_grad, radial_glow, shadow, squircle, font


# ------------------------------------------------------------------ glyph painter
class GM:
    """Paints a glyph as masks. Unit coordinates (0..1)."""

    def __init__(self, lw=0.052):
        self.lw = lw * S
        self.solid = Image.new("L", (S, S), 0)
        self.addl = Image.new("L", (S, S), 0)
        self.cutl = Image.new("L", (S, S), 0)
        self.ds, self.da, self.dc = (ImageDraw.Draw(m) for m in (self.solid, self.addl, self.cutl))

    @staticmethod
    def P(p):
        return (p[0] * S, p[1] * S)

    # solid shapes
    def poly(self, pts, cut=False):
        self.ds.polygon([self.P(p) for p in pts], fill=0 if cut else 255)

    def rr(self, box, r, cut=False):
        b = (box[0] * S, box[1] * S, box[2] * S, box[3] * S)
        self.ds.rounded_rectangle(b, r * S, fill=0 if cut else 255)

    def circ(self, c, r, cut=False):
        x, y = self.P(c)
        self.ds.ellipse((x - r * S, y - r * S, x + r * S, y + r * S), fill=0 if cut else 255)

    # lines
    def _line(self, d, pts, w):
        w = w or self.lw
        pp = [self.P(p) for p in pts]
        d.line(pp, fill=255, width=int(w), joint="curve")
        for p in (pp[0], pp[-1]):
            d.ellipse((p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2), fill=255)

    def line(self, pts, w=None):
        self._line(self.da, pts, w)

    def cline(self, pts, w=None):          # subtractive in fill mode, additive in stroke mode
        self._line(self.dc, pts, w)

    def dot(self, c, r):
        x, y = self.P(c)
        self.da.ellipse((x - r * S, y - r * S, x + r * S, y + r * S), fill=255)

    def arc(self, c, r, a0, a1, w=None):
        x, y = self.P(c)
        w = w or self.lw
        self.da.arc((x - r * S, y - r * S, x + r * S, y + r * S), a0, a1, fill=255, width=int(w))
        for a in (a0, a1):
            px, py = x + r * S * math.cos(math.radians(a)), y + r * S * math.sin(math.radians(a))
            self.da.ellipse((px - w / 2, py - w / 2, px + w / 2, py + w / 2), fill=255)

    # final masks
    def fill_mask(self):
        m = ImageChops.lighter(self.solid, self.addl)
        return ImageChops.subtract(m, self.cutl)

    def stroke_mask(self):
        R = self.lw * 0.36
        b = self.solid.filter(ImageFilter.GaussianBlur(R))
        dil = b.point(lambda v: 255 if v > 22 else 0)
        ero = b.point(lambda v: 255 if v > 233 else 0)
        band = ImageChops.subtract(dil, ero).filter(ImageFilter.GaussianBlur(1.2))
        band = band.point(lambda v: min(255, int(v * 1.6)))
        m = ImageChops.lighter(band, self.addl)
        return ImageChops.lighter(m, self.cutl)


def rot(pts, c, deg):
    a = math.radians(deg)
    out = []
    for x, y in pts:
        dx, dy = x - c[0], y - c[1]
        out.append((c[0] + dx * math.cos(a) - dy * math.sin(a), c[1] + dx * math.sin(a) + dy * math.cos(a)))
    return out


def ngon(c, r, n, start=-90):
    return [(c[0] + r * math.cos(math.radians(start + i * 360 / n)),
             c[1] + r * math.sin(math.radians(start + i * 360 / n))) for i in range(n)]


# ------------------------------------------------------------------ the glyphs
def g_phone(g):
    pts = [(0.26, 0.30), (0.34, 0.22), (0.42, 0.33), (0.37, 0.41), (0.45, 0.55), (0.59, 0.63),
           (0.67, 0.58), (0.78, 0.66), (0.70, 0.74), (0.58, 0.77), (0.40, 0.68), (0.28, 0.50)]
    g.poly(pts)


def g_messages(g):
    g.rr((0.22, 0.27, 0.78, 0.65), 0.15)
    g.poly([(0.30, 0.60), (0.27, 0.78), (0.50, 0.63)])


def g_safari(g):
    g.circ((0.5, 0.5), 0.29)
    g.poly([(0.68, 0.32), (0.55, 0.55), (0.32, 0.68), (0.45, 0.45)], cut=True)
    g.dot((0.5, 0.5), 0.028)


def g_mail(g):
    g.rr((0.20, 0.29, 0.80, 0.71), 0.06)
    g.cline([(0.23, 0.33), (0.5, 0.55), (0.77, 0.33)], g.lw * 0.8)


def g_camera(g):
    g.rr((0.18, 0.34, 0.82, 0.72), 0.08)
    g.poly([(0.36, 0.34), (0.41, 0.26), (0.59, 0.26), (0.64, 0.34)])
    g.circ((0.5, 0.53), 0.135, cut=True)
    g.circ((0.5, 0.53), 0.06)


def g_photos(g):
    for k in range(8):
        a = math.radians(k * 45)
        g.circ((0.5 + 0.145 * math.cos(a), 0.5 + 0.145 * math.sin(a)), 0.105)
    g.circ((0.5, 0.5), 0.05, cut=True)


def g_settings(g):
    pts = []
    r1, r2 = 0.205, 0.285
    for i in range(8):
        a = i * 45
        for da, rr_ in ((-9, r2), (9, r2), (14, r1), (31, r1)):
            t = math.radians(a + da)
            pts.append((0.5 + rr_ * math.cos(t), 0.5 + rr_ * math.sin(t)))
    g.poly(pts)
    g.circ((0.5, 0.5), 0.09, cut=True)


def g_clock(g):
    g.circ((0.5, 0.5), 0.29)
    g.cline([(0.5, 0.5), (0.5, 0.30)], g.lw * 0.8)
    g.cline([(0.5, 0.5), (0.64, 0.58)], g.lw * 0.8)


def g_calendar(g):
    g.rr((0.23, 0.25, 0.77, 0.77), 0.07)
    g.cline([(0.26, 0.42), (0.74, 0.42)], g.lw * 0.7)
    for x in (0.37, 0.5, 0.63):
        for y in (0.53, 0.65):
            g.rr((x - 0.03, y - 0.03, x + 0.03, y + 0.03), 0.01, cut=True)


def g_notes(g):
    g.rr((0.27, 0.22, 0.73, 0.78), 0.06)
    for y in (0.38, 0.5, 0.62):
        g.cline([(0.35, y), (0.65, y)], g.lw * 0.65)


def g_reminders(g):
    for y in (0.34, 0.50, 0.66):
        g.dot((0.31, y), 0.04)
        g.line([(0.43, y), (0.71, y)], g.lw * 0.8)


def g_maps(g):
    g.circ((0.5, 0.42), 0.20)
    g.poly([(0.335, 0.53), (0.5, 0.80), (0.665, 0.53)])
    g.circ((0.5, 0.42), 0.075, cut=True)


def g_weather(g):
    g.circ((0.39, 0.40), 0.12)
    for k in range(8):
        a = math.radians(k * 45 - 20)
        g.line([(0.39 + 0.17 * math.cos(a), 0.40 + 0.17 * math.sin(a)),
                (0.39 + 0.22 * math.cos(a), 0.40 + 0.22 * math.sin(a))], g.lw * 0.6)
    g.circ((0.44, 0.66), 0.115)
    g.circ((0.58, 0.62), 0.15)
    g.circ((0.70, 0.69), 0.095)
    g.rr((0.42, 0.66, 0.72, 0.775), 0.05)


def g_music(g):
    g.circ((0.38, 0.69), 0.09)
    g.circ((0.64, 0.63), 0.09)
    g.rr((0.45, 0.30, 0.49, 0.69), 0.02)
    g.rr((0.71, 0.24, 0.75, 0.63), 0.02)
    g.poly([(0.45, 0.29), (0.75, 0.23), (0.75, 0.36), (0.45, 0.42)])


def g_appstore(g):
    g.line([(0.50, 0.25), (0.33, 0.73)], g.lw * 0.95)
    g.line([(0.50, 0.25), (0.67, 0.73)], g.lw * 0.95)
    g.line([(0.36, 0.60), (0.64, 0.60)], g.lw * 0.8)


def g_health(g):
    k = 0.0155
    pts = []
    for i in range(64):
        t = i * 2 * math.pi / 64
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((0.5 + k * x, 0.47 - k * y))
    g.poly(pts)


def g_wallet(g):
    g.rr((0.30, 0.25, 0.70, 0.36), 0.03)
    g.rr((0.22, 0.31, 0.78, 0.72), 0.06)
    g.cline([(0.22, 0.45), (0.78, 0.45)], g.lw * 0.7)


def g_calculator(g):
    g.rr((0.29, 0.21, 0.71, 0.79), 0.06)
    g.rr((0.35, 0.27, 0.65, 0.40), 0.02, cut=True)
    for y in (0.51, 0.62, 0.73):
        for x in (0.385, 0.5, 0.615):
            g.circ((x, y), 0.027, cut=True)


def g_contacts(g):
    g.circ((0.5, 0.37), 0.125)
    pts = [(0.5 + 0.23 * math.cos(math.radians(a)), 0.80 + 0.25 * math.sin(math.radians(a)))
           for a in range(180, 361, 6)]
    g.poly(pts)


def g_facetime(g):
    g.rr((0.20, 0.35, 0.60, 0.65), 0.07)
    g.poly([(0.64, 0.50), (0.80, 0.37), (0.80, 0.63)])


def g_videos(g):
    g.rr((0.20, 0.28, 0.80, 0.66), 0.06)
    g.poly([(0.45, 0.38), (0.45, 0.56), (0.60, 0.47)], cut=True)
    g.line([(0.38, 0.76), (0.62, 0.76)], g.lw * 0.8)


def g_podcasts(g):
    g.circ((0.5, 0.45), 0.075)
    g.arc((0.5, 0.45), 0.17, 150, 390, g.lw * 0.7)
    g.arc((0.5, 0.45), 0.27, 150, 390, g.lw * 0.7)
    g.line([(0.5, 0.52), (0.5, 0.76)], g.lw * 0.85)


def g_stocks(g):
    g.line([(0.23, 0.64), (0.40, 0.47), (0.53, 0.58), (0.77, 0.33)], g.lw * 0.9)
    g.line([(0.62, 0.33), (0.77, 0.33), (0.77, 0.48)], g.lw * 0.9)


def g_news(g):
    g.line([(0.34, 0.72), (0.34, 0.28), (0.66, 0.72), (0.66, 0.28)], g.lw * 1.0)


def g_voicememos(g):
    for x, h in zip((0.25, 0.35, 0.45, 0.55, 0.65, 0.75), (0.08, 0.17, 0.27, 0.20, 0.13, 0.07)):
        g.line([(x, 0.5 - h), (x, 0.5 + h)], g.lw * 0.7)


def g_tips(g):
    g.circ((0.5, 0.42), 0.18)
    g.rr((0.42, 0.58, 0.58, 0.70), 0.03)
    g.rr((0.45, 0.70, 0.55, 0.76), 0.03)


def g_home(g):
    g.poly([(0.5, 0.23), (0.80, 0.50), (0.70, 0.50), (0.70, 0.76), (0.30, 0.76), (0.30, 0.50), (0.20, 0.50)])
    g.rr((0.44, 0.58, 0.56, 0.76), 0.02, cut=True)


def g_books(g):
    g.poly([(0.49, 0.34), (0.26, 0.29), (0.26, 0.70), (0.49, 0.75)])
    g.poly([(0.51, 0.34), (0.74, 0.29), (0.74, 0.70), (0.51, 0.75)])


def g_store(g):
    pts = []
    for i in range(10):
        r = 0.29 if i % 2 == 0 else 0.125
        a = math.radians(-90 + i * 36)
        pts.append((0.5 + r * math.cos(a), 0.53 + r * math.sin(a)))
    g.poly(pts)


def g_files(g):
    g.rr((0.21, 0.36, 0.79, 0.73), 0.05)
    g.poly([(0.21, 0.40), (0.21, 0.30), (0.42, 0.30), (0.49, 0.38)])


def g_shortcuts(g):
    g.poly(rot([(0.5, 0.24), (0.68, 0.42), (0.5, 0.60), (0.32, 0.42)], (0.5, 0.42), 0))
    g.poly([(0.5, 0.40), (0.68, 0.58), (0.5, 0.76), (0.32, 0.58)])
    g.poly([(0.5, 0.45), (0.60, 0.55), (0.5, 0.65), (0.40, 0.55)], cut=True)


def g_compass(g):
    g.circ((0.5, 0.5), 0.29)
    g.poly([(0.5, 0.25), (0.585, 0.5), (0.415, 0.5)], cut=True)     # north half of the needle
    g.line([(0.5, 0.5), (0.5, 0.5)], g.lw * 0.5)
    g.poly([(0.5, 0.75), (0.585, 0.5), (0.415, 0.5)])               # south half stays solid
    g.circ((0.5, 0.5), 0.028, cut=True)


def g_measure(g):
    g.poly(rot([(0.22, 0.44), (0.78, 0.44), (0.78, 0.60), (0.22, 0.60)], (0.5, 0.5), -28))
    for k in range(5):
        p = rot([(0.30 + k * 0.1, 0.44), (0.30 + k * 0.1, 0.51 if k % 2 == 0 else 0.485)], (0.5, 0.5), -28)
        g.cline(p, g.lw * 0.3)


def g_cube(g):
    c, r = (0.5, 0.5), 0.29
    k = math.sqrt(3) / 2
    top = (0.5, 0.5 - r); rt = (0.5 + k * r, 0.5 - r / 2); rb = (0.5 + k * r, 0.5 + r / 2)
    bot = (0.5, 0.5 + r); lb = (0.5 - k * r, 0.5 + r / 2); lt = (0.5 - k * r, 0.5 - r / 2)
    g.poly([top, rt, rb, bot, lb, lt])
    g.cline([lt, c, rt], g.lw * 0.45)
    g.cline([c, bot], g.lw * 0.45)


def g_filza(g):
    g.rr((0.21, 0.36, 0.79, 0.73), 0.05)
    g.poly([(0.21, 0.40), (0.21, 0.30), (0.42, 0.30), (0.49, 0.38)])
    g.cline([(0.35, 0.55), (0.65, 0.55)], g.lw * 0.5)


# bundle id -> (glyph fn, accent colour)
APPS = [
    ("com.apple.mobilephone",       g_phone,       "#34C759"),
    ("com.apple.MobileSMS",         g_messages,    "#30D158"),
    ("com.apple.mobilesafari",      g_safari,      "#0A84FF"),
    ("com.apple.mobilemail",        g_mail,        "#2F7DF6"),
    ("com.apple.camera",            g_camera,      "#8E8E93"),
    ("com.apple.mobileslideshow",   g_photos,      "#FF9F0A"),
    ("com.apple.Preferences",       g_settings,    "#8E8E93"),
    ("com.apple.mobiletimer",       g_clock,       "#FF9500"),
    ("com.apple.mobilecal",         g_calendar,    "#FF3B30"),
    ("com.apple.mobilenotes",       g_notes,       "#FFCC00"),
    ("com.apple.reminders",         g_reminders,   "#FF9F0A"),
    ("com.apple.Maps",              g_maps,        "#32D74B"),
    ("com.apple.weather",           g_weather,     "#40C8E0"),
    ("com.apple.Music",             g_music,       "#FF375F"),
    ("com.apple.AppStore",          g_appstore,    "#0A84FF"),
    ("com.apple.Health",            g_health,      "#FF2D55"),
    ("com.apple.Passbook",          g_wallet,      "#30B0C7"),
    ("com.apple.calculator",        g_calculator,  "#FF9500"),
    ("com.apple.MobileAddressBook", g_contacts,    "#A2845E"),
    ("com.apple.facetime",          g_facetime,    "#34C759"),
    ("com.apple.videos",            g_videos,      "#5E5CE6"),
    ("com.apple.podcasts",          g_podcasts,    "#BF5AF2"),
    ("com.apple.stocks",            g_stocks,      "#30D158"),
    ("com.apple.news",              g_news,        "#FF453A"),
    ("com.apple.VoiceMemos",        g_voicememos,  "#FF453A"),
    ("com.apple.tips",              g_tips,        "#FFD60A"),
    ("com.apple.Home",              g_home,        "#FF9F0A"),
    ("com.apple.iBooks",            g_books,       "#FF9500"),
    ("com.apple.MobileStore",       g_store,       "#BF5AF2"),
    ("com.apple.DocumentsApp",      g_files,       "#0A84FF"),
    ("is.workflow.my.app",          g_shortcuts,   "#BF5AF2"),
    ("com.apple.compass",           g_compass,     "#FF453A"),
    ("com.apple.measure",           g_measure,     "#FFD60A"),
    ("org.coolstar.SileoStore",     g_cube,        "#A855F7"),
    ("xyz.willy.Zebra",             g_cube,        "#E5E5EA"),
    ("com.saurik.Cydia",            g_cube,        "#B07A45"),
    ("com.tigisoftware.Filza",      g_filza,       "#FF9F0A"),
]

PREVIEW_ORDER = ["com.apple.mobilephone", "com.apple.MobileSMS", "com.apple.mobilesafari",
                 "com.apple.camera", "com.apple.mobileslideshow", "com.apple.Preferences",
                 "com.apple.mobiletimer", "com.apple.mobilecal", "com.apple.mobilenotes",
                 "com.apple.Maps", "com.apple.Music", "com.apple.AppStore"]

NEON = ["#00E5FF", "#FF2D95", "#B6FF3B", "#FFC400", "#7C4DFF", "#FF5252", "#27F5A5"]


# ------------------------------------------------------------------ styles
def _hue_shift(rgb, deg, sat=1.0, val=1.0):
    h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in rgb))
    h = (h + deg / 360) % 1
    return tuple(int(c * 255) for c in colorsys.hsv_to_rgb(h, min(1, s * sat), min(1, v * val)))


def colorize(mask, rgba):
    layer = Image.new("RGBA", (S, S), rgba[:3] + (0,))
    a = mask if len(rgba) < 4 or rgba[3] == 255 else mask.point(lambda v: int(v * rgba[3] / 255))
    layer.putalpha(a)
    return layer


def style_violet(idx, accent, gm):
    shift = ((idx % 7) - 3) * 5
    c1 = _hue_shift(hexc("#9166FF"), shift)
    c2 = _hue_shift(hexc("#43198F"), shift)
    bg = lin_grad((S, S), c1, c2, 125)
    bg.alpha_composite(radial_glow((S, S), (S * 0.3, S * 0.15), S * 0.8, (255, 255, 255), 0.22))
    bg = grain(bg, 5, seed=idx)
    m = gm.fill_mask()
    g = colorize(m, (255, 255, 255))
    bg.alpha_composite(shadow(g, (0, 16), 16, 0.30, (20, 0, 60)))
    bg.alpha_composite(g)
    return bg


def style_mono(idx, accent, gm):
    bg = lin_grad((S, S), hexc("#202026"), hexc("#09090C"), 120)
    bg = grain(bg, 5, seed=idx)
    m = gm.stroke_mask()
    bg.alpha_composite(colorize(m, (245, 245, 247)))
    d = ImageDraw.Draw(bg)
    r = 30
    d.ellipse((S - 118 - r, 96 - r, S - 118 + r, 96 + r), fill=hexc(accent) + (255,))
    return bg


def style_paper(idx, accent, gm):
    bg = lin_grad((S, S), hexc("#F6F0E3"), hexc("#E6DCC7"), 120)
    bg = grain(bg, 7, seed=idx)
    blob = Image.new("L", (S, S), 0)
    ImageDraw.Draw(blob).ellipse((S * 0.30, S * 0.18, S * 0.86, S * 0.74), fill=255)
    bg.alpha_composite(colorize(blob, hexc(accent) + (235,)))
    m = gm.fill_mask()
    # slightly mis-registered ink layer, like a two-colour print
    m = ImageChops.offset(m, -10, 8)
    bg.alpha_composite(colorize(m, (30, 26, 40, 245)))
    return bg


def style_neon(idx, accent, gm):
    col = hexc(NEON[idx % len(NEON)])
    bg = lin_grad((S, S), hexc("#14102B"), hexc("#07070F"), 120)
    bg = grain(bg, 4, seed=idx)
    m = gm.stroke_mask()
    wide = m.filter(ImageFilter.GaussianBlur(46)).point(lambda v: min(255, int(v * 1.5)))
    mid = m.filter(ImageFilter.GaussianBlur(18)).point(lambda v: min(255, int(v * 1.3)))
    bg.alpha_composite(colorize(wide, col + (190,)))
    bg.alpha_composite(colorize(mid, col + (255,)))
    core = tuple(min(255, int(c * 0.4 + 255 * 0.6)) for c in col)
    bg.alpha_composite(colorize(m, core))
    return bg


def style_frost(idx, accent, gm):
    bg = lin_grad((S, S), hexc("#EAF4FF"), hexc("#C9DCF5"), 125)
    bg.alpha_composite(radial_glow((S, S), (S * 0.28, S * 0.1), S * 0.85, (255, 255, 255), 0.85))
    bg = grain(bg, 4, seed=idx)
    d = ImageDraw.Draw(bg)
    d.rounded_rectangle((26, 26, S - 27, S - 27), 190, outline=(255, 255, 255, 235), width=14)
    base = hexc(accent)
    deep = tuple(int(c * 0.70) for c in base)
    m = gm.fill_mask()
    g = colorize(m, deep + (255,))
    hi = colorize(m.point(lambda v: int(v * 0.45)), tuple(min(255, int(c * 1.25 + 30)) for c in base) + (255,))
    bg.alpha_composite(shadow(g, (0, 20), 20, 0.30, deep))
    bg.alpha_composite(g)
    shifted = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    shifted.alpha_composite(hi, (0, -10))
    # keep the highlight only inside the glyph
    shifted.putalpha(ImageChops.multiply(shifted.split()[3], m))
    bg.alpha_composite(shifted)
    return bg


THEMES = [
    # id, display name, blurb, style fn, glyph stroke width
    ("violet", "Violet", "Deep violet squares with solid white glyphs.", style_violet, 0.060),
    ("mono",   "Mono",   "Near-black with thin white line art and a single colour dot.", style_mono, 0.046),
    ("paper",  "Paper",  "Warm cream stock with ink glyphs on an offset colour print.", style_paper, 0.058),
    ("neon",   "Neon",   "Glowing tube-light outlines on midnight blue.", style_neon, 0.042),
    ("frost",  "Frost",  "Frosted pale glass with tinted, softly lit glyphs.", style_frost, 0.060),
]


def render_icon(theme, idx, size):
    tid, _, _, fn, lw = theme
    bid, glyph, accent = APPS[idx]
    gm = GM(lw)
    glyph(gm)
    img = fn(idx, accent, gm)
    return img.resize((size, size), Image.LANCZOS).convert("RGB")


def preview(theme, cols=4, rows=3, cell=210):
    gap = 26
    pad = 34
    W = pad * 2 + cols * cell + (cols - 1) * gap
    H = pad * 2 + rows * cell + (rows - 1) * gap
    bg = lin_grad((W, H), hexc("#2B2342"), hexc("#17112A"), 115)
    bg = grain(bg, 4)
    idxs = {b: i for i, (b, _, _) in enumerate(APPS)}
    for n, bid in enumerate(PREVIEW_ORDER[: cols * rows]):
        ic = squircle(render_icon(theme, idxs[bid], cell).convert("RGBA"))
        x = pad + (n % cols) * (cell + gap)
        y = pad + (n // cols) * (cell + gap)
        bg.alpha_composite(ic, (x, y))
    return bg.convert("RGB")


if __name__ == "__main__":
    os.makedirs("/home/claude/purple/out/preview", exist_ok=True)
    for t in THEMES:
        preview(t).save(f"/home/claude/purple/out/preview/theme-{t[0]}.png")
    # full glyph check sheet in the violet + mono styles
    for t in (THEMES[0], THEMES[1]):
        n = len(APPS)
        cols = 8
        rows = (n + cols - 1) // cols
        cell = 120
        sh = Image.new("RGBA", (cols * (cell + 10) + 10, rows * (cell + 10) + 10), (24, 18, 38, 255))
        for i in range(n):
            sh.alpha_composite(squircle(render_icon(t, i, cell).convert("RGBA")),
                               (10 + (i % cols) * (cell + 10), 10 + (i // cols) * (cell + 10)))
        sh.save(f"/home/claude/purple/out/preview/all-{t[0]}.png")
    print("ok", len(APPS), "apps")
