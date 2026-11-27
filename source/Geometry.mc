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

    // Where the major ticks start (their inner end), measured from the dial centre.
    function tickInnerR(r as Number) as Float {
        return (r - Theme.TICK_INSET) - r * Theme.TICK_MAJOR;
    }

    // Centre radius of the outer ring: Theme.RING_TICK_GAP inside the major ticks.
    function ringOuterR(r as Number) as Float {
        return tickInnerR(r) - Theme.RING_TICK_GAP - ringWidth(r) / 2.0;
    }

    // The outer edge of the roundel at the hand pivot: its radius, the gap to its coloured arcs,
    // and half the arcs' 5 px pen.
    function roundelOuterR(r as Number) as Float {
        return r * 0.11 + 6 + 2.5;
    }

    // Where the M badge's centre sits: halfway between the roundel's outer edge and the major
    // tick at 12 o'clock, so the badge has the same margin above and below it.
    function badgeCenterY(cy as Number, r as Number) as Float {
        return cy - (roundelOuterR(r) + tickInnerR(r)) / 2.0;
    }

    // Centre radius of the middle ring (the navy active minutes gauge).
    function middleRingR(r as Number) as Float {
        return ringOuterR(r) - (ringWidth(r) + Theme.GAP);
    }

    // Which element a touch on the dial hit. Non-overlapping targets:
    //   date window -> :date, battery icon -> :battery, roundel area -> :hr, ring arc -> :activity.
    // (The weather is not a zone of its own: the view shows the weather card for :date.)
    function hitTest(x as Number, y as Number, w as Number, h as Number, r as Number) as Symbol or Null {
        if (w == 0) { return null; }
        var cx = w / 2;
        var cy = h / 2;

        var dx = x - cx;
        var dy = y - cy;
        var dist = Math.sqrt(dx * dx + dy * dy);

        // the date window (3 o'clock) and the battery icon (9 o'clock): circles the same size as
        // the roundel's, on the middle ring's arc. They run off the edge of the screen, which is
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

    function near(x as Number, y as Number, px as Numeric, py as Numeric, reach as Numeric) as Boolean {
        var dx = x - px;
        var dy = y - py;
        return Math.sqrt(dx * dx + dy * dy) < reach;
    }
}
