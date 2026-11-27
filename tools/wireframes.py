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
the theme. Layout that lives in BmwMWatchView.mc and Cards.mc (positions as
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
ZONE_COLORS = {1: "#E040FB", 2: "#3DDC84", 3: "#FF8A00", 4: "#00C0FF"}   # touch targets: magenta, green, orange, cyan
GAP, TICK_INSET, RING_TICK_GAP = num("GAP"), num("TICK_INSET"), num("RING_TICK_GAP")
TICK_MAJOR, TICK_MINOR = num("TICK_MAJOR"), num("TICK_MINOR")
BATT_W, BATT_H, BATT_R, BATT_TERM_W, BATT_TERM_H, BATT_PAD = (num("BATT_W"), num("BATT_H"), num("BATT_R"),
                                                                num("BATT_TERM_W"), num("BATT_TERM_H"),
                                                                num("BATT_PAD"))
CARD_W, CARD_H, CARD_H_ROWS, CARD_H_TWO, CARD_R, CARD_PAD = (num("CARD_W"), num("CARD_H"), num("CARD_H_ROWS"),
                                                              num("CARD_H_TWO"), num("CARD_R"), num("CARD_PAD"))
CARD_DETAIL2_PITCH = num("CARD_DETAIL2_PITCH")
CARD_CHEVRON_HALF_W, CARD_CHEVRON_HALF_H = num("CARD_CHEVRON_HALF_W"), num("CARD_CHEVRON_HALF_H")
CARD_SWATCH_H, CARD_SWATCH_GAP = num("CARD_SWATCH_H"), num("CARD_SWATCH_GAP")
CARD_TITLE_Y, CARD_BIG_Y, CARD_DETAIL_Y, CARD_ROW_Y, CARD_ROW_PITCH = (num("CARD_TITLE_Y"), num("CARD_BIG_Y"),
                                                                        num("CARD_DETAIL_Y"), num("CARD_ROW_Y"),
                                                                        num("CARD_ROW_PITCH"))
WINDOW_DATE_DX = num("WINDOW_DATE_DX")
TOUCH_R, TOUCH_ARC_ANGLE = num("TOUCH_R"), num("TOUCH_ARC_ANGLE")
TOUCH_RING_OUT, TOUCH_RING_IN = num("TOUCH_RING_OUT"), num("TOUCH_RING_IN")
DIM = {BLUE: BLUE_DIM, NAVY: NAVY_DIM, RED: RED_DIM}
# Theme.metricColor(): one colour per metric everywhere
METRIC = {"steps": BLUE, "active": NAVY, "body": RED}

# pixel sizes per Theme font role: the vector font sizes the watch face uses
FONT_PX = {"label": num("FONT_PX_LABEL"), "value": num("FONT_PX_VALUE"), "title": num("FONT_PX_TITLE")}

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
RING_OUT = TICK_INNER - RING_TICK_GAP - RING_W / 2.0    # ringOuterR()
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
    """Mirror of Cards.drawCard(): a quick card over the dial, with example values."""
    rows = kind == "activity"
    ch = CARD_H_ROWS if rows else (CARD_H_TWO if kind == "weather" else CARD_H)
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
    if kind == "date":                                   # touch the date card for the weather
        ax, ay = left + CARD_W - CARD_PAD, top + ch / 2
        s.line((ax - CARD_CHEVRON_HALF_W, ay - CARD_CHEVRON_HALF_H), (ax + CARD_CHEVRON_HALF_W, ay), GREY, 2)
        s.line((ax + CARD_CHEVRON_HALF_W, ay), (ax - CARD_CHEVRON_HALF_W, ay + CARD_CHEVRON_HALF_H), GREY, 2)
    if rows:
        for i, (n, v) in enumerate([("Steps", "6214 / 10000"), ("Active", "68 / 150 min"), ("Body battery", "78")]):
            y = top + CARD_ROW_Y + i * CARD_ROW_PITCH
            k = CARD_SWATCH_H / 99.0                          # Logo.stripePoints(0, ...): the M's first stripe
            sx0, sy0 = left + CARD_PAD, y - CARD_SWATCH_H / 2
            s.poly([(sx0 + 57 * k, sy0), (sx0 + 93 * k, sy0), (sx0 + 36 * k, sy0 + 99 * k), (sx0, sy0 + 99 * k)],
                   [BLUE, NAVY, RED][i])                      # each row wears its ring's colour
            s.text(sx0 + 93 * k + CARD_SWATCH_GAP, y, n, "label", GREY, "start")
            s.text(left + CARD_W - CARD_PAD, y, v, "value", WHITE, "end")
    else:
        s.text(CX, top + CARD_BIG_Y, big, "title", WHITE)
        s.text(CX, top + CARD_DETAIL_Y, detail, "label", GREY)
        if kind == "weather":
            s.text(CX, top + CARD_DETAIL_Y + CARD_DETAIL2_PITCH, "High 20&#176; &#183; Low 9&#176;", "label", GREY)


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
    draw_badge(s, CY - (R * .11 + 6 + 2.5 + TICK_INNER) / 2)    # Geometry.badgeCenterY(): midway between the roundel and the ticks
    arc = RING_OUT - PITCH                           # one arc: the middle ring's distance from the centre
    sx = CX + arc                                    # the date window at 3 o'clock
    hl, hv = FONT_PX["label"] * 1.2, FONT_PX["value"] * 1.2        # approximate line heights
    top = CY - (hl + hv) / 2
    s.text(sx + WINDOW_DATE_DX, top + hl / 2, "WED", "label", GREY)
    s.text(sx + WINDOW_DATE_DX, top + hl + hv / 2, "25", "value", WHITE)
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
        s.add('<circle cx="%.1f" cy="%.1f" r="%.1f" %s/>' % (CX + arc, CY, R * TOUCH_R, shape % (z[1], z[1])))
        s.add('<circle cx="%.1f" cy="%.1f" r="%.1f" %s/>' % (CX - arc, CY, R * TOUCH_R, shape % (z[2], z[2])))
        s.add('<circle cx="%.1f" cy="%.1f" r="%.1f" %s/>' % (CX, CY, R * TOUCH_R, shape % (z[3], z[3])))
        lo_a, hi_a = 270 - TOUCH_ARC_ANGLE, 270 + TOUCH_ARC_ANGLE
        band = ([pt(r_hi, a_) for a_ in range(lo_a, hi_a + 1, 3)]
                + [pt(r_lo, a_) for a_ in range(hi_a, lo_a - 1, -3)])
        s.add('<polygon points="%s" %s/>' % (pts(band), shape % (z[4], z[4])))
        s.add('</g>')                                   # end of the screen clip
        # The number badge always sits centred on the top edge of its target's outline.
        badge = lambda x, y, n: (s.circle(x, y, 12, z[n]), s.text(x, y, str(n), "label", BLACK))
        badge(CX + arc, CY - R * TOUCH_R, 1)                # date: top of its circle
        badge(CX - arc, CY - R * TOUCH_R, 2)                # battery: top of its circle
        badge(CX, CY - R * TOUCH_R, 3)                      # roundel: top of its circle
        badge(CX, CY + r_lo, 4)                         # rings: top (inner edge) of the wedge
    if card:
        draw_card(s, card)
    s.add("</g>")


def tap_zones():
    """The dial with its touch targets numbered, and a legend of the card each one shows."""
    s = Svg()
    lw = 600
    s.add('<rect x="-30" y="-30" width="%d" height="%d" fill="#1b1b1b"/>' % (W + 60 + lw, H + 60))
    dial_into(s, 0, 0, True)
    x0 = W + 40
    s.text(x0, 40, "Touch targets", "title", WHITE, "start")
    rows = [("1", ZONE_COLORS[1], "Date (3 o'clock)", "date card; touch it for the weather card"),
            ("2", ZONE_COLORS[2], "Battery (9 o'clock)", "battery card: percentage and days left"),
            ("3", ZONE_COLORS[3], "Roundel (centre)", "heart rate card: bpm, resting rate, stress"),
            ("4", ZONE_COLORS[4], "Rings (bottom)", "activity card: steps, active minutes, body battery")]
    for i, (n, c, name, what) in enumerate(rows):
        y = 90 + i * 70
        s.circle(x0 + 12, y, 12, c)
        s.text(x0 + 12, y, n, "label", BLACK)
        s.text(x0 + 36, y, name, "value", WHITE, "start")
        s.text(x0 + 36, y + 28, what, "label", GREY, "start")
    s.text(x0, 90 + 4 * 70 + 6, "Hold a zone for its card.", "label", GREY, "start")
    s.text(x0, 90 + 4 * 70 + 32, "Touch anywhere to dismiss it, or it goes after 4 seconds.", "label", GREY, "start")
    return s.doc((W + 60 + lw) * 1.6, (H + 60) * 1.6, "-30 -30 %d %d" % (W + 60 + lw, H + 60))


def dial(zones=False):
    s = Svg()
    s.add('<rect x="-30" y="-30" width="%d" height="%d" fill="#1b1b1b"/>' % (W + 60, H + 60))
    dial_into(s, 0, 0, zones)
    return s.doc((W + 60) * 2, (H + 60) * 2, "-30 -30 %d %d" % (W + 60, H + 60))


def cards():
    """The quick cards shown when a zone is pressed, over the dial."""
    s = Svg()
    kinds = ["battery", "date", "weather", "activity"]
    total = len(kinds) * W + (len(kinds) - 1) * 40
    s.add('<rect x="-20" y="-20" width="%d" height="%d" fill="#1b1b1b"/>' % (total + 40, H + 40))
    for i, k in enumerate(kinds):
        dial_into(s, i * (W + 40), 0, False, k)
    return s.doc(total + 40, H + 40, "-20 -20 %d %d" % (total + 40, H + 40))


# ---------------------------------------------------------------- rendering
OUTPUTS = {          # name -> (svg generator, png file name)
    "dial": (lambda: dial(), "wireframe.png"),
    "tap-zones": (lambda: tap_zones(), "tap-zones.png"),
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
