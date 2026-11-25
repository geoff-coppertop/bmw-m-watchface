#!/usr/bin/env python3
"""Generate the README wireframes from source/Theme.mc.

    python3 tools/wireframes.py              # render PNGs into docs/
    python3 tools/wireframes.py --svg-only   # write SVGs instead (no renderer needed)
    python3 tools/wireframes.py --out DIR    # write somewhere else

Colours, spacing and font-size roles are read from Theme.mc, so the mock-ups follow
the theme. Layout that lives in BmwMWatchView.mc and BmwMDetail.mc (positions as
fractions of the dial radius, logo geometry, hand lengths) is mirrored in this
script and must be kept in sync by hand.

PNG output needs one SVG renderer, tried in this order: rsvg-convert,
inkscape, the cairosvg Python package, Google Chrome / Chromium. Install any one
(for example `sudo apt install librsvg2-bin` or `pip install cairosvg`). Set
CHROME_PATH to point at a specific Chrome binary.

The mock-ups use example values and the time 10:08:35. They are not simulator
screenshots.
"""
import argparse
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent

# ---------------------------------------------------------------- theme
_theme = (ROOT / "source" / "Theme.mc").read_text()
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
CHART_X, CHART_TOP, CHART_BOTTOM = num("CHART_X"), num("CHART_TOP"), num("CHART_BOTTOM")
Y_XLABELS, Y_STATS, Y_DOTS, DOT_R = num("Y_XLABELS"), num("Y_STATS"), num("Y_DOTS"), num("DOT_R")
Y_CAPTION = num("Y_CAPTION")
ACTIVITY_ROW_TOP, ACTIVITY_ROW_PITCH = num("ACTIVITY_ROW_TOP"), num("ACTIVITY_ROW_PITCH")
BAR_COLS_W, BAR_COLS_GAP = num("BAR_COLS_W"), num("BAR_COLS_GAP")
DIM = {BLUE: BLUE_DIM, NAVY: NAVY_DIM, RED: RED_DIM}
# Theme.metricColor(): one colour per metric everywhere
METRIC = {"steps": BLUE, "active": NAVY, "body": RED, "hr": RED, "weather": RED}

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


def screen(s, ox=0, oy=0):
    s.add('<g transform="translate(%d,%d)"><rect width="%d" height="%d" rx="70" fill="%s" '
          'stroke="%s" stroke-width="3"/>' % (ox, oy, W, H, BLACK, GREY_MID))


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
    for i, (c, frac) in enumerate([(METRIC["steps"], .62), (METRIC["active"], .45), (METRIC["body"], .78)]):
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


def chevron(s, x, y, right):
    d = -6 if right else 6
    s.add('<polyline points="%.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="none" stroke="%s" stroke-width="3"/>'
          % (x + d, y - 12, x - d, y, x + d, y + 12, GREY_MID))


def nav(s, sub, from_activity):
    """Edge chevrons and page dots, as drawNav() in BmwMDetail.mc."""
    if sub == 0:
        chevron(s, W - 24, H / 2, True)
    if sub == 1 or from_activity:
        chevron(s, 24, H / 2, False)
    for i in range(2):
        s.circle(CX - 10 + i * 20, Y_DOTS, DOT_R, WHITE if i == sub else GREY_MID)


def pages():
    s = Svg()
    total = W * 3 + 80
    s.add('<rect x="-20" y="-20" width="%d" height="%d" fill="#1b1b1b"/>' % (total + 40, H + 40))

    # 1: Activity page (tap the ring zone). Each row opens that metric.
    screen(s, 0)
    stripes(s, 0)
    s.text(CX, Y_TITLE, "ACTIVITY", "title", GREY_LIGHT)
    items = [("Steps", "6214 / 10000", .62, BLUE, "walker"),
             ("Active minutes (week)", "68 / 150 min", .45, NAVY, "bolt"),
             ("Body battery", "78 / 100", .78, RED, "body")]
    for i, (name, val, frac, c, g) in enumerate(items):
        y = ACTIVITY_ROW_TOP + 50 + i * ACTIVITY_ROW_PITCH
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
        chevron(s, W - 36, y + 8, True)
    s.add("</g>")

    # 2: a metric page (steps), opened from Activity, so it has a back chevron
    screen(s, W + 40)
    stripes(s, 0)
    g_walker(s, CX, Y_GLYPH, GLYPH_BIG, BLUE)
    s.text(CX, Y_TITLE_UNDER_GLYPH, "STEPS", "title", GREY_LIGHT)
    s.text(CX, Y_HERO, "6214", "hero", WHITE)
    s.text(CX, Y_SUB, "of 10000 goal", "label", GREY_LIGHT)
    bar(s, 0, Y_BAR, .62, BLUE)
    for i, (l, v) in enumerate([("Distance", "4.7 km"), ("Calories", "312 kcal"), ("Floors", "6 / 10")]):
        row(s, 0, Y_ROWS + i * ROW_PITCH, l, v)
    nav(s, 0, True)
    s.add("</g>")

    # 3: weather page, opened from the dial
    screen(s, (W + 40) * 2)
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
    nav(s, 0, False)
    s.add("</g>")
    return s.doc(total * 1, (H + 40), "-20 -20 %d %d" % (total + 40, H + 40))


# ---------------------------------------------------------------- graph pages
def bar_chart(s, vals, goal, color, labels):
    """Each day is a vertical gauge: dim track up to the goal, bright fill to the value."""
    n = len(vals)
    total = n * BAR_COLS_W + (n - 1) * BAR_COLS_GAP
    x0 = W / 2 - total / 2
    maxv = max([goal or 0] + [v for v in vals if v is not None]) or 1
    for i, v in enumerate(vals):
        x = x0 + i * (BAR_COLS_W + BAR_COLS_GAP)
        if goal:
            th = goal * (CHART_BOTTOM - CHART_TOP) / maxv
            s.add('<rect x="%.1f" y="%.1f" width="%d" height="%.1f" fill="%s"/>'
                  % (x, CHART_BOTTOM - th, BAR_COLS_W, th, DIM.get(color, GREY_DARK)))
        if v is not None:
            hgt = v * (CHART_BOTTOM - CHART_TOP) / maxv
            s.add('<rect x="%.1f" y="%.1f" width="%d" height="%.1f" fill="%s"/>'
                  % (x, CHART_BOTTOM - hgt, BAR_COLS_W, hgt, color))
        s.text(x + BAR_COLS_W / 2, Y_XLABELS, labels[i], "label", WHITE if i == n - 1 else GREY_LIGHT)
    s.line((x0, CHART_BOTTOM), (x0 + total, CHART_BOTTOM), GREY_DARK, 2)


def find_sleep(hr, bb):
    """Python mirror of the inference in findSleep() (BmwMDetail.mc). Keep in sync."""
    n = len(hr)
    vals = sorted(int(v) for v in hr if v is not None)
    if len(vals) < 24:
        return None
    lo, med = vals[len(vals) // 10], vals[len(vals) // 2]
    if med - lo < 8:                  # no real night/day difference (SleepInference.MIN_CONTRAST)
        return None
    thr = lo + (med - lo) * 0.4
    best_s = best_e = -1
    run_s = last_low = -1
    gap = 0
    for i in range(n + 1):
        low = i < n and hr[i] is not None and hr[i] <= thr
        if low:
            if run_s < 0:
                run_s = i
            last_low = i
            gap = 0
        elif run_s >= 0:
            gap += 1
            if gap > 1 or i == n:
                if best_s < 0 or last_low - run_s > best_e - best_s:
                    best_s, best_e = run_s, last_low
                run_s = -1
                gap = 0
    if best_s < 0 or best_e - best_s + 1 < 8:
        return None
    first = next((bb[i] for i in range(best_s, min(best_e, best_s + 3) + 1) if bb[i] is not None), None)
    last = next((bb[i] for i in range(best_e, max(best_s, best_e - 3) - 1, -1) if bb[i] is not None), None)
    if first is not None and last is not None and last - first < 8:
        return None
    return best_s, best_e + 1


def moon(s, x, y):
    s.circle(x, y, 7, NAVY_LIGHT)
    s.circle(x + 4, y - 2, 6, BLACK)


def sun(s, x, y):
    s.circle(x, y, 4, WHITE)
    for i in range(8):
        a = i * math.pi / 4
        s.line((x + math.cos(a) * 6, y + math.sin(a) * 6), (x + math.cos(a) * 9, y + math.sin(a) * 9), WHITE, 2)


def line_chart(s, vals, color, xlabels, sleep=None):
    x0, x1 = CHART_X, W - CHART_X
    s.line((x0, CHART_BOTTOM), (x1, CHART_BOTTOM), GREY_DARK, 2)
    s.line((x0, CHART_TOP), (x1, CHART_TOP), GREY_DARK, 2)
    good = [v for v in vals if v is not None]
    lo, hi = min(good), max(good)
    if hi == lo:
        hi = lo + 1
    if sleep:
        a_, b_ = sleep
        n_ = len(vals)
        xa = x0 + (x1 - x0) * a_ / (n_ - 1)
        xb = x0 + (x1 - x0) * (b_ - 1) / (n_ - 1)
        s.add('<rect x="%.1f" y="%d" width="%.1f" height="%d" fill="%s"/>' % (xa, CHART_TOP, xb - xa, CHART_BOTTOM - CHART_TOP, BLUE_DIM))
        if a_ > 0:
            moon(s, xa, CHART_TOP - 12)
        if b_ < n_:
            sun(s, xb, CHART_TOP - 12)
    s.text(x1 + 6, CHART_TOP, str(max(good)), "label", GREY_LIGHT, "start")
    s.text(x1 + 6, CHART_BOTTOM, str(min(good)), "label", GREY_LIGHT, "start")
    n = len(vals)
    prev = None
    for i, v in enumerate(vals):
        if v is None:
            prev = None
            continue
        x = x0 + (x1 - x0) * i / (n - 1)
        y = CHART_BOTTOM - (v - lo) * (CHART_BOTTOM - CHART_TOP) / (hi - lo)
        if prev:
            s.line(prev, (x, y), color, 3)
        prev = (x, y)
    if prev:
        s.circle(prev[0], prev[1], 4, color)
    for x, anchor, t in zip((x0, CX, x1), ("start", "middle", "end"), xlabels):
        s.text(x, Y_XLABELS, t, "label", GREY_LIGHT, anchor)


def graph_page(s, ox, oy, title, stats, draw, caption=None):
    screen(s, ox, oy)
    stripes(s, 0)
    s.text(CX, Y_TITLE, title, "title", GREY_LIGHT)
    if caption:
        s.text(CX, Y_CAPTION, caption, "label", GREY_LIGHT)
    draw()
    s.text(CX, Y_STATS, stats, "label", GREY_LIGHT)
    nav(s, 1, False)
    s.add("</g>")


def graphs():
    s = Svg()
    cols, rows = 3, 2
    tw, th = cols * W + (cols - 1) * 40, rows * H + (rows - 1) * 40
    s.add('<rect x="-20" y="-20" width="%d" height="%d" fill="#1b1b1b"/>' % (tw + 40, th + 40))
    px, py = W + 40, H + 40

    steps = [4210, 8032, 6120, 9400, 3100, 7012, 6214]
    days = ["T", "F", "S", "S", "M", "T", "W"]
    active = [22, 35, 12, 0, 28, 41, 18]
    # Mock 24 h ending at 08:00 Wed. A night at buckets 30..43 (23:00 to 06:00):
    # heart rate drops and body battery rises, as it would for real sleep.
    hr = [52 + int(3 * math.sin(i)) if 30 <= i < 44 else 72 + int(8 * math.sin(i / 2.3)) + (22 if 12 < i < 16 else 0)
          for i in range(48)]
    body = [int(85 - i * 1.7) if i < 30 else int(34 + (i - 30) * 4.0) if i < 44 else 88 for i in range(48)]
    sleep = find_sleep(hr, body)
    assert sleep, "mock night should be detected"
    t0 = 8 * 60 - 24 * 60                       # minutes, relative to now = 08:00

    def hhmm(idx):
        m = (t0 + idx * 30) % (24 * 60)
        return "%02d:%02d" % (m // 60, m % 60)
    note = "Sleep %s–%s · estimated" % (hhmm(sleep[0]), hhmm(sleep[1]))
    temp = [18, 19, 20, 20, 19, 18, 17, 15, 14, 13, 12, 11]

    graph_page(s, 0, 0, "STEPS · 7 DAYS", "Avg 6284   Best 9400   Goal 10000",
               lambda: bar_chart(s, steps, 10000, METRIC["steps"], days))
    graph_page(s, px, 0, "ACTIVE MIN · 7 DAYS", "Avg 22   Best 41   Daily target 21",
               lambda: bar_chart(s, active, 21, METRIC["active"], days))
    graph_page(s, px * 2, 0, "BODY BATTERY · 24 H", "Low %d   High %d" % (min(body), max(body)),
               lambda: line_chart(s, body, METRIC["body"], ["24h ago", "12h", "now"], sleep), note)
    graph_page(s, 0, py, "HEART RATE · 24 H", "Min %d   Max %d" % (min(hr), max(hr)),
               lambda: line_chart(s, hr, METRIC["hr"], ["24h ago", "12h", "now"], sleep), note)
    graph_page(s, px, py, "TEMPERATURE · 12 H", "Low 11&#176;   High 20&#176;",
               lambda: line_chart(s, temp, METRIC["weather"], ["14:00", "20:00", "01:00"]))
    return s.doc(tw + 40, th + 40, "-20 -20 %d %d" % (tw + 40, th + 40))


# ---------------------------------------------------------------- rendering
OUTPUTS = {          # name -> (svg generator, png file name)
    "dial": (lambda: dial(), "wireframe.png"),
    "tap-zones": (lambda: dial(zones=True), "tap-zones.png"),
    "pages": (lambda: pages(), "pages.png"),
    "graphs": (lambda: graphs(), "graphs.png"),
}


def svg_size(path):
    head = Path(path).read_text()[:400]
    return (int(re.search(r'width="(\d+)"', head).group(1)),
            int(re.search(r'height="(\d+)"', head).group(1)))


def _chrome():
    for cand in (os.environ.get("CHROME_PATH"), shutil.which("google-chrome"),
                 shutil.which("google-chrome-stable"), shutil.which("chromium"),
                 shutil.which("chromium-browser")):
        if cand and Path(cand).exists():
            return cand
    return None


def renderer():
    """Return a function (svg_path, png_path) -> None, or None if nothing is installed."""
    if shutil.which("rsvg-convert"):
        return lambda a, b: subprocess.run(["rsvg-convert", "-w", str(svg_size(a)[0]), a, "-o", b], check=True)
    if shutil.which("inkscape"):
        return lambda a, b: subprocess.run(["inkscape", a, "-o", b, "-w", str(svg_size(a)[0])],
                                           check=True, capture_output=True)
    try:
        import cairosvg
        return lambda a, b: cairosvg.svg2png(url=a, write_to=b, output_width=svg_size(a)[0])
    except ImportError:
        pass
    chrome = _chrome()
    if chrome:
        def via_chrome(a, b):
            w, h = svg_size(a)
            cmd = [chrome, "--headless", "--disable-gpu", "--hide-scrollbars",
                   "--screenshot=" + b, "--window-size=%d,%d" % (w, h), Path(a).as_uri()]
            if hasattr(os, "geteuid") and os.geteuid() == 0:
                cmd.insert(1, "--no-sandbox")          # Chrome refuses to run as root otherwise
            subprocess.run(cmd, check=True, capture_output=True)
        return via_chrome
    return None


def main():
    ap = argparse.ArgumentParser(description="Generate the README wireframes from Theme.mc.")
    ap.add_argument("--out", default=str(ROOT / "docs"), help="output directory (default: docs/)")
    ap.add_argument("--svg-only", action="store_true", help="write SVGs and skip PNG rendering")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    if args.svg_only:
        for name, (gen, _) in OUTPUTS.items():
            (out / (name + ".svg")).write_text(gen())
            print("wrote", out / (name + ".svg"))
        return 0

    render = renderer()
    if render is None:
        sys.exit("No SVG renderer found. Install one of: rsvg-convert (librsvg2-bin), inkscape, "
                 "the cairosvg Python package, or Google Chrome / Chromium (or set CHROME_PATH).\n"
                 "Or run with --svg-only to write the SVGs.")
    with tempfile.TemporaryDirectory() as tmp:
        for name, (gen, png) in OUTPUTS.items():
            svg = Path(tmp) / (name + ".svg")
            svg.write_text(gen())
            render(str(svg), str(out / png))
            print("wrote", out / png)
    return 0


if __name__ == "__main__":
    sys.exit(main())
