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

    // Which element a tap on the dial hit. Three big, non-overlapping targets:
    //   top row -> :weather, roundel area -> :hr, ring band -> :activity.
    function hitTest(x as Number, y as Number, w as Number, h as Number, r as Number) as Symbol or Null {
        if (w == 0) { return null; }
        var cx = w / 2;
        var cy = h / 2;

        // date / weather / battery row (checked first: it sits above the roundel zone)
        if ((y - (cy - r * 0.58)).abs() < 24 && (x - cx).abs() < 140) {
            return :weather;
        }

        // roundel: a generous circle that stops well short of the rings
        var dx = x - cx;
        var dy = y - cy;
        if (Math.sqrt(dx * dx + dy * dy) < r * 0.36) {
            return :hr;
        }

        // ring band, with margin
        if (dy > 0) {
            var d = Math.sqrt(dx * dx + dy * dy);
            var ringR = ringOuterR(r);
            var ang = Math.atan2(dx.abs(), dy) * 180.0 / Math.PI;   // from straight down
            if (ang < 42 && d <= ringR + 14 && d >= ringR - 2 * (ringWidth(r) + Theme.GAP) - 20) {
                return :activity;
            }
        }
        return null;
    }
}
