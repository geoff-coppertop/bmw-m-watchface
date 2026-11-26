#!/usr/bin/env python3
"""Write resources/drawables/launcher_icon.png: the face badge's three stripes and the M on black.

    python3 tools/launcher_icon.py [size]     # default 65, the Venu X1's launcher icon size

Colours come from source/Theme.mc and the geometry matches source/Logo.mc and the badge on the dial.
Needs Pillow (pip install pillow).
"""
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
size = int(sys.argv[1]) if len(sys.argv) > 1 else 65

theme = (ROOT / "source" / "Theme.mc").read_text()
consts = dict(re.findall(r"const (\w+)\s*=\s*(0x[0-9A-Fa-f]+)\s*;", theme))
col = lambda n: "#%06X" % int(consts[n], 0)

S = 8                                           # supersample, then shrink for smooth edges
img = Image.new("RGB", (size * S, size * S), col("BLACK"))
d = ImageDraw.Draw(img)
k = (size - 8) / 281 * S                        # the badge spans 281 logo units; leave a 4 px margin
left, top = 4 * S, (size * S - 99 * k) / 2
P = lambda pts: [(left + (x - 9) * k, top + y * k) for x, y in pts]
for xt, c in ((66, "BLUE"), (107, "NAVY"), (148, "RED")):
    d.polygon(P([(xt, 0), (xt + 36, 0), (xt + 36 - 57, 99), (xt - 57, 99)]), fill=col(c))
M = [(132, 99), (189, 0), (227.5, 0), (227.5, 40), (252, 0), (290, 0), (290, 99),
     (254.5, 99), (254.5, 58), (229.5, 99), (196.5, 99), (196.5, 58), (171.5, 99)]
d.polygon(P(M), fill=col("WHITE"))
out = ROOT / "resources" / "drawables" / "launcher_icon.png"
img.resize((size, size), Image.LANCZOS).save(out)
print("wrote", out, "(%dx%d)" % (size, size))
