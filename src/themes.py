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

    def text(self, s_, cx, cy, size, cut=False):
        from art import font
        f = font("poppins-b", int(size * S))
        bb = self.ds.textbbox((0, 0), s_, font=f)
        w, h = bb[2] - bb[0], bb[3] - bb[1]
        self.ds.text((cx * S - w / 2 - bb[0], cy * S - h / 2 - bb[1]), s_, font=f, fill=0 if cut else 255)

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



# ---- Google family (functional glyphs, not brand logos) ----
def g_google(g):
    g.circ((0.44, 0.44), 0.21)
    g.circ((0.44, 0.44), 0.12, cut=True)
    g.line([(0.59, 0.59), (0.77, 0.77)], g.lw * 1.1)


def g_chrome(g):
    g.circ((0.5, 0.5), 0.29)
    g.circ((0.5, 0.5), 0.125, cut=True)
    g.circ((0.5, 0.5), 0.075)
    for a in (90, 210, 330):
        t = math.radians(a)
        g.cline([(0.5 + 0.125 * math.cos(t), 0.5 + 0.125 * math.sin(t)),
                 (0.5 + 0.29 * math.cos(t), 0.5 + 0.29 * math.sin(t))], g.lw * 0.5)


def g_youtube(g):
    g.rr((0.17, 0.30, 0.83, 0.70), 0.12)
    g.poly([(0.44, 0.40), (0.44, 0.60), (0.61, 0.50)], cut=True)


def g_ytmusic(g):
    g.circ((0.5, 0.5), 0.30)
    g.circ((0.5, 0.5), 0.20, cut=True)
    g.poly([(0.45, 0.39), (0.45, 0.61), (0.63, 0.50)])


def g_drive(g):
    g.poly([(0.5, 0.23), (0.80, 0.74), (0.20, 0.74)])
    g.cline([(0.5, 0.50), (0.66, 0.74)], g.lw * 0.5)
    g.cline([(0.5, 0.50), (0.34, 0.74)], g.lw * 0.5)


def g_doc(g):
    g.rr((0.28, 0.20, 0.72, 0.80), 0.05)
    g.poly([(0.58, 0.20), (0.72, 0.34), (0.58, 0.34)], cut=True)
    for y in (0.50, 0.60, 0.70):
        g.cline([(0.36, y), (0.64, y)], g.lw * 0.5)


def g_sheet(g):
    g.rr((0.26, 0.22, 0.74, 0.78), 0.05)
    g.cline([(0.5, 0.34), (0.5, 0.74)], g.lw * 0.45)
    for y in (0.46, 0.58, 0.70):
        g.cline([(0.32, y), (0.68, y)], g.lw * 0.45)


def g_slides(g):
    g.rr((0.18, 0.28, 0.82, 0.72), 0.05)
    g.rr((0.27, 0.37, 0.73, 0.63), 0.02, cut=True)


def g_translate(g):
    g.rr((0.18, 0.22, 0.58, 0.62), 0.07)
    g.rr((0.42, 0.40, 0.82, 0.80), 0.07)
    g.text("A", 0.38, 0.43, 0.25, cut=True)
    g.text("a", 0.62, 0.62, 0.22, cut=True)


def g_classroom(g):
    g.rr((0.19, 0.25, 0.81, 0.69), 0.05)
    g.rr((0.26, 0.32, 0.74, 0.62), 0.02, cut=True)
    g.circ((0.5, 0.44), 0.055)
    g.line([(0.38, 0.79), (0.62, 0.79)], g.lw * 0.8)


def g_assistant(g):
    for x, r in ((0.25, 0.055), (0.40, 0.07), (0.57, 0.07), (0.74, 0.055)):
        g.dot((x, 0.5), r)


def g_remote(g):
    g.rr((0.34, 0.19, 0.66, 0.81), 0.09)
    g.circ((0.5, 0.38), 0.095, cut=True)
    g.circ((0.5, 0.38), 0.03)
    g.circ((0.5, 0.62), 0.03, cut=True)


def g_globe(g):
    g.circ((0.5, 0.5), 0.29)
    g.cline([(0.21, 0.5), (0.79, 0.5)], g.lw * 0.4)
    g.cline([(0.5 + 0.13 * math.cos(2 * math.pi * k / 40), 0.5 + 0.29 * math.sin(2 * math.pi * k / 40))
             for k in range(41)], g.lw * 0.4)


def g_shieldcheck(g):
    g.poly([(0.5, 0.21), (0.75, 0.30), (0.75, 0.52), (0.5, 0.79), (0.25, 0.52), (0.25, 0.30)])
    g.cline([(0.39, 0.50), (0.47, 0.59), (0.62, 0.41)], g.lw * 0.75)


# ---- Strava / fitness ----
def g_route(g):
    pts = [(0.5 + 0.19 * math.sin(2 * math.pi * k / 24), 0.74 - 0.48 * k / 24) for k in range(25)]
    g.line(pts, g.lw * 0.85)
    g.circ((0.5, 0.76), 0.07)
    g.circ((0.5, 0.76), 0.032, cut=True)
    g.circ((0.5, 0.26), 0.07)


def g_fitness(g):
    g.line([(0.19, 0.52), (0.37, 0.52), (0.46, 0.33), (0.56, 0.69), (0.64, 0.52), (0.81, 0.52)], g.lw * 0.8)


# ---- games ----
def g_gamepad(g):
    g.rr((0.15, 0.35, 0.85, 0.69), 0.16)
    g.cline([(0.29, 0.52), (0.43, 0.52)], g.lw * 0.45)
    g.cline([(0.36, 0.45), (0.36, 0.59)], g.lw * 0.45)
    g.circ((0.63, 0.49), 0.035, cut=True)
    g.circ((0.72, 0.56), 0.035, cut=True)


def g_twoplayer(g):
    for cx in (0.34, 0.66):
        g.circ((cx, 0.38), 0.095)
        pts = [(cx + 0.17 * math.cos(math.radians(a)), 0.78 + 0.19 * math.sin(math.radians(a)))
               for a in range(180, 361, 8)]
        g.poly(pts)


def g_geometrydash(g):
    g.rr((0.22, 0.32, 0.58, 0.68), 0.04)
    g.rr((0.30, 0.41, 0.37, 0.50), 0.01, cut=True)
    g.rr((0.43, 0.41, 0.50, 0.50), 0.01, cut=True)
    g.rr((0.30, 0.56, 0.50, 0.61), 0.01, cut=True)
    g.poly([(0.63, 0.68), (0.72, 0.46), (0.81, 0.68)])
    g.line([(0.16, 0.76), (0.84, 0.76)], g.lw * 0.5)


def g_roblox(g):
    sq = [(0.28, 0.28), (0.72, 0.28), (0.72, 0.72), (0.28, 0.72)]
    g.poly(rot(sq, (0.5, 0.5), 18))
    g.poly(rot([(0.43, 0.43), (0.57, 0.43), (0.57, 0.57), (0.43, 0.57)], (0.5, 0.5), 18), cut=True)


def g_runner(g):
    for x in (0.27, 0.43, 0.59):
        g.line([(x, 0.31), (x + 0.15, 0.5), (x, 0.69)], g.lw * 0.9)


def g_shield(g):
    g.poly([(0.5, 0.21), (0.77, 0.30), (0.73, 0.58), (0.5, 0.79), (0.27, 0.58), (0.23, 0.30)])
    g.cline([(0.5, 0.34), (0.5, 0.64)], g.lw * 0.55)


def g_crown(g):
    g.poly([(0.21, 0.66), (0.21, 0.34), (0.38, 0.49), (0.5, 0.28), (0.62, 0.49), (0.79, 0.34), (0.79, 0.66)])
    g.rr((0.21, 0.70, 0.79, 0.78), 0.02)


def g_gem(g):
    g.poly([(0.30, 0.34), (0.70, 0.34), (0.84, 0.50), (0.5, 0.80), (0.16, 0.50)])
    g.cline([(0.16, 0.50), (0.84, 0.50)], g.lw * 0.4)
    g.cline([(0.38, 0.34), (0.5, 0.80), (0.62, 0.34)], g.lw * 0.4)


def g_pokeball(g):
    g.circ((0.5, 0.5), 0.29)
    g.cline([(0.21, 0.5), (0.79, 0.5)], g.lw * 0.8)
    g.circ((0.5, 0.5), 0.10, cut=True)
    g.circ((0.5, 0.5), 0.05)


def g_eightball(g):
    g.circ((0.5, 0.5), 0.29)
    g.circ((0.5, 0.47), 0.13, cut=True)
    g.text("8", 0.5, 0.47, 0.17)


def g_crosshair(g):
    g.circ((0.5, 0.5), 0.27)
    g.circ((0.5, 0.5), 0.19, cut=True)
    for a in (0, 90, 180, 270):
        t = math.radians(a)
        g.line([(0.5 + 0.12 * math.cos(t), 0.5 + 0.12 * math.sin(t)),
                (0.5 + 0.34 * math.cos(t), 0.5 + 0.34 * math.sin(t))], g.lw * 0.6)
    g.dot((0.5, 0.5), 0.035)


def g_letter_g(g):
    g.text("G", 0.5, 0.5, 0.52)



# ---- jailbreak / sideloading apps ----
def g_terminal(g):
    g.rr((0.17, 0.24, 0.83, 0.76), 0.07)
    g.cline([(0.30, 0.40), (0.41, 0.50), (0.30, 0.60)], g.lw * 0.65)
    g.cline([(0.47, 0.62), (0.64, 0.62)], g.lw * 0.65)


def g_cleaner(g):
    g.line([(0.70, 0.22), (0.47, 0.50)], g.lw * 0.7)                       # handle
    head = rot([(0.28, 0.50), (0.56, 0.44), (0.70, 0.62), (0.44, 0.80), (0.26, 0.74)], (0.48, 0.62), -8)
    g.poly(head)
    g.cline([(0.38, 0.62), (0.44, 0.74)], g.lw * 0.4)
    g.cline([(0.50, 0.58), (0.55, 0.70)], g.lw * 0.4)
    star = []
    for i in range(8):
        r = 0.085 if i % 2 == 0 else 0.028
        a = math.radians(-90 + i * 45)
        star.append((0.28 + r * math.cos(a), 0.30 + r * math.sin(a)))
    g.poly(star)


def g_crystal(g):
    g.poly([(0.5, 0.19), (0.69, 0.34), (0.69, 0.62), (0.5, 0.81), (0.31, 0.62), (0.31, 0.34)])
    g.cline([(0.31, 0.34), (0.5, 0.47), (0.69, 0.34)], g.lw * 0.4)
    g.cline([(0.5, 0.47), (0.5, 0.81)], g.lw * 0.4)


def g_delta(g):
    g.poly([(0.5, 0.21), (0.82, 0.77), (0.18, 0.77)])
    g.poly([(0.5, 0.42), (0.65, 0.68), (0.35, 0.68)], cut=True)


def g_reprovision(g):
    c, r = (0.5, 0.5), 0.24
    for a0, a1 in ((200, 330), (20, 150)):
        g.arc(c, r, a0, a1, g.lw * 0.8)
        t = math.radians(a1)
        pos = (c[0] + r * math.cos(t), c[1] + r * math.sin(t))
        tan = (-math.sin(t), math.cos(t))
        nor = (math.cos(t), math.sin(t))
        tip = (pos[0] + tan[0] * 0.085, pos[1] + tan[1] * 0.085)
        b1 = (pos[0] + nor[0] * 0.075, pos[1] + nor[1] * 0.075)
        b2 = (pos[0] - nor[0] * 0.075, pos[1] - nor[1] * 0.075)
        g.poly([tip, b1, b2])


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
    # ---- Google apps (bundle IDs confirmed from public lists) ----
    ("com.google.GoogleMobile",          g_google,      "#4285F4"),
    ("com.google.chrome.ios",            g_chrome,      "#EA4335"),
    ("com.google.Gmail",                 g_mail,        "#EA4335"),
    ("com.google.Maps",                  g_maps,        "#34A853"),
    ("com.google.ios.youtube",           g_youtube,     "#FF3B30"),
    ("com.google.ios.youtubemusic",      g_ytmusic,     "#FF3B30"),
    ("com.google.Drive",                 g_drive,       "#FBBC04"),
    ("com.google.photos",                g_photos,      "#FBBC04"),
    ("com.google.Docs",                  g_doc,         "#4285F4"),
    ("com.google.Sheets",                g_sheet,       "#34A853"),
    ("com.google.Slides",                g_slides,      "#FBBC04"),
    ("com.google.calendar",              g_calendar,    "#4285F4"),
    ("com.google.Keep",                  g_tips,        "#FBBC04"),
    ("com.google.meetings",              g_facetime,    "#34A853"),
    ("com.google.Translate",             g_translate,   "#4285F4"),
    ("com.google.Classroom",             g_classroom,   "#34A853"),
    ("com.google.OPA",                   g_assistant,   "#4285F4"),
    ("com.google.Chromecast",            g_home,        "#EA4335"),
    ("com.google.AndroidTVRemote",       g_remote,      "#34A853"),
    ("com.google.fit",                   g_health,      "#34A853"),
    ("com.google.news",                  g_news,        "#4285F4"),
    ("com.google.GoogleDigitalEditions", g_news,        "#4285F4"),
    ("com.google.b612",                  g_globe,       "#34A853"),
    ("com.google.Authenticator",         g_shieldcheck, "#4285F4"),

    # ---- jailbreak / sideloading apps ----
    # Delta's ID is from its own README. The others also get icons by name through Purple Link, which is what
    # catches sideloaded copies whose bundle ID has a suffix added.
    ("com.rileytestut.Delta",            g_delta,       "#5E5CE6"),
    ("com.exile90.icleanerpro",          g_cleaner,     "#FF9F0A"),
]

# name -> (glyph, accent). These become _generic/<name>.png; the purplelink helper points apps at them by
# category / name, so any game, Google app or fitness app gets a matching icon even if its bundle ID is
# not listed above.
GENERIC = [
    ("game",         g_gamepad,      "#FF5E7E"),
    ("twoplayer",    g_twoplayer,    "#5AC8FA"),
    ("google",       g_letter_g,     "#4285F4"),
    ("fitness",      g_fitness,      "#FC4C02"),
    ("strava",       g_route,        "#FC4C02"),
    ("geometrydash", g_geometrydash, "#FFD60A"),
    ("roblox",       g_roblox,       "#FF453A"),
    ("minecraft",    g_cube,         "#32D74B"),
    ("runner",       g_runner,       "#FF9F0A"),
    ("shield",       g_shield,       "#0A84FF"),
    ("crown",        g_crown,        "#BF5AF2"),
    ("gem",          g_gem,          "#FF2D55"),
    ("pokeball",     g_pokeball,     "#FF453A"),
    ("eightball",    g_eightball,    "#8E8E93"),
    ("crosshair",    g_crosshair,    "#FF9500"),
    ("terminal",     g_terminal,     "#30D158"),
    ("icleaner",     g_cleaner,      "#FF9F0A"),
    ("amethyst",     g_crystal,      "#B26BFF"),
    ("delta",        g_delta,        "#5E5CE6"),
    ("reprovision",  g_reprovision,  "#0A84FF"),
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



def _vignette(img, strength=0.55):
    ys, xs = np.mgrid[0:S, 0:S].astype(np.float32)
    d = np.sqrt(((xs - S / 2) / (S / 2)) ** 2 + ((ys - S / 2) / (S / 2)) ** 2)
    a = np.clip((d - 0.55) / 0.9, 0, 1) ** 1.6 * strength
    layer = np.zeros((S, S, 4), np.uint8)
    layer[..., 3] = (a * 255).astype(np.uint8)
    img.alpha_composite(Image.fromarray(layer, "RGBA"))


def style_sunset(idx, accent, gm):
    shift = ((idx % 5) - 2) * 4
    c1 = _hue_shift(hexc("#FF9F43"), shift)
    c2 = _hue_shift(hexc("#6B2BB5"), shift)
    bg = lin_grad((S, S), c1, c2, 100)
    bg.alpha_composite(radial_glow((S, S), (S * 0.5, S * 0.9), S * 0.85, (255, 64, 120), 0.6))
    sun = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sun)
    sd.ellipse((S * 0.5 - 330, S * 0.9 - 330, S * 0.5 + 330, S * 0.9 + 330), fill=(255, 226, 160, 120))
    for k, y in enumerate(range(int(S * 0.80), S, 34)):          # retro bands across the lower sun
        sd.rectangle((0, y, S, y + 8 + k * 2), fill=(0, 0, 0, 0))
    bg.alpha_composite(sun.filter(ImageFilter.GaussianBlur(5)))
    bg = grain(bg, 5, seed=idx)
    m = gm.fill_mask()
    g = colorize(m, (255, 255, 255))
    bg.alpha_composite(shadow(g, (0, 18), 18, 0.32, (60, 0, 70)))
    bg.alpha_composite(g)
    return bg


def style_phosphor(idx, accent, gm):
    bg = lin_grad((S, S), hexc("#06210F"), hexc("#010603"), 100)
    bg = grain(bg, 4, seed=idx)
    m = gm.stroke_mask()
    green = (66, 255, 128)
    bg.alpha_composite(colorize(m.filter(ImageFilter.GaussianBlur(44)).point(lambda v: min(255, int(v * 1.5))), green + (170,)))
    bg.alpha_composite(colorize(m.filter(ImageFilter.GaussianBlur(14)).point(lambda v: min(255, int(v * 1.3))), green + (255,)))
    bg.alpha_composite(colorize(ImageChops.offset(m, -7, 0), (255, 70, 70, 70)))      # slight colour fringing
    bg.alpha_composite(colorize(ImageChops.offset(m, 7, 0), (70, 130, 255, 70)))
    bg.alpha_composite(colorize(m, (190, 255, 210)))
    sc = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sc)
    for y in range(0, S, 10):                                                           # CRT scanlines
        sd.line([(0, y), (S, y)], fill=(0, 0, 0, 58), width=4)
    bg.alpha_composite(sc)
    _vignette(bg, 0.7)
    return bg


def style_blueprint(idx, accent, gm):
    bg = lin_grad((S, S), hexc("#3170C8"), hexc("#103262"), 120)
    bg = grain(bg, 4, seed=idx)
    gl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gl)
    for x in range(0, S, 64):
        gd.line([(x, 0), (x, S)], fill=(255, 255, 255, 58 if x % 256 == 0 else 24), width=4 if x % 256 == 0 else 2)
        gd.line([(0, x), (S, x)], fill=(255, 255, 255, 58 if x % 256 == 0 else 24), width=4 if x % 256 == 0 else 2)
    for (x, y) in ((70, 70), (S - 70, 70), (70, S - 70), (S - 70, S - 70)):            # registration crosses
        gd.line([(x - 26, y), (x + 26, y)], fill=(255, 255, 255, 120), width=5)
        gd.line([(x, y - 26), (x, y + 26)], fill=(255, 255, 255, 120), width=5)
    bg.alpha_composite(gl)
    fillm = gm.fill_mask().point(lambda v: int(v * 0.16))
    bg.alpha_composite(colorize(fillm, (255, 255, 255)))
    m = gm.stroke_mask()
    bg.alpha_composite(shadow(colorize(m, (255, 255, 255)), (0, 8), 6, 0.30, (0, 20, 70)))
    bg.alpha_composite(colorize(m, (245, 250, 255)))
    d = ImageDraw.Draw(bg)                                                               # dimension line along the bottom
    d.line([(150, S - 120), (S - 150, S - 120)], fill=(255, 255, 255, 150), width=4)
    for x in (150, S - 150):
        d.line([(x, S - 138), (x, S - 102)], fill=(255, 255, 255, 150), width=4)
    return bg


def style_pixel(idx, accent, gm):
    N = 28
    base = hexc(accent)
    light = tuple(min(255, int(v * 1.25 + 50)) for v in base)
    bg = lin_grad((S, S), hexc("#2C1F62"), hexc("#110B2B"), 115)
    bg = grain(bg, 3, seed=idx)
    gl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gl)
    cell = S / N
    for i in range(N + 1):
        gd.line([(i * cell, 0), (i * cell, S)], fill=(255, 255, 255, 12), width=2)
        gd.line([(0, i * cell), (S, i * cell)], fill=(255, 255, 255, 12), width=2)
    rng = np.random.default_rng(idx + 5)
    for _ in range(9):                                                                   # a few lit pixels
        x, y = int(rng.integers(0, N)), int(rng.integers(0, N))
        gd.rectangle((x * cell, y * cell, (x + 1) * cell, (y + 1) * cell), fill=base + (int(rng.integers(30, 80)),))
    bg.alpha_composite(gl)
    small = gm.fill_mask().resize((N, N), Image.LANCZOS).point(lambda v: 255 if v > 105 else 0)
    pix = small.resize((S, S), Image.NEAREST)
    step = int(cell)
    bg.alpha_composite(colorize(ImageChops.offset(pix, step, step), (0, 0, 0, 150)))      # hard drop shadow
    bg.alpha_composite(colorize(pix, base))
    hi = ImageChops.subtract(pix, ImageChops.offset(pix, 0, step))                        # lit top row of each shape
    bg.alpha_composite(colorize(hi, light))
    lo = ImageChops.subtract(pix, ImageChops.offset(pix, 0, -step))                       # shaded bottom row
    bg.alpha_composite(colorize(lo, tuple(int(v * 0.6) for v in base)))
    return bg


def _warp(mask, amp, seed, scale=96):
    rng = np.random.default_rng(seed)
    n = S // scale + 3
    chans = []
    for c in range(2):
        arr = rng.normal(0, 1, (n, n))
        img = Image.fromarray(np.clip((arr + 3) * 42, 0, 255).astype(np.uint8), "L").resize((S, S), Image.BICUBIC)
        chans.append((np.array(img, np.float32) / 42 - 3) * amp)
    ys, xs = np.mgrid[0:S, 0:S]
    xx = np.clip(xs + chans[0], 0, S - 1).astype(int)
    yy = np.clip(ys + chans[1], 0, S - 1).astype(int)
    return Image.fromarray(np.array(mask)[yy, xx], "L")


def style_doodle(idx, accent, gm):
    base = hexc(accent)
    flat = tuple(int(v * 0.88) for v in base)
    bg = Image.new("RGBA", (S, S), flat + (255,))
    bg.alpha_composite(radial_glow((S, S), (S * 0.3, S * 0.2), S * 0.9, (255, 255, 255), 0.22))
    bg = grain(bg, 7, seed=idx)
    d = ImageDraw.Draw(bg)
    d.rounded_rectangle((64, 64, S - 65, S - 65), 150, outline=(12, 8, 18, 235), width=18)   # marker border
    m = _warp(gm.fill_mask(), 11, idx + 3)
    dil = m.filter(ImageFilter.GaussianBlur(15)).point(lambda v: 255 if v > 24 else 0)
    outline = ImageChops.subtract(dil, m)
    bg.alpha_composite(colorize(outline, (12, 8, 18)))
    bg.alpha_composite(colorize(m, (255, 255, 255)))
    # the little signature: two eyes, as in the original drawing
    for cx in (S - 232, S - 128):
        d.ellipse((cx - 30, S - 190 - 30, cx + 30, S - 190 + 30), fill=(12, 8, 18, 255))
        d.ellipse((cx - 17, S - 190 - 15, cx - 6, S - 190 - 4), fill=(255, 255, 255, 255))
    return bg


THEMES = [
    # id, display name, blurb, style fn, glyph stroke width
    ("violet", "Violet", "Deep violet squares with solid white glyphs.", style_violet, 0.060),
    ("mono",   "Mono",   "Near-black with thin white line art and a single colour dot.", style_mono, 0.046),
    ("paper",  "Paper",  "Warm cream stock with ink glyphs on an offset colour print.", style_paper, 0.058),
    ("neon",   "Neon",   "Glowing tube-light outlines on midnight blue.", style_neon, 0.042),
    ("frost",  "Frost",  "Frosted pale glass with tinted, softly lit glyphs.", style_frost, 0.060),
    ("sunset", "Sunset", "Warm orange-to-purple dusk with a low sun and white glyphs.", style_sunset, 0.060),
    ("phosphor", "Phosphor", "Green terminal glow with scanlines on black.", style_phosphor, 0.044),
    ("blueprint", "Blueprint", "White line drawings on blue graph paper.", style_blueprint, 0.040),
    ("pixel",  "Pixel",  "Chunky 8-bit glyphs on a dark pixel grid.", style_pixel, 0.060),
    ("doodle", "Doodle", "Flat colour, wobbly marker outlines and a little pair of eyes.", style_doodle, 0.060),
]

THEME_PALETTE = {
    "violet": ("#8B5CF6", "#3B1480"), "mono": ("#3A3A42", "#0A0A0E"), "paper": ("#F2EADA", "#D2C3A2"),
    "neon": ("#2E1C70", "#07050F"), "frost": ("#E0EDFC", "#98B9E4"), "sunset": ("#FF8F3F", "#6B2BB5"),
    "phosphor": ("#0E4220", "#010603"), "blueprint": ("#3C7AD3", "#0F2E60"), "pixel": ("#4B3694", "#130D33"),
    "doodle": ("#862CED", "#2A0E52"),
}


def theme_icon(theme_row, size=256):
    """Package icon for a theme: a glossy tray with four icons from that theme."""
    import art
    tid = theme_row[0]
    c1, c2 = THEME_PALETTE[tid]
    bg = art.rich_background(c1, c2, sum(ord(ch) for ch in tid) * 5)
    ids = [b for b, _, _ in APPS]
    cell, gap = 372, 44
    x0 = (S - 2 * cell - gap) // 2
    for n, bid in enumerate(("com.apple.mobilephone", "com.apple.mobilesafari", "com.apple.Music", "com.apple.Preferences")):
        ic = squircle(render_icon(theme_row, ids.index(bid), cell).convert("RGBA"))
        x = x0 + (n % 2) * (cell + gap)
        y = x0 + (n // 2) * (cell + gap)
        tile = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        tile.alpha_composite(ic, (x, y))
        bg.alpha_composite(shadow(tile, (0, 16), 16, 0.42, (0, 0, 20)))
        bg.alpha_composite(tile)
    sheen = Image.new("L", (S, S), 0)
    ImageDraw.Draw(sheen).ellipse((-S * 0.35, -S * 0.95, S * 1.35, S * 0.50), fill=40)
    sh = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    sh.putalpha(sheen.filter(ImageFilter.GaussianBlur(6)))
    bg.alpha_composite(sh)
    edge = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle((10, 10, S - 11, S - 11), 210, outline=(255, 255, 255, 44), width=8)
    bg.alpha_composite(edge)
    return bg.resize((size, size), Image.LANCZOS).convert("RGB")


def render_glyph(theme, seed, glyph, accent, size):
    _, _, _, fn, lw = theme
    gm = GM(lw)
    glyph(gm)
    img = fn(seed, accent, gm)
    return img.resize((size, size), Image.LANCZOS).convert("RGB")


def render_icon(theme, idx, size):
    bid, glyph, accent = APPS[idx]
    return render_glyph(theme, idx, glyph, accent, size)


def render_generic(theme, i, size):
    name, glyph, accent = GENERIC[i]
    return render_glyph(theme, 200 + i, glyph, accent, size)


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
