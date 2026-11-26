#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# dependencies = ["cairosvg"]
# ///
"""Generate the README wireframes from source/Theme.mc.

    uv run tools/wireframes.py              # render PNGs into docs/
    uv run tools/wireframes.py --svg-only   # write SVGs instead (no renderer needed)
    uv run tools/wireframes.py --out DIR    # write somewhere else

Colours, spacing and font-size roles are read from Theme.mc, so the mock-ups follow
the theme. Layout that lives in BmwMWatchView.mc and BmwMDetail.mc (positions as
fractions of the dial radius, logo geometry, hand lengths) is mirrored in this
script and must be kept in sync by hand.

uv installs the one Python dependency (cairosvg) into a throwaway environment, so there is
nothing to set up. PNG output needs one SVG renderer, tried in this order: rsvg-convert,
inkscape, the cairosvg package (needs the system cairo library, `libcairo2`), Google Chrome /
Chromium. Set CHROME_PATH to point at a specific Chrome binary.

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
_consts = dict(re.findall(r"const (\w+)\s*=\s*(0x[0-9A-Fa-f]+|-?[0-9.]+)\s*;", _theme))


def num(name):
    return float(_consts[name]) if "." in _consts[name] else int(_consts[name], 0)


def col(name):
    return "#%06X" % int(_consts[name], 0)


BLUE, NAVY, RED = col("BLUE"), col("NAVY"), col("RED")
BLUE_DIM, NAVY_DIM, RED_DIM = col("BLUE_DIM"), col("NAVY_DIM"), col("RED_DIM")
WHITE, BLACK = col("WHITE"), col("BLACK")
GREY = col("GREY")
CHROME = "#555555"          # the mock watch bezel in the images; not part of the face
ZONE_COLORS = {1: "#FFD400", 2: "#E040FB", 3: "#3DDC84", 4: "#FF8A00", 5: "#00C0FF"}   # touch targets: yellow, magenta, green, orange, cyan
GAP, TICK_INSET = num("GAP"), num("TICK_INSET")
TICK_MAJOR, TICK_MINOR = num("TICK_MAJOR"), num("TICK_MINOR")
MARGIN, ROW_PITCH = num("MARGIN"), num("ROW_PITCH")
BAR_W, BAR_H, BAR_R = num("BAR_W"), num("BAR_H"), num("BAR_R")
Y_STRIPES, Y_TITLE, Y_HERO, Y_SUB, Y_NOTE, Y_ROWS = (num("Y_STRIPES"), num("Y_TITLE"), num("Y_HERO"), num("Y_SUB"),
                                                     num("Y_NOTE"), num("Y_ROWS"))
CHART_X, CHART_TOP, CHART_BOTTOM = num("CHART_X"), num("CHART_TOP"), num("CHART_BOTTOM")
Y_XLABELS, Y_STATS, Y_DOTS, DOT_R = num("Y_XLABELS"), num("Y_STATS"), num("Y_DOTS"), num("DOT_R")
Y_CAPTION = num("Y_CAPTION")
BATT_W, BATT_H, BATT_R, BATT_TERM_W, BATT_TERM_H, BATT_PAD = (num("BATT_W"), num("BATT_H"), num("BATT_R"),
                                                                num("BATT_TERM_W"), num("BATT_TERM_H"),
                                                                num("BATT_PAD"))
CARD_W, CARD_H, CARD_H_ROWS, CARD_R, CARD_PAD = (num("CARD_W"), num("CARD_H"), num("CARD_H_ROWS"), num("CARD_R"),
                                                  num("CARD_PAD"))
CARD_TITLE_Y, CARD_BIG_Y, CARD_DETAIL_Y, CARD_ROW_Y, CARD_ROW_PITCH = (num("CARD_TITLE_Y"), num("CARD_BIG_Y"),
                                                                        num("CARD_DETAIL_Y"), num("CARD_ROW_Y"),
                                                                        num("CARD_ROW_PITCH"))
WINDOW_LABEL_DY, WINDOW_VALUE_DY = num("WINDOW_LABEL_DY"), num("WINDOW_VALUE_DY")
TOUCH_R, TOUCH_TEMP_HALF_R, TOUCH_ARC_ANGLE = num("TOUCH_R"), num("TOUCH_TEMP_HALF_R"), num("TOUCH_ARC_ANGLE")
TOUCH_RING_OUT, TOUCH_RING_IN = num("TOUCH_RING_OUT"), num("TOUCH_RING_IN")
STRIPE_H = num("STRIPE_H")
NAV_CHEVRON_X, CHEVRON_HALF_W, CHEVRON_HALF_H, DOT_PITCH = (num("NAV_CHEVRON_X"), num("CHEVRON_HALF_W"),
                                                              num("CHEVRON_HALF_H"), num("DOT_PITCH"))
MARK_DY, MOON_R, MOON_CUT_R, MOON_CUT_DX, MOON_CUT_DY = (num("MARK_DY"), num("MOON_R"), num("MOON_CUT_R"),
                                                          num("MOON_CUT_DX"), num("MOON_CUT_DY"))
SUN_R, SUN_RAY_IN, SUN_RAY_OUT, LINE_END_R = num("SUN_R"), num("SUN_RAY_IN"), num("SUN_RAY_OUT"), num("LINE_END_R")
CLOUD_STRIP_DY, CLOUD_STRIP_H = num("CLOUD_STRIP_DY"), num("CLOUD_STRIP_H")
ACT_GLYPH, ACT_GLYPH_DX, ACT_TEXT_DX = num("ACT_GLYPH"), num("ACT_GLYPH_DX"), num("ACT_TEXT_DX")
ACT_LABEL_DY, ACT_VALUE_DY, ACT_BAR_DY = num("ACT_LABEL_DY"), num("ACT_VALUE_DY"), num("ACT_BAR_DY")
ACT_CHEVRON_X, ACT_CHEVRON_DY = num("ACT_CHEVRON_X"), num("ACT_CHEVRON_DY")
WEATHER_Y_UNIT, WEATHER_UNIT_DX = num("WEATHER_Y_UNIT"), num("WEATHER_UNIT_DX")
ACTIVITY_ROW_TOP, ACTIVITY_ROW_PITCH = num("ACTIVITY_ROW_TOP"), num("ACTIVITY_ROW_PITCH")
BAR_COLS_W, BAR_COLS_GAP = num("BAR_COLS_W"), num("BAR_COLS_GAP")
DIM = {BLUE: BLUE_DIM, NAVY: NAVY_DIM, RED: RED_DIM}
# Theme.metricColor(): one colour per metric everywhere
METRIC = {"steps": BLUE, "active": NAVY, "body": RED, "hr": RED, "weather": RED, "temp": RED, "stress": RED}

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
          'stroke="%s" stroke-width="3"/>' % (ox, oy, W, H, BLACK, CHROME))


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


def draw_battery_icon(s, x, y, pct):
    """Mirror of drawBatteryIcon(): grey outline and terminal, white fill (red below 20%)."""
    left, top = x - BATT_W / 2, y - BATT_H / 2
    s.add('<rect x="%.1f" y="%.1f" width="%d" height="%d" rx="%d" fill="none" stroke="%s" stroke-width="2"/>'
          % (left, top, BATT_W, BATT_H, BATT_R, GREY))
    s.add('<rect x="%.1f" y="%.1f" width="%d" height="%d" fill="%s"/>'
          % (left + BATT_W, y - BATT_TERM_H / 2, BATT_TERM_W, BATT_TERM_H, GREY))
    fill_w = (BATT_W - 2 * BATT_PAD) * pct / 100.0
    if fill_w > 0:
        s.add('<rect x="%.1f" y="%.1f" width="%.1f" height="%d" fill="%s"/>'
              % (left + BATT_PAD, top + BATT_PAD, fill_w, BATT_H - 2 * BATT_PAD, RED if pct < 20 else WHITE))


def draw_card(s, kind):
    """Mirror of DetailPage.drawCard(): a quick card over the dial, with example values."""
    rows = kind == "activity"
    ch = CARD_H_ROWS if rows else CARD_H
    left, top = CX - CARD_W / 2, CY - ch / 2
    s.add('<rect x="%.1f" y="%.1f" width="%d" height="%d" rx="%d" fill="%s" stroke="%s" stroke-width="2"/>'
          % (left, top, CARD_W, ch, CARD_R, BLACK, GREY))
    title, big, detail = {
        "battery": ("WATCH BATTERY", "82%", "6.3 days left"),
        "date": ("TODAY", "Wednesday", "25 November 2026"),
        "weather": ("WEATHER", "18&#176;C", "Partly cloudy &#183; feels 16&#176;"),
        "hr": ("HEART RATE", "72 bpm", "Resting 52 &#183; Stress 34"),
        "activity": ("ACTIVITY", "", ""),
    }[kind]
    s.text(CX, top + CARD_TITLE_Y, title, "label", GREY)
    if rows:
        for i, (n, v) in enumerate([("Steps", "6214 / 10000"), ("Active (week)", "68 / 150 min"), ("Body battery", "78")]):
            y = top + CARD_ROW_Y + i * CARD_ROW_PITCH
            s.text(left + CARD_PAD, y, n, "label", GREY, "start")
            s.text(left + CARD_W - CARD_PAD, y, v, "value", WHITE, "end")
    else:
        s.text(CX, top + CARD_BIG_Y, big, "title", WHITE)
        s.text(CX, top + CARD_DETAIL_Y, detail, "label", GREY)


def dial_into(s, ox, oy, zones=False, card=None):
    screen(s, ox, oy)
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
               WHITE if major else GREY, 4 if major else 2)
    draw_badge(s, CY - R * .4)
    temp_y = CY - (RING_OUT - PITCH)                 # Geometry.tempY()
    s.text(CX, temp_y, "18&#176;C", "value", WHITE)  # the weather tap target
    arc = RING_OUT - PITCH                           # one arc: the middle ring's distance from the centre
    sx = CX + arc                                    # the date window at 3 o'clock
    s.text(sx, CY + WINDOW_LABEL_DY, "WED", "label", GREY)
    s.text(sx, CY + WINDOW_VALUE_DY, "25", "value", WHITE)
    draw_battery_icon(s, CX - arc, CY, 82)   # the battery at 9 o'clock
    draw_hand(s, (10 + 8 / 60) * 30, R * .56, R * .07, R * .1)
    draw_hand(s, (8 + 35 / 60) * 6, R * .88, R * .05, R * .12)
    a = math.radians(35 * 6)
    s.line((CX - math.sin(a) * R * .18, CY + math.cos(a) * R * .18),
           (CX + math.sin(a) * R * .94, CY - math.cos(a) * R * .94), RED, 3)
    draw_roundel(s)
    if zones:
        # One colour per target, far apart in hue and none of them a watch colour (blue, navy,
        # red, white, grey), so the overlay never reads as part of the face.
        r_hi, r_lo = RING_OUT + TOUCH_RING_OUT, RING_OUT - 2 * PITCH - TOUCH_RING_IN
        z = ZONE_COLORS
        s.add('<clipPath id="scr"><rect width="%d" height="%d" rx="70"/></clipPath><g clip-path="url(#scr)">' % (W, H))
        shape = 'fill="%s" fill-opacity=".25" stroke="%s" stroke-width="2"'
        top_lo, top_hi = 90 - TOUCH_ARC_ANGLE, 90 + TOUCH_ARC_ANGLE          # the temperature arc, around 12 o'clock
        t_in, t_out = arc - TOUCH_TEMP_HALF_R, arc + TOUCH_TEMP_HALF_R
        tband = ([pt(t_out, a_) for a_ in range(top_lo, top_hi + 1, 3)]
                 + [pt(t_in, a_) for a_ in range(top_hi, top_lo - 1, -3)])
        s.add('<polygon points="%s" %s/>' % (pts(tband), shape % (z[1], z[1])))
        s.add('<circle cx="%.1f" cy="%.1f" r="%.1f" %s/>' % (CX + arc, CY, R * TOUCH_R, shape % (z[2], z[2])))
        s.add('<circle cx="%.1f" cy="%.1f" r="%.1f" %s/>' % (CX - arc, CY, R * TOUCH_R, shape % (z[3], z[3])))
        s.add('<circle cx="%.1f" cy="%.1f" r="%.1f" %s/>' % (CX, CY, R * TOUCH_R, shape % (z[4], z[4])))
        lo_a, hi_a = 270 - TOUCH_ARC_ANGLE, 270 + TOUCH_ARC_ANGLE
        band = ([pt(r_hi, a_) for a_ in range(lo_a, hi_a + 1, 3)]
                + [pt(r_lo, a_) for a_ in range(hi_a, lo_a - 1, -3)])
        s.add('<polygon points="%s" %s/>' % (pts(band), shape % (z[5], z[5])))
        s.add('</g>')                                   # end of the screen clip
        # The number badge always sits centred on the top edge of its target's outline.
        badge = lambda x, y, n: (s.circle(x, y, 12, z[n]), s.text(x, y, str(n), "label", BLACK))
        badge(CX, CY - t_out, 1)                        # temperature: top (outer edge) of its arc
        badge(CX + arc, CY - R * TOUCH_R, 2)                # date: top of its circle
        badge(CX - arc, CY - R * TOUCH_R, 3)                # battery: top of its circle
        badge(CX, CY - R * TOUCH_R, 4)                      # roundel: top of its circle
        badge(CX, CY + r_lo, 5)                         # rings: top (inner edge) of the wedge
    if card:
        draw_card(s, card)
    s.add("</g>")


def tap_zones():
    """The dial with its touch targets numbered, and a legend of what a tap and a hold do."""
    s = Svg()
    lw = 600
    s.add('<rect x="-30" y="-30" width="%d" height="%d" fill="#1b1b1b"/>' % (W + 60 + lw, H + 60))
    dial_into(s, 0, 0, True)
    x0 = W + 40
    s.text(x0, 40, "Touch targets", "title", WHITE, "start")
    rows = [("1", ZONE_COLORS[1], "Temperature (12 o'clock)", "tap: weather card", "hold: Weather page"),
            ("2", ZONE_COLORS[2], "Date (3 o'clock)", "tap: date card", "hold: nothing"),
            ("3", ZONE_COLORS[3], "Battery (9 o'clock)", "tap: battery card", "hold: nothing"),
            ("4", ZONE_COLORS[4], "Roundel (centre)", "tap: heart rate card", "hold: Heart rate page"),
            ("5", ZONE_COLORS[5], "Rings (bottom)", "tap: activity card", "hold: Activity page")]
    for i, (n, c, name, tap, hold) in enumerate(rows):
        y = 90 + i * 70
        s.circle(x0 + 12, y, 12, c)
        s.text(x0 + 12, y, n, "label", BLACK)
        s.text(x0 + 36, y, name, "value", WHITE, "start")
        s.text(x0 + 36, y + 28, tap + "   &#183;   " + hold, "label", GREY, "start")
    s.text(x0, 90 + 5 * 70 + 6, "A tap peeks: a quick card; tap anywhere to dismiss it.", "label", GREY, "start")
    s.text(x0, 90 + 5 * 70 + 32, "A hold goes deeper: it opens the page, where there is one.", "label", GREY, "start")
    return s.doc((W + 60 + lw) * 1.6, (H + 60) * 1.6, "-30 -30 %d %d" % (W + 60 + lw, H + 60))


def dial(zones=False):
    s = Svg()
    s.add('<rect x="-30" y="-30" width="%d" height="%d" fill="#1b1b1b"/>' % (W + 60, H + 60))
    dial_into(s, 0, 0, zones)
    return s.doc((W + 60) * 2, (H + 60) * 2, "-30 -30 %d %d" % (W + 60, H + 60))


def cards():
    """The quick cards shown on a tap, over the dial."""
    s = Svg()
    kinds = ["battery", "weather", "activity"]
    total = len(kinds) * W + (len(kinds) - 1) * 40
    s.add('<rect x="-20" y="-20" width="%d" height="%d" fill="#1b1b1b"/>' % (total + 40, H + 40))
    for i, k in enumerate(kinds):
        dial_into(s, i * (W + 40), 0, False, k)
    return s.doc(total + 40, H + 40, "-20 -20 %d %d" % (total + 40, H + 40))


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
    s.add('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="%d"/>' % (x, y, rr, DIM.get(c, BLUE_DIM), glyph_pen(sz)))
    s.arc(x, y, rr, 90, 90 - 360 * frac, c, glyph_pen(sz), cw=True)
    s.circle(x, y - sz * .24, sz * .1, GREY)
    for x1, y1, x2, y2 in [(0, -.1, 0, .15), (0, -.02, -.22, -.17), (0, -.02, .22, -.17),
                           (0, .15, -.14, .36), (0, .15, .14, .36)]:
        s.line((x + x1 * sz, y + y1 * sz), (x + x2 * sz, y + y2 * sz), GREY, glyph_pen(sz))


# ---------------------------------------------------------------- detail pages
def stripes(s, ox):
    """The face badge's stripes, scaled down: the same geometry as Logo.stripePoints()."""
    k = STRIPE_H / 99.0
    left = ox + CX - 175 * k / 2
    top = Y_STRIPES - STRIPE_H / 2
    for xt, c in LOGO_STRIPES:
        s.poly([(left + (x - 9) * k, top + y * k) for x, y in
                [(xt, 0), (xt + 36, 0), (xt + 36 - 57, 99), (xt - 57, 99)]], c)


def bar(s, ox, y, frac, c):
    s.add('<rect x="%.1f" y="%.1f" width="%d" height="%d" rx="%d" fill="%s"/>'
          % (ox + CX - BAR_W / 2, y - BAR_H / 2, BAR_W, BAR_H, BAR_R, DIM.get(c, BLUE_DIM)))
    s.add('<rect x="%.1f" y="%.1f" width="%.1f" height="%d" rx="%d" fill="%s"/>'
          % (ox + CX - BAR_W / 2, y - BAR_H / 2, BAR_W * frac, BAR_H, BAR_R, c))


def row(s, ox, y, label, value):
    s.text(ox + MARGIN, y, label, "label", GREY, "start")
    s.text(ox + W - MARGIN, y, value, "value", WHITE, "end")


def chevron(s, x, y, right):
    d = -CHEVRON_HALF_W if right else CHEVRON_HALF_W
    s.add('<polyline points="%.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="none" stroke="%s" stroke-width="3"/>'
          % (x + d, y - CHEVRON_HALF_H, x - d, y, x + d, y + CHEVRON_HALF_H, GREY))


def nav(s, sub, from_activity, count=2):
    """Edge chevrons and page dots, as drawNav() in BmwMDetail.mc."""
    if sub < count - 1:
        chevron(s, W - NAV_CHEVRON_X, H / 2, True)
    if sub >= 1 or from_activity:
        chevron(s, NAV_CHEVRON_X, H / 2, False)
    for i in range(count):
        s.circle(CX + (i - (count - 1) / 2.0) * DOT_PITCH, Y_DOTS, DOT_R, WHITE if i == sub else GREY)


def pages():
    s = Svg()
    total = W * 4 + 120
    s.add('<rect x="-20" y="-20" width="%d" height="%d" fill="#1b1b1b"/>' % (total + 40, H + 40))

    # 1: Activity page (hold the ring zone). Each row opens that metric.
    screen(s, 0)
    stripes(s, 0)
    s.text(CX, Y_TITLE, "ACTIVITY", "title", GREY)
    items = [("Steps", "6214 / 10000", .62, BLUE, "walker"),
             ("Active minutes (week)", "68 / 150 min", .45, NAVY, "bolt"),
             ("Body battery", "78 / 100", .78, RED, "body")]
    for i, (name, val, frac, c, g) in enumerate(items):
        y = ACTIVITY_ROW_TOP + 50 + i * ACTIVITY_ROW_PITCH
        gx = MARGIN + ACT_GLYPH_DX
        if g == "walker":
            g_walker(s, gx, y, ACT_GLYPH, BLUE)
        elif g == "bolt":
            g_bolt(s, gx, y, ACT_GLYPH, WHITE)
        else:
            g_body(s, gx, y, ACT_GLYPH, RED, frac)
        s.text(MARGIN + ACT_TEXT_DX, y + ACT_LABEL_DY, name, "label", GREY, "start")
        s.text(MARGIN + ACT_TEXT_DX, y + ACT_VALUE_DY, val, "value", WHITE, "start")
        bar(s, 0, y + ACT_BAR_DY, frac, c)
        chevron(s, W - ACT_CHEVRON_X, y + ACT_CHEVRON_DY, True)
    s.add("</g>")

    # 2: a metric page (steps), opened from Activity, so it has a back chevron
    screen(s, W + 40)
    stripes(s, 0)
    s.text(CX, Y_TITLE, "STEPS", "title", GREY)
    s.text(CX, Y_HERO, "6214", "hero", WHITE)
    s.text(CX, Y_SUB, "of 10000 goal", "label", GREY)
    bar(s, 0, Y_NOTE, .62, BLUE)
    for i, (l, v) in enumerate([("Distance", "4.7 km"), ("Calories", "312 kcal"), ("Floors", "6 / 10")]):
        row(s, 0, Y_ROWS + i * ROW_PITCH, l, v)
    nav(s, 0, True)
    s.add("</g>")

    # 3: weather page, opened from the dial
    screen(s, (W + 40) * 2)
    stripes(s, 0)
    s.text(CX, Y_TITLE, "WEATHER", "title", GREY)
    s.text(CX, Y_HERO, "18", "hero", WHITE)
    s.text(CX + 61 + WEATHER_UNIT_DX - 8, WEATHER_Y_UNIT, "&#176;C", "title", GREY, "start")
    s.text(CX, Y_SUB, "Partly cloudy", "title", WHITE)
    s.text(CX, Y_NOTE, "Feels like 16&#176;", "label", GREY)
    for i, (l, v) in enumerate([("High / low", "20&#176; / 9&#176;"), ("Rain chance", "30%"),
                                ("Wind", "12 km/h NW"), ("Humidity", "65%")]):
        row(s, 0, Y_ROWS + i * ROW_PITCH, l, v)
    for i, (t, v) in enumerate([("14", "19&#176;"), ("17", "20&#176;"), ("20", "17&#176;"), ("23", "14&#176;")]):
        x = W * (.2 + .2 * i)
        s.text(x, Y_ROWS + 4 * ROW_PITCH, t, "label", GREY)
        s.text(x, Y_ROWS + 5 * ROW_PITCH, v, "value", WHITE)
    nav(s, 0, False)
    s.add("</g>")
    # 4: Body Battery detail, opened from Activity, with four pages in all
    screen(s, (W + 40) * 3)
    stripes(s, 0)
    s.text(CX, Y_TITLE, "BODY BATTERY", "title", GREY)
    s.text(CX, Y_HERO, "78", "hero", WHITE)
    s.text(CX, Y_SUB, "High energy", "label", GREY)
    bar(s, 0, Y_NOTE, .78, METRIC["body"])
    for i, (l, v) in enumerate([("24 h low / high", "34 / 88"), ("Stress", "34 &#183; Low"), ("Sleep score", "82")]):
        row(s, 0, Y_ROWS + i * ROW_PITCH, l, v)
    nav(s, 0, True, 4)
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
                  % (x, CHART_BOTTOM - th, BAR_COLS_W, th, DIM.get(color, BLUE_DIM)))
        if v is not None:
            hgt = v * (CHART_BOTTOM - CHART_TOP) / maxv
            s.add('<rect x="%.1f" y="%.1f" width="%d" height="%.1f" fill="%s"/>'
                  % (x, CHART_BOTTOM - hgt, BAR_COLS_W, hgt, color))
        s.text(x + BAR_COLS_W / 2, Y_XLABELS, labels[i], "label", WHITE if i == n - 1 else GREY)
    s.line((x0, CHART_BOTTOM), (x0 + total, CHART_BOTTOM), BLUE_DIM, 2)


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
    s.circle(x, y, MOON_R, GREY)
    s.circle(x + MOON_CUT_DX, y + MOON_CUT_DY, MOON_CUT_R, BLACK)


def sun(s, x, y):
    s.circle(x, y, SUN_R, WHITE)
    for i in range(8):
        a = i * math.pi / 4
        s.line((x + math.cos(a) * SUN_RAY_IN, y + math.sin(a) * SUN_RAY_IN),
               (x + math.cos(a) * SUN_RAY_OUT, y + math.sin(a) * SUN_RAY_OUT), WHITE, 2)


def grey_level(pct):
    """Mirror of Stats.greyLevel()."""
    p = max(0, min(100, pct))
    v = p * int(GREY[3:5], 16) // 100
    return "#%02X%02X%02X" % (v, v, v)


def line_chart(s, vals, color, xlabels, sleep=None, rain=None, cloud=None, frozen=None, tenths=False):
    x0, x1 = CHART_X, W - CHART_X
    s.line((x0, CHART_BOTTOM), (x1, CHART_BOTTOM), BLUE_DIM, 2)
    s.line((x0, CHART_TOP), (x1, CHART_TOP), BLUE_DIM, 2)
    good = [v for v in vals if v is not None]
    lo, hi = min(good), max(good)
    if hi == lo:
        hi = lo + 1
    if rain and cloud:
        step = (x1 - x0) / (len(vals) - 1)
        for i in range(len(vals)):
            cx_ = x0 + step * i
            if rain[i]:
                rh = rain[i] * (CHART_BOTTOM - CHART_TOP) / 100.0
                s.add('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s"/>'
                      % (cx_ - step * .35, CHART_BOTTOM - rh, step * .7, rh, WHITE if frozen and frozen[i] else BLUE))
            sx, sw = cx_ - step / 2, step
            if sx < x0:
                sw -= x0 - sx
                sx = x0
            if sx + sw > x1:
                sw = x1 - sx
            s.add('<rect x="%.1f" y="%d" width="%.1f" height="%d" fill="%s"/>'
                  % (sx, CHART_TOP + CLOUD_STRIP_DY, sw, CLOUD_STRIP_H, grey_level(cloud[i])))
    if sleep:
        a_, b_ = sleep
        n_ = len(vals)
        xa = x0 + (x1 - x0) * a_ / (n_ - 1)
        xb = x0 + (x1 - x0) * (b_ - 1) / (n_ - 1)
        s.add('<rect x="%.1f" y="%d" width="%.1f" height="%d" fill="%s"/>' % (xa, CHART_TOP, xb - xa, CHART_BOTTOM - CHART_TOP, BLUE_DIM))
        if a_ > 0:
            moon(s, xa, CHART_TOP + MARK_DY)
        if b_ < n_:
            sun(s, xb, CHART_TOP + MARK_DY)
    fmt = (lambda v: "%.1f" % (v / 10.0)) if tenths else str
    s.text(x1 + 6, CHART_TOP, fmt(max(good)), "label", GREY, "start")
    s.text(x1 + 6, CHART_BOTTOM, fmt(min(good)), "label", GREY, "start")
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
        s.circle(prev[0], prev[1], LINE_END_R, color)
    for x, anchor, t in zip((x0, CX, x1), ("start", "middle", "end"), xlabels):
        s.text(x, Y_XLABELS, t, "label", GREY, anchor)


def graph_page(s, ox, oy, title, stats, draw, caption=None, sub=1, count=2):
    screen(s, ox, oy)
    stripes(s, 0)
    s.text(CX, Y_TITLE, title, "title", GREY)
    if caption:
        s.text(CX, Y_CAPTION, caption, "label", GREY)
    draw()
    s.text(CX, Y_STATS, stats, "label", GREY)
    nav(s, sub, False, count)
    s.add("</g>")


def graphs():
    s = Svg()
    cols, rows = 3, 3
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
    temp = [4, 4, 3, 3, 2, 1, 1, 0, 0, -1, -1, -2]       # a cold evening: rain turns to snow

    graph_page(s, 0, 0, "STEPS · 7 DAYS", "Avg 6284   Best 9400   Goal 10000",
               lambda: bar_chart(s, steps, 10000, METRIC["steps"], days))
    graph_page(s, px, 0, "ACTIVE MIN · 7 DAYS", "Avg 22   Best 41   Daily target 21",
               lambda: bar_chart(s, active, 21, METRIC["active"], days))
    graph_page(s, px * 2, 0, "BODY BATTERY · 24 H", "Low %d   High %d" % (min(body), max(body)),
               lambda: line_chart(s, body, METRIC["body"], ["24h ago", "12h", "now"], sleep), note, 1, 4)
    graph_page(s, 0, py, "HEART RATE · 24 H", "Min %d   Max %d" % (min(hr), max(hr)),
               lambda: line_chart(s, hr, METRIC["hr"], ["24h ago", "12h", "now"], sleep), note)
    rain = [0, 10, 30, 60, 70, 60, 50, 60, 80, 70, 50, 30]
    frozen = [False] * 7 + [True] * 5                       # rain first, then snow from 21:00
    cloud = [40, 60, 80, 90, 100, 100, 90, 100, 100, 90, 80, 70]
    graph_page(s, px, py, "TEMPERATURE · 12 H", "Low %d&#176;   High %d&#176;" % (min(temp), max(temp)),
               lambda: line_chart(s, temp, METRIC["weather"], ["14", "20", "01"], None, rain, cloud, frozen),
               "Bars: precipitation · Strip: cloud cover")
    # Stress: low overnight, bumps through the day
    stress = [max(5, int((14 if 30 <= i < 44 else 38) + 16 * math.sin(i / 3.0) + (20 if 14 < i < 18 else 0)))
              for i in range(48)]
    graph_page(s, 0, py * 2, "STRESS · 24 H", "Avg %d   Max %d" % (sum(stress) // len(stress), max(stress)),
               lambda: line_chart(s, stress, METRIC["stress"], ["24h ago", "12h", "now"], sleep), note, 2, 4)
    # Sensor temperature, in tenths of a degree: it typically climbs a little during sleep
    skin = [int(332 + 6 * math.sin(i / 4.0) + (10 if 30 <= i < 44 else 0)) for i in range(48)]
    graph_page(s, px * 2, py, "SENSOR TEMP · 24 H", "Low %.1f&#176;   High %.1f&#176;" % (min(skin) / 10, max(skin) / 10),
               lambda: line_chart(s, skin, METRIC["temp"], ["24h ago", "12h", "now"], sleep, tenths=True), note, 3, 4)
    return s.doc(tw + 40, th + 40, "-20 -20 %d %d" % (tw + 40, th + 40))


# ---------------------------------------------------------------- rendering
OUTPUTS = {          # name -> (svg generator, png file name)
    "dial": (lambda: dial(), "wireframe.png"),
    "tap-zones": (lambda: tap_zones(), "tap-zones.png"),
    "pages": (lambda: pages(), "pages.png"),
    "graphs": (lambda: graphs(), "graphs.png"),
    "cards": (lambda: cards(), "cards.png"),
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
    except Exception:      # not installed, or its cairo system library is missing
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
                 "the cairosvg package (via uv), or Google Chrome / Chromium (or set CHROME_PATH).\n"
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
