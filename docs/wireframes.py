#!/usr/bin/env python3
"""Generate the README wireframes (SVG) from source/Theme.mc.

Colours, fonts' roles and spacing tokens are read from Theme.mc, so the
mock-ups follow the theme. Layout that lives in BmwMWatchView.mc and
BmwMDetail.mc (positions as fractions of the dial radius, logo geometry, hand
lengths) is mirrored below and must be kept in sync by hand.

    python3 docs/wireframes.py [output_dir]      # default: docs/

Writes dial.svg, tap-zones.svg and pages.svg. Convert them to PNG with any
renderer (the committed PNGs were rendered with headless Chromium).
The mock-ups use example values and the time 10:08:35; they are not simulator
screenshots.
"""
import math
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE

# ---------------------------------------------------------------- theme
_theme = (HERE.parent / "source" / "Theme.mc").read_text()
_consts = dict(re.findall(r"const (\w+)\s*=\s*(0x[0-9A-Fa-f]+|[0-9.]+)\s*;", _theme))


def num(name):
    return float(_consts[name]) if "." in _consts[name] else int(_consts[name], 0)


def col(name):
    return "#%06X" % int(_consts[name], 0)


BLUE, NAVY, RED = col("BLUE"), col("NAVY"), col("RED")
BLUE_DIM, NAVY_DIM, RED_DIM = col("BLUE_DIM"), col("NAVY_DIM"), col("RED_DIM")
NAVY_LIGHT = col("NAVY_LIGHT")
WHITE, BLACK = col("WHITE"), col("BLACK")
GREY_LIGHT, GREY_MID, GREY_DARK = col("GREY_LIGHT"), col("GREY_MID"), col("GREY_DARK")
GAP, TICK_INSET = num("GAP"), num("TICK_INSET")
TICK_MAJOR, TICK_MINOR = num("TICK_MAJOR"), num("TICK_MINOR")
MARGIN, ROW_PITCH = num("MARGIN"), num("ROW_PITCH")
BAR_W, BAR_H, BAR_R = num("BAR_W"), num("BAR_H"), num("BAR_R")
Y_STRIPES, Y_TITLE, Y_GLYPH, GLYPH_BIG = num("Y_STRIPES"), num("Y_TITLE"), num("Y_GLYPH"), num("GLYPH_BIG")
Y_TITLE_UNDER_GLYPH, Y_HERO, Y_SUB, Y_BAR = (num("Y_TITLE_UNDER_GLYPH"), num("Y_HERO"),
                                              num("Y_SUB"), num("Y_BAR"))
Y_ROWS, Y_WEATHER_ROWS = num("Y_ROWS"), num("Y_WEATHER_ROWS")
DIM = {BLUE: BLUE_DIM, NAVY: NAVY_DIM, RED: RED_DIM}

# approximate pixel heights of the Garmin system fonts, per Theme font role
FONT_PX = {"label": 18, "value": 22, "title": 24, "hero": 96}

# ---------------------------------------------------------------- screen
W, H = 448, 486
CX, CY = W / 2, H / 2
R = min(W, H) / 2 - 4
FAMILY = "Helvetica,Arial,sans-serif"


def pt(rad, deg, x=CX, y=CY):
    a = math.radians(deg)
    return x + rad * math.cos(a), y - rad * math.sin(a)


def pts(points):
    return " ".join("%.1f,%.1f" % p for p in points)


class Svg:
    def __init__(self):
        self.o = []

    def add(self, s):
        self.o.append(s)

    def text(self, x, y, s, role, fill, anchor="middle"):
        self.add('<text x="%.1f" y="%.1f" font-size="%d" fill="%s" text-anchor="%s" '
                 'dominant-baseline="central" font-family="%s">%s</text>'
                 % (x, y, FONT_PX[role], fill, anchor, FAMILY, s))

    def poly(self, points, fill):
        self.add('<polygon points="%s" fill="%s"/>' % (pts(points), fill))

    def circle(self, x, y, r, fill):
        self.add('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (x, y, r, fill))

    def line(self, p, q, stroke, w):
        self.add('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="%s"/>'
                 % (p[0], p[1], q[0], q[1], stroke, w))

    def arc(self, x, y, rad, a0, a1, stroke, w, cw=False):
        p0, p1 = pt(rad, a0, x, y), pt(rad, a1, x, y)
        large = 1 if abs(a1 - a0) > 180 else 0
        self.add('<path d="M%.1f %.1f A%.1f %.1f 0 %d %d %.1f %.1f" fill="none" stroke="%s" stroke-width="%s"/>'
                 % (p0[0], p0[1], rad, rad, large, 1 if cw else 0, p1[0], p1[1], stroke, w))

    def doc(self, width, height, vb):
        return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="%s" width="%d" height="%d">%s</svg>'
                % (vb, width, height, "".join(self.o)))


def screen(s, ox=0):
    s.add('<g transform="translate(%d,0)"><rect width="%d" height="%d" rx="70" fill="%s" '
          'stroke="%s" stroke-width="3"/>' % (ox, W, H, BLACK, GREY_MID))


# ---------------------------------------------------------------- shared geometry
RING_W = int(R * 0.2 / 99 * 36 * 0.866 + 0.5)          # same rounding as ringWidth()
PITCH = RING_W + GAP
TICK_INNER = (R - TICK_INSET) - R * TICK_MAJOR
RING_OUT = TICK_INNER - GAP - RING_W / 2.0              # ringOuterR()
LOGO_STRIPES = [(66, BLUE), (107, NAVY), (148, RED)]    # top-left x, colour
LOGO_M = [(132, 99), (189, 0), (227.5, 0), (227.5, 40), (252, 0), (290, 0), (290, 99),
          (254.5, 99), (254.5, 58), (229.5, 99), (196.5, 99), (196.5, 58), (171.5, 99)]


def draw_badge(s, cy):
    mh = R * 0.2
    k = mh / 99
    left, top = CX - 281 * k / 2, cy - mh / 2

    def lp(points):
        return [(left + (x - 9) * k, top + y * k) for x, y in points]
    for xt, c in LOGO_STRIPES:
        s.poly(lp([(xt, 0), (xt + 36, 0), (xt + 36 - 57, 99), (xt - 57, 99)]), c)
    s.poly(lp(LOGO_M), WHITE)


def draw_hand(s, deg, length, wid, tail):
    a = math.radians(deg)
    sn, cs = math.sin(a), math.cos(a)

    def poly(ln, hw, tl):
        local = [(-hw, -tl), (-hw * .6, ln), (hw * .6, ln), (hw, -tl)]
        return [(CX + x * cs + y * sn, CY + x * sn - y * cs) for x, y in local]
    s.poly(poly(length, wid / 2, tail), WHITE)
    s.poly(poly(length * .92, wid / 5, -length * .18), BLUE)


def draw_roundel(s):
    rr = R * .11
    ri = rr * .72
    for c, a0, a1 in [(BLUE, 100, 170), (NAVY, 10, 80), (NAVY, 280, 350), (RED, 190, 260)]:
        s.arc(CX, CY, rr + 6, a0, a1, c, 5)
    s.circle(CX, CY, rr, BLACK)
    s.circle(CX, CY, ri, WHITE)
    for a0, a1 in [(90, 180), (270, 360)]:
        p0, p1 = pt(ri, a0), pt(ri, a1)
        s.add('<path d="M%.1f %.1f L%.1f %.1f A%.1f %.1f 0 0 0 %.1f %.1f Z" fill="%s"/>'
              % (CX, CY, p0[0], p0[1], ri, ri, p1[0], p1[1], BLUE))


def dial(zones=False):
    s = Svg()
    s.add('<rect x="-30" y="-30" width="%d" height="%d" fill="#1b1b1b"/>' % (W + 60, H + 60))
    screen(s)
    # ring track + fill: a 60 degree wedge, 240..300, fill runs left to right
    for i, (c, frac) in enumerate([(BLUE, .62), (NAVY, .45), (RED, .78)]):
        rad = RING_OUT - i * PITCH
        s.arc(CX, CY, rad, 240, 300, DIM[c], RING_W)
        s.arc(CX, CY, rad, 240, 240 + 60 * frac, c, RING_W)
    for i in range(60):
        major = i % 5 == 0
        outer = R - TICK_INSET
        inner = outer - (R * TICK_MAJOR if major else R * TICK_MINOR)
        s.line(pt(inner, 90 - i * 6), pt(outer, 90 - i * 6),
               WHITE if major else GREY_LIGHT, 4 if major else 2)
    draw_badge(s, CY - R * .4)
    s.text(CX, CY - R * .58, "WED 25 &#160;&#183;&#160; 18&#176;C &#160;&#183;&#160; 82%", "label", GREY_LIGHT)
    draw_hand(s, (10 + 8 / 60) * 30, R * .56, R * .07, R * .1)
    draw_hand(s, (8 + 35 / 60) * 6, R * .88, R * .05, R * .12)
    a = math.radians(35 * 6)
    s.line((CX - math.sin(a) * R * .18, CY + math.cos(a) * R * .18),
           (CX + math.sin(a) * R * .94, CY - math.cos(a) * R * .94), RED, 3)
    draw_roundel(s)
    if zones:
        s.add('<rect x="%.1f" y="%.1f" width="280" height="48" rx="10" fill="#FFD400" fill-opacity=".25" '
              'stroke="#FFD400" stroke-width="2"/>' % (CX - 140, CY - R * .58 - 24))
        s.add('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" fill-opacity=".22" stroke="%s" '
              'stroke-width="2" stroke-dasharray="6 4"/>' % (CX, CY, R * .36, RED, RED))
        r_hi, r_lo = RING_OUT + 14, RING_OUT - 2 * PITCH - 20
        band = [pt(r_hi, a_) for a_ in range(228, 313, 3)] + [pt(r_lo, a_) for a_ in range(312, 227, -3)]
        s.add('<polygon points="%s" fill="#00C0FF" fill-opacity=".22" stroke="#00C0FF" stroke-width="2"/>'
              % pts(band))
    s.add("</g>")
    return s.doc((W + 60) * 2, (H + 60) * 2, "-30 -30 %d %d" % (W + 60, H + 60))


# ---------------------------------------------------------------- glyphs (page mock-ups)
def g_heart(s, x, y, sz, c):
    s.circle(x - sz * .25, y - sz * .15, sz * .28, c)
    s.circle(x + sz * .25, y - sz * .15, sz * .28, c)
    s.poly([(x - sz * .51, y - sz * .02), (x + sz * .51, y - sz * .02), (x, y + sz * .55)], c)


def glyph_pen(sz):
    return max(2, int(sz * 0.08))


def g_walker(s, x, y, sz, c):
    w = glyph_pen(sz)
    s.circle(x + sz * .06, y - sz * .40, sz * .11, c)
    for x1, y1, x2, y2 in [(.04, -.24, -.02, .08), (.03, -.18, .22, -.02), (.03, -.18, -.15, -.04),
                           (-.02, .08, .14, .26), (.14, .26, .20, .50),
                           (-.02, .08, -.16, .28), (-.16, .28, -.30, .46)]:
        s.line((x + x1 * sz, y + y1 * sz), (x + x2 * sz, y + y2 * sz), c, w)


def g_bolt(s, x, y, sz, c):
    s.poly([(x + sz * .15, y - sz * .6), (x - sz * .35, y + sz * .05), (x - sz * .02, y + sz * .05),
            (x - sz * .15, y + sz * .6), (x + sz * .35, y - sz * .1), (x + sz * .02, y - sz * .1)], c)


def g_body(s, x, y, sz, c, frac):
    rr = sz * .62
    s.add('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="%d"/>' % (x, y, rr, GREY_MID, glyph_pen(sz)))
    s.arc(x, y, rr, 90, 90 - 360 * frac, c, glyph_pen(sz), cw=True)
    s.circle(x, y - sz * .24, sz * .1, GREY_LIGHT)
    for x1, y1, x2, y2 in [(0, -.1, 0, .15), (0, -.02, -.22, -.17), (0, -.02, .22, -.17),
                           (0, .15, -.14, .36), (0, .15, .14, .36)]:
        s.line((x + x1 * sz, y + y1 * sz), (x + x2 * sz, y + y2 * sz), GREY_LIGHT, glyph_pen(sz))


# ---------------------------------------------------------------- detail pages
def stripes(s, ox):
    for i, c in enumerate([BLUE, NAVY, RED]):
        x = ox + CX - 40 + i * 28
        s.poly([(x + 8, Y_STRIPES - 7), (x + 28, Y_STRIPES - 7), (x + 20, Y_STRIPES + 7), (x, Y_STRIPES + 7)], c)


def bar(s, ox, y, frac, c):
    s.add('<rect x="%.1f" y="%.1f" width="%d" height="%d" rx="%d" fill="%s"/>'
          % (ox + CX - BAR_W / 2, y - BAR_H / 2, BAR_W, BAR_H, BAR_R, DIM.get(c, GREY_DARK)))
    s.add('<rect x="%.1f" y="%.1f" width="%.1f" height="%d" rx="%d" fill="%s"/>'
          % (ox + CX - BAR_W / 2, y - BAR_H / 2, BAR_W * frac, BAR_H, BAR_R, c))


def row(s, ox, y, label, value):
    s.text(ox + MARGIN, y, label, "label", GREY_LIGHT, "start")
    s.text(ox + W - MARGIN, y, value, "value", WHITE, "end")


def pages():
    s = Svg()
    total = W * 3 + 80
    s.add('<rect x="-20" y="-20" width="%d" height="%d" fill="#1b1b1b"/>' % (total + 40, H + 40))

    # 1: activity rings page
    ox = 0
    screen(s, ox)
    stripes(s, 0)
    s.text(CX, Y_TITLE, "ACTIVITY RINGS", "title", GREY_LIGHT)
    items = [("Steps", "6214 / 10000", .62, BLUE, "walker"),
             ("Active minutes (week)", "68 / 150 min", .45, NAVY, "bolt"),
             ("Body battery", "78 / 100", .78, RED, "body")]
    for i, (name, val, frac, c, g) in enumerate(items):
        y = 150 + i * 100
        gx = MARGIN + 14
        if g == "walker":
            g_walker(s, gx, y, 24, BLUE)
        elif g == "bolt":
            g_bolt(s, gx, y, 24, NAVY_LIGHT)
        else:
            g_body(s, gx, y, 24, RED, frac)
        s.text(MARGIN + 46, y - 14, name, "label", GREY_LIGHT, "start")
        s.text(MARGIN + 46, y + 10, val, "value", WHITE, "start")
        bar(s, 0, y + 40, frac, c)
    s.add("</g>")

    # 2: a metric page (steps)
    ox = W + 40
    screen(s, ox)
    stripes(s, 0)
    g_walker(s, CX, Y_GLYPH, GLYPH_BIG, BLUE)
    s.text(CX, Y_TITLE_UNDER_GLYPH, "STEPS", "title", GREY_LIGHT)
    s.text(CX, Y_HERO, "6214", "hero", WHITE)
    s.text(CX, Y_SUB, "of 10000 goal", "label", GREY_LIGHT)
    bar(s, 0, Y_BAR, .62, BLUE)
    for i, (l, v) in enumerate([("Distance", "4.7 km"), ("Calories", "312 kcal"), ("Floors", "6 / 10")]):
        row(s, 0, Y_ROWS + i * ROW_PITCH, l, v)
    s.add("</g>")

    # 3: weather page
    ox = (W + 40) * 2
    screen(s, ox)
    stripes(s, 0)
    s.text(CX, Y_TITLE, "WEATHER", "title", GREY_LIGHT)
    s.text(CX, 142, "18", "hero", WHITE)
    s.text(CX + 61, 120, "&#176;C", "title", GREY_LIGHT, "start")
    s.text(CX, 204, "Partly cloudy", "title", WHITE)
    s.text(CX, 234, "Feels like 16&#176;", "label", GREY_LIGHT)
    for i, (l, v) in enumerate([("High / low", "20&#176; / 9&#176;"), ("Rain chance", "30%"),
                                ("Wind", "12 km/h NW"), ("Humidity", "65%")]):
        row(s, 0, Y_WEATHER_ROWS + i * ROW_PITCH, l, v)
    for i, (t, v) in enumerate([("14:00", "19&#176;"), ("15:00", "20&#176;"), ("16:00", "19&#176;"), ("17:00", "17&#176;")]):
        x = W * (.2 + .2 * i)
        s.text(x, 410, t, "label", GREY_LIGHT)
        s.text(x, 438, v, "value", WHITE)
    s.add("</g>")
    return s.doc(total * 1, (H + 40), "-20 -20 %d %d" % (total + 40, H + 40))


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "dial.svg").write_text(dial())
    (OUT / "tap-zones.svg").write_text(dial(zones=True))
    (OUT / "pages.svg").write_text(pages())
    print("wrote", ", ".join(str(OUT / n) for n in ("dial.svg", "tap-zones.svg", "pages.svg")))
