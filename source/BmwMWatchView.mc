import Toybox.ActivityMonitor;
import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Timer;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;
import Toybox.WatchUi;

// Analog chronograph watchface in BMW M Motorsport colours.
class BmwMWatchView extends WatchUi.WatchFace {

    // M Motorsport tricolour
    const M_LIGHT_BLUE = 0x0066B1;   // = logo blue
    const M_DARK_BLUE  = 0x003C78;   // = logo navy
    const M_RED        = 0xE32618;   // = logo red
    const TRACK_GREY   = 0x2A2A2A;
    // M badge colours (current flat logo: blue, navy, red + white M)
    const BADGE_BLUE   = 0x0066B1;
    const BADGE_NAVY   = 0x003C78;
    const BADGE_RED    = 0xE32618;
    const BADGE_M      = 0xFFFFFF;
    // dark tints for empty ring tracks
    const DIM_LIGHT_BLUE = 0x00203A;
    const DIM_DARK_BLUE  = 0x00101F;
    const DIM_RED        = 0x3A0C08;

    private var _asleep as Boolean = false;

    // tap detail pages
    private var _page as Symbol or Null = null;
    private var _detail as DetailPage or Null = null;
    private var _timer as Timer.Timer or Null = null;
    private var _w as Number = 0;
    private var _h as Number = 0;
    private var _r as Number = 0;

    function initialize() {
        WatchFace.initialize();
        _detail = new DetailPage(self);
        _timer = new Timer.Timer();
    }

    function onEnterSleep() as Void {
        _asleep = true;
        closePage();     // always return to the dial when the watch dims
    }

    function onExitSleep() as Void {
        _asleep = false;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var r = (w < h ? w : h) / 2 - 4;
        _w = w;
        _h = h;
        _r = r;

        if (_page != null && !_asleep && _detail != null) {
            _detail.draw(dc, _page);
            return;
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        drawBezel(dc, cx, cy, r);
        drawMMark(dc, cx, cy - r * 0.4, r);
        drawInfoRow(dc, cx, cy - r * 0.58);

        drawHands(dc, cx, cy, r);
    }

    // ---- dial -----------------------------------------------------------

    // ---- taps -------------------------------------------------------------

    // Returns true if the tap was used. Tapping a page again closes it.
    function handleTap(x as Number, y as Number) as Boolean {
        if (_page != null) {
            closePage();
            return true;
        }
        var hit = hitTest(x, y);
        if (hit == null) {
            return false;
        }
        _page = hit;
        if (_timer != null) {
            _timer.stop();
            _timer.start(method(:closePage), 20000, false);   // auto-return after 20 s
        }
        WatchUi.requestUpdate();
        return true;
    }

    function closePage() as Void {
        _page = null;
        if (_timer != null) {
            _timer.stop();
        }
        WatchUi.requestUpdate();
    }

    // Which element was tapped. Three big, non-overlapping targets:
    //   top row -> weather, roundel area -> heart rate, ring band -> activity.
    private function hitTest(x as Number, y as Number) as Symbol or Null {
        if (_w == 0) { return null; }
        var cx = _w / 2;
        var cy = _h / 2;
        var r = _r;

        // date / weather / battery row (checked first: it sits above the roundel zone)
        if ((y - (cy - r * 0.58)).abs() < 24 && (x - cx).abs() < 140) {
            return :weather;
        }

        // roundel: generous circle, stops well short of the rings
        if (near(x, y, cx, cy, r * 0.36)) {
            return :hr;
        }

        // ring band, with margin
        var dx = x - cx;
        var dy = y - cy;
        if (dy > 0) {
            var d = Math.sqrt(dx * dx + dy * dy);
            var ringR = ringOuterR(r);
            var ang = Math.atan2(dx.abs(), dy) * 180.0 / Math.PI;   // from straight down
            if (ang < 42 && d <= ringR + 14 && d >= ringR - 2 * (ringWidth(r) + 2) - 20) {
                return :rings;
            }
        }
        return null;
    }

    private function near(x as Numeric, y as Numeric, px as Numeric, py as Numeric, reach as Numeric) as Boolean {
        var ddx = x - px;
        var ddy = y - py;
        return Math.sqrt(ddx * ddx + ddy * ddy) < reach;
    }

    // Glyph used by the detail pages.
    function drawGlyph(dc as Dc, kind as Symbol, x as Numeric, y as Numeric, s as Numeric) as Void {
        if (kind == :hr) {
            drawHeart(dc, x, y, s, M_RED);
        } else if (kind == :steps) {
            drawShoe(dc, x, y, s, M_LIGHT_BLUE);
        } else if (kind == :active) {
            drawBolt(dc, x, y, s, 0x4A90D9);
        } else if (kind == :body) {
            var bb = bodyBatFrac();
            drawBodyBattery(dc, x, y, s, M_RED, bb);
        }
    }

    private function rad(deg as Numeric) as Float {
        return deg * Math.PI / 180.0;
    }

    // Three M-colour activity rings inside the lower half of the dial. Each ring is a dim
    // track in a dark tint of the colour that fills to the bright colour.
    //   outer light blue = steps, middle dark blue = active minutes,
    //   inner red        = body battery
    private function drawBezel(dc as Dc, cx as Numeric, cy as Numeric, r as Numeric) as Void {
        // Ring bars are as wide as the M badge stripes, with the same 2 px gap
        // between bars and between the outer ring and the major ticks.
        var w = ringWidth(r);
        var pitch = w + 2;
        var ringR = ringOuterR(r);
        drawRing(dc, cx, cy, ringR,             w, stepsFrac(),   M_LIGHT_BLUE, DIM_LIGHT_BLUE);
        drawRing(dc, cx, cy, ringR - pitch,     w, activeFrac(),  M_DARK_BLUE,  DIM_DARK_BLUE);
        drawRing(dc, cx, cy, ringR - 2 * pitch, w, bodyBatFrac(), M_RED,        DIM_RED);

        // minute / hour ticks
        for (var i = 0; i < 60; i++) {
            var a = rad(i * 6);
            var major = (i % 5 == 0);
            var outer = r - 8;
            var inner = outer - (major ? r * 0.09 : r * 0.035);
            dc.setPenWidth(major ? 4 : 2);
            dc.setColor(major ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(
                cx + Math.sin(a) * inner, cy - Math.cos(a) * inner,
                cx + Math.sin(a) * outer, cy - Math.cos(a) * outer);
        }
        dc.setPenWidth(1);
    }

    // The track is a 60 degree wedge centred on 6 o'clock. Its ends are straight
    // lines out from the roundel centre at 30 degrees either side of straight
    // down (240 and 300), the same lean as the M badge stripes, and they point at
    // the 7 and 5 o'clock ticks. The fill runs left to right from the 240 end.
    private function drawRing(dc as Dc, cx as Numeric, cy as Numeric, R as Numeric, pen as Number,
                              frac as Float, color as Number, dim as Number) as Void {
        dc.setPenWidth(pen);
        dc.setColor(_asleep ? TRACK_GREY : dim, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, R, Graphics.ARC_COUNTER_CLOCKWISE, 240, 300);
        if (frac > 1.0) { frac = 1.0; }
        if (frac > 0.01 && !_asleep) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, R, Graphics.ARC_COUNTER_CLOCKWISE, 240, 240 + 60 * frac);
        }
        dc.setPenWidth(1);
    }

    // Badge stripe width measured square-on: 36 of 99 logo units across a badge
    // 0.2 r tall, leaning 57 units over 99 (cos of that lean is about 0.87).
    private function ringWidth(r as Number) as Number {
        return (r * 0.2 / 99.0 * 36 * 0.866).toNumber();
    }

    // Centre radius of the outer ring: 2 px inside the major ticks.
    private function ringOuterR(r as Number) as Float {
        var tickInner = (r - 8) - r * 0.09;
        return tickInner - 2 - ringWidth(r) / 2.0;
    }

    // M badge, traced from the flat logo. Coordinates are in logo units:
    // the badge is 99 units tall and spans x = 9..290. Stripes and M share one
    // slant on the left; the M has a vertical right edge, a top valley with a
    // vertical left side, and two right-angled notches along the bottom.
    // Stripes are 36 wide with an even 5 unit gap, and the M's left edge runs
    // parallel to them, so every gap is the same top to bottom.
    // (Stylised redraw, not the registered logo artwork.)
    private function drawMMark(dc as Dc, cx as Numeric, cy as Numeric, r as Numeric) as Void {
        var mh = r * 0.2;                   // badge height in pixels
        var k = mh / 99.0;                  // pixels per logo unit
        var left = cx - (281 * k) / 2;      // logo is 281 units wide
        var top = cy - mh / 2;

        var stripeX = [66, 107, 148];       // top-left x of each stripe
        var colors = [BADGE_BLUE, BADGE_NAVY, BADGE_RED];
        for (var i = 0; i < 3; i++) {
            var xt = stripeX[i];
            var pts = [[xt, 0], [xt + 36, 0], [xt + 36 - 57, 99], [xt - 57, 99]];
            dc.setColor(_asleep ? Graphics.COLOR_DK_GRAY : colors[i], Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(logoPoints(pts, left, top, k));
        }

        var m = [[132, 99], [189, 0], [227.5, 0], [227.5, 40], [252, 0], [290, 0], [290, 99],
                 [254.5, 99], [254.5, 58], [229.5, 99], [196.5, 99], [196.5, 58], [171.5, 99]];
        dc.setColor(_asleep ? Graphics.COLOR_LT_GRAY : BADGE_M, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(logoPoints(m, left, top, k));
    }

    private function logoPoints(pts as Array<Array<Numeric> >, left as Numeric, top as Numeric,
                                k as Numeric) as Array<[Numeric, Numeric]> {
        var out = [] as Array<[Numeric, Numeric]>;
        for (var i = 0; i < pts.size(); i++) {
            out.add([left + (pts[i][0] - 9) * k, top + pts[i][1] * k]);
        }
        return out;
    }

    // Roundel at the hand pivot, ringed by the M-colour arcs of the 50 Years
    // emblem. Drawn over the hands' bases. (Stylised redraw.)
    private function drawRoundel(dc as Dc, cx as Numeric, cy as Numeric, r as Numeric) as Void {
        var R = r * 0.11;
        var ri = R * 0.72;

        if (!_asleep) {
            dc.setPenWidth(5);
            dc.setColor(M_LIGHT_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, R + 6, Graphics.ARC_COUNTER_CLOCKWISE, 100, 170);
            dc.setColor(M_DARK_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, R + 6, Graphics.ARC_COUNTER_CLOCKWISE, 10, 80);
            dc.drawArc(cx, cy, R + 6, Graphics.ARC_COUNTER_CLOCKWISE, 280, 350);
            dc.setColor(M_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, R + 6, Graphics.ARC_COUNTER_CLOCKWISE, 190, 260);
            dc.setPenWidth(1);
        }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, R);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, ri);
        dc.setColor(_asleep ? Graphics.COLOR_DK_GRAY : M_LIGHT_BLUE, Graphics.COLOR_TRANSPARENT);
        fillSector(dc, cx, cy, ri, 90, 180);
        fillSector(dc, cx, cy, ri, 270, 360);
    }

    private function fillSector(dc as Dc, cx as Numeric, cy as Numeric, rr as Numeric,
                                a0 as Numeric, a1 as Numeric) as Void {
        var pts = [[cx, cy]] as Array<[Numeric, Numeric]>;
        var steps = 8;
        for (var i = 0; i <= steps; i++) {
            var a = rad(a0 + (a1 - a0) * i / steps.toFloat());
            pts.add([cx + Math.cos(a) * rr, cy - Math.sin(a) * rr]);
        }
        dc.fillPolygon(pts);
    }

    // Date, weather and watch battery in one quiet line above the badge.
    private function drawInfoRow(dc as Dc, cx as Numeric, y as Numeric) as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var bat = System.getSystemStats().battery.toNumber();
        var txt = info.day_of_week.toString().toUpper() + " " + info.day.toString()
            + "  ·  " + weatherText() + "  ·  " + bat.toString() + "%";
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, txt,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---- glyphs (drawn on the detail pages) ------------------------------

    private function drawHeart(dc as Dc, x as Numeric, y as Numeric, s as Numeric, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - s * 0.25, y - s * 0.15, s * 0.28);
        dc.fillCircle(x + s * 0.25, y - s * 0.15, s * 0.28);
        dc.fillPolygon([[x - s * 0.51, y - s * 0.02], [x + s * 0.51, y - s * 0.02], [x, y + s * 0.55]]);
    }

    // Side-view running shoe, toe to the right: coloured upper over a light sole.
    private function drawShoe(dc as Dc, x as Numeric, y as Numeric, s as Numeric, color as Number) as Void {
        var k = s * 1.15;
        var cy = y + k * 0.035;     // centre the glyph vertically
        var upper = [[-0.60, 0.22], [-0.60, -0.10], [-0.50, -0.45], [-0.20, -0.45], [-0.12, -0.15],
                     [0.05, -0.12], [0.28, -0.02], [0.55, 0.08], [0.60, 0.22]];
        var sole = [[-0.62, 0.22], [0.62, 0.22], [0.62, 0.38], [-0.55, 0.38]];
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(localPoints(upper, x, cy, k));
        dc.setColor(_asleep ? Graphics.COLOR_DK_GRAY : 0xBBBBBB, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(localPoints(sole, x, cy, k));
    }

    private function localPoints(pts as Array<Array<Numeric> >, x as Numeric, y as Numeric,
                                 k as Numeric) as Array<[Numeric, Numeric]> {
        var out = [] as Array<[Numeric, Numeric]>;
        for (var i = 0; i < pts.size(); i++) {
            out.add([x + pts[i][0] * k, y + pts[i][1] * k]);
        }
        return out;
    }

    private function drawBolt(dc as Dc, x as Numeric, y as Numeric, s as Numeric, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [x + s * 0.15, y - s * 0.6], [x - s * 0.35, y + s * 0.05], [x - s * 0.02, y + s * 0.05],
            [x - s * 0.15, y + s * 0.6], [x + s * 0.35, y - s * 0.1], [x + s * 0.02, y - s * 0.1]
        ]);
    }

    // Body Battery: a person with raised arms inside a ring. The ring fills
    // clockwise from 12 o'clock to the current level, so it can't be mistaken
    // for the watch's own battery.
    private function drawBodyBattery(dc as Dc, x as Numeric, y as Numeric, s as Numeric,
                                     color as Number, frac as Float) as Void {
        var rr = s * 0.62;
        dc.setPenWidth(2);
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, rr);
        if (frac > 1.0) { frac = 1.0; }
        if (frac > 0.02) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            if (frac > 0.98) {
                dc.drawCircle(x, y, rr);
            } else {
                dc.drawArc(x, y, rr, Graphics.ARC_CLOCKWISE, 90, 90 - 360 * frac);
            }
        }
        // figure: head, torso, raised arms, legs
        dc.setColor(_asleep ? Graphics.COLOR_DK_GRAY : 0xBBBBBB, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y - s * 0.24, s * 0.1);
        dc.drawLine(x, y - s * 0.1, x, y + s * 0.15);
        dc.drawLine(x, y - s * 0.02, x - s * 0.22, y - s * 0.17);
        dc.drawLine(x, y - s * 0.02, x + s * 0.22, y - s * 0.17);
        dc.drawLine(x, y + s * 0.15, x - s * 0.14, y + s * 0.36);
        dc.drawLine(x, y + s * 0.15, x + s * 0.14, y + s * 0.36);
        dc.setPenWidth(1);
    }

    // ---- hands ----------------------------------------------------------

    private function drawHands(dc as Dc, cx as Numeric, cy as Numeric, r as Numeric) as Void {
        var t = System.getClockTime();
        var hourDeg = ((t.hour % 12) + t.min / 60.0) * 30.0;
        var minDeg = (t.min + t.sec / 60.0) * 6.0;

        drawHand(dc, cx, cy, hourDeg, r * 0.56, r * 0.07, r * 0.1, Graphics.COLOR_WHITE, M_LIGHT_BLUE);
        drawHand(dc, cx, cy, minDeg, r * 0.88, r * 0.05, r * 0.12, Graphics.COLOR_WHITE, M_LIGHT_BLUE);

        if (!_asleep) {
            var a = rad(t.sec * 6.0);
            var tail = r * 0.18;
            var len = r * 0.94;
            dc.setPenWidth(3);
            dc.setColor(M_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(
                cx - Math.sin(a) * tail, cy + Math.cos(a) * tail,
                cx + Math.sin(a) * len, cy - Math.cos(a) * len);
            dc.setPenWidth(1);
        }

        drawRoundel(dc, cx, cy, r);
    }

    // Sword-style hand with a lume stripe, rotated by deg clockwise from 12.
    private function drawHand(dc as Dc, cx as Numeric, cy as Numeric, deg as Float,
                              len as Numeric, wid as Numeric, tail as Numeric,
                              body as Number, lume as Number) as Void {
        var a = rad(deg);
        dc.setColor(body, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(handPoints(cx, cy, a, len, wid / 2, tail));
        dc.setColor(_asleep ? Graphics.COLOR_BLACK : lume, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(handPoints(cx, cy, a, len * 0.92, wid / 5, -len * 0.18));
    }

    private function handPoints(cx as Numeric, cy as Numeric, a as Float, len as Numeric,
                                hw as Numeric, tail as Numeric) as Array<[Numeric, Numeric]> {
        var local = [[-hw, -tail], [-hw * 0.6, len], [hw * 0.6, len], [hw, -tail]];
        var out = [] as Array<[Numeric, Numeric]>;
        var s = Math.sin(a);
        var c = Math.cos(a);
        for (var i = 0; i < local.size(); i++) {
            var lx = local[i][0];
            var ly = local[i][1];
            out.add([cx + lx * c + ly * s, cy + lx * s - ly * c]);
        }
        return out;
    }

    // ---- data -----------------------------------------------------------

    private function stepsFrac() as Float {
        var info = ActivityMonitor.getInfo();
        if (info.steps == null || info.stepGoal == null || info.stepGoal == 0) { return 0.0; }
        return info.steps.toFloat() / info.stepGoal;
    }

    private function activeFrac() as Float {
        var info = ActivityMonitor.getInfo();
        if (info.activeMinutesWeek == null || info.activeMinutesWeekGoal == null
            || info.activeMinutesWeekGoal == 0) { return 0.0; }
        return info.activeMinutesWeek.total.toFloat() / info.activeMinutesWeekGoal;
    }

    private function bodyBattery() as Number or Null {
        if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
            var it = SensorHistory.getBodyBatteryHistory({ :period => 1 });
            var sample = (it != null) ? it.next() : null;
            if (sample != null && sample.data != null) {
                return sample.data.toNumber();
            }
        }
        return null;
    }

    private function bodyBatFrac() as Float {
        var bb = bodyBattery();
        return bb == null ? 0.0 : bb / 100.0;
    }

    private function weatherText() as String {
        if (Toybox has :Weather) {
            var cond = Weather.getCurrentConditions();
            if (cond != null && cond.temperature != null) {
                var temp = cond.temperature;   // Celsius
                var unit = "C";
                if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
                    temp = temp * 9.0 / 5.0 + 32.0;
                    unit = "F";
                }
                return temp.toNumber().toString() + "°" + unit;
            }
        }
        return "--°";
    }
}
