import Toybox.Lang;
import Toybox.Math;

// Dial geometry shared by drawing and tap detection, kept free of drawing calls so
// it can be unit tested (source/tests/GeometryTests.mc).
module Geometry {

    function dialRadius(w as Number, h as Number) as Number {
        return (w < h ? w : h) / 2 - 4;
    }

    // Ring bar width: the M badge stripe width measured square-on (36 of 99 logo
    // units across a badge 0.2 r tall, leaning 57 over 99), rounded not truncated.
    function ringWidth(r as Number) as Number {
        return (r * 0.2 / 99.0 * 36 * 0.866 + 0.5).toNumber();
    }

    // Centre radius of the outer ring: Theme.GAP inside the major ticks.
    function ringOuterR(r as Number) as Float {
        var tickInner = (r - Theme.TICK_INSET) - r * Theme.TICK_MAJOR;
        return tickInner - Theme.GAP - ringWidth(r) / 2.0;
    }

    // Centre radius of the middle ring (the navy active minutes gauge).
    function middleRingR(r as Number) as Float {
        return ringOuterR(r) - (ringWidth(r) + Theme.GAP);
    }

    // Where the temperature sits at 12 o'clock: the same distance from the dial centre as
    // the middle ring is at 6 o'clock, mirrored, which also keeps it clear of the badge.
    function tempY(cy as Number, r as Number) as Float {
        return cy - middleRingR(r);
    }

    // Which element a tap or hold on the dial hit. Non-overlapping targets:
    //   temperature arc -> :weather, date window -> :date, battery icon -> :battery,
    //   roundel area -> :hr, ring arc -> :activity.
    function hitTest(x as Number, y as Number, w as Number, h as Number, r as Number) as Symbol or Null {
        if (w == 0) { return null; }
        var cx = w / 2;
        var cy = h / 2;

        var dx = x - cx;
        var dy = y - cy;
        var dist = Math.sqrt(dx * dx + dy * dy);

        // the temperature at 12 o'clock: an arc along its own radius, the mirror of the rings'
        // arc at 6 o'clock
        if (dy < 0 && (dist - middleRingR(r)).abs() < Theme.TOUCH_TEMP_HALF_R
            && Math.atan2(dx.abs(), -dy) * 180.0 / Math.PI < Theme.TOUCH_ARC_ANGLE) {
            return :weather;
        }

        // the date window (3 o'clock) and the battery icon (9 o'clock): circles the same size as
        // the roundel's, on the temperature's arc. They run off the edge of the screen, which is
        // fine: only the part on the screen can be touched.
        var zoneR = r * Theme.TOUCH_R;               // the roundel, date and battery targets share one radius
        var side = middleRingR(r);
        if (near(x, y, cx + side, cy, zoneR)) { return :date; }
        if (near(x, y, cx - side, cy, zoneR)) { return :battery; }

        // roundel: a generous circle that stops well short of the rings
        if (dist < zoneR) {
            return :hr;
        }

        // ring band, with margin
        if (dy > 0) {
            var ringR = ringOuterR(r);
            var ang = Math.atan2(dx.abs(), dy) * 180.0 / Math.PI;   // from straight down
            if (ang < Theme.TOUCH_ARC_ANGLE && dist <= ringR + Theme.TOUCH_RING_OUT
                && dist >= ringR - 2 * (ringWidth(r) + Theme.GAP) - Theme.TOUCH_RING_IN) {
                return :activity;
            }
        }
        return null;
    }

    private function near(x as Number, y as Number, px as Numeric, py as Numeric, reach as Numeric) as Boolean {
        var dx = x - px;
        var dy = y - py;
        return Math.sqrt(dx * dx + dy * dy) < reach;
    }
}
