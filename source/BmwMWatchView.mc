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

// Analog chronograph watchface in BMW M Motorsport colours. All colours,
// spacing constants and font roles come from the Theme module.
class BmwMWatchView extends WatchUi.WatchFace {

    private var _asleep as Boolean = false;

    // tap detail pages
    private var _page as Symbol or Null = null;
    private var _sub as Number = 0;               // 0 = detail page, 1 = graph page
    private var _from as Symbol or Null = null;   // page to go back to (set when opened from Activity)
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
            _detail.draw(dc, _page, _sub, _from != null);
            return;
        }

        dc.setColor(Theme.WHITE, Theme.BLACK);
        dc.clear();

        drawBezel(dc, cx, cy, r);
        drawMMark(dc, cx, cy - r * 0.4, r);
        drawInfoRow(dc, cx, cy - r * 0.58);

        drawHands(dc, cx, cy, r);
    }

    // ---- dial -----------------------------------------------------------

    // ---- taps -------------------------------------------------------------

    // Returns true if the tap was used.
    //   Dial:        a tap on a zone opens that page (see hitTest).
    //   Open page:   top strip closes. On the Activity page a row opens that metric.
    //                On other pages the right side goes forward (detail -> graph)
    //                and the left side goes back (graph -> detail -> Activity/dial).
    function handleTap(x as Number, y as Number) as Boolean {
        if (_page == null) {
            var hit = hitTest(x, y);
            if (hit == null) {
                return false;
            }
            _page = hit;
            _sub = 0;
            _from = null;
            restartTimer();
            WatchUi.requestUpdate();
            return true;
        }

        restartTimer();
        if (y < Theme.CLOSE_Y) {
            closePage();
            return true;
        }

        if (_page == :activity) {
            var idx = (y - Theme.ACTIVITY_ROW_TOP) / Theme.ACTIVITY_ROW_PITCH;
            if (y >= Theme.ACTIVITY_ROW_TOP && idx < 3) {
                var kinds = [:steps, :active, :body];
                _page = kinds[idx];
                _from = :activity;
                _sub = 0;
            } else {
                closePage();
                return true;
            }
        } else if (x > _w * (1.0 - Theme.NAV_ZONE)) {
            if (_sub == 0) {
                _sub = 1;
            }
        } else if (x < _w * Theme.NAV_ZONE) {
            goBack();
            return true;
        }
        WatchUi.requestUpdate();
        return true;
    }

    private function goBack() as Void {
        if (_sub == 1) {
            _sub = 0;
        } else if (_from != null) {
            _page = _from;
            _from = null;
        } else {
            closePage();
            return;
        }
        WatchUi.requestUpdate();
    }

    private function restartTimer() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer.start(method(:closePage), 20000, false);   // auto-return after 20 s
        }
    }

    function closePage() as Void {
        _page = null;
        _sub = 0;
        _from = null;
        if (_timer != null) {
            _timer.stop();
        }
        if (_detail != null) {
            _detail.reset();      // drop cached graph data
        }
        WatchUi.requestUpdate();
    }

    // Which element was tapped. Three big, non-overlapping targets:
    //   top row -> weather, roundel area -> heart rate, ring band -> Activity page.
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
            if (ang < 42 && d <= ringR + 14 && d >= ringR - 2 * (ringWidth(r) + Theme.GAP) - 20) {
                return :activity;
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
            drawHeart(dc, x, y, s, Theme.RED);
        } else if (kind == :steps) {
            drawWalker(dc, x, y, s, Theme.BLUE);
        } else if (kind == :active) {
            drawBolt(dc, x, y, s, Theme.NAVY_LIGHT);
        } else if (kind == :body) {
            var bb = bodyBatFrac();
            drawBodyBattery(dc, x, y, s, Theme.RED, bb);
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
        var pitch = w + Theme.GAP;
        var ringR = ringOuterR(r);
        drawRing(dc, cx, cy, ringR,             w, stepsFrac(),   Theme.metricColor(:steps));
        drawRing(dc, cx, cy, ringR - pitch,     w, activeFrac(),  Theme.metricColor(:active));
        drawRing(dc, cx, cy, ringR - 2 * pitch, w, bodyBatFrac(), Theme.metricColor(:body));

        // minute / hour ticks
        for (var i = 0; i < 60; i++) {
            var a = rad(i * 6);
            var major = (i % 5 == 0);
            var outer = r - Theme.TICK_INSET;
            var inner = outer - (major ? r * Theme.TICK_MAJOR : r * Theme.TICK_MINOR);
            dc.setPenWidth(major ? 4 : 2);
            dc.setColor(major ? Theme.WHITE : Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
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
                              frac as Float, color as Number) as Void {
        dc.setPenWidth(pen);
        dc.setColor(_asleep ? Theme.GREY_DARK : Theme.dimOf(color), Graphics.COLOR_TRANSPARENT);
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
        return (r * 0.2 / 99.0 * 36 * 0.866 + 0.5).toNumber();   // rounded, not truncated
    }

    // Centre radius of the outer ring: 2 px inside the major ticks.
    private function ringOuterR(r as Number) as Float {
        var tickInner = (r - Theme.TICK_INSET) - r * Theme.TICK_MAJOR;
        return tickInner - Theme.GAP - ringWidth(r) / 2.0;
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
        var colors = [Theme.BLUE, Theme.NAVY, Theme.RED];
        for (var i = 0; i < 3; i++) {
            var xt = stripeX[i];
            var pts = [[xt, 0], [xt + 36, 0], [xt + 36 - 57, 99], [xt - 57, 99]];
            dc.setColor(_asleep ? Theme.GREY_MID : colors[i], Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(logoPoints(pts, left, top, k));
        }

        var m = [[132, 99], [189, 0], [227.5, 0], [227.5, 40], [252, 0], [290, 0], [290, 99],
                 [254.5, 99], [254.5, 58], [229.5, 99], [196.5, 99], [196.5, 58], [171.5, 99]];
        dc.setColor(_asleep ? Theme.GREY_LIGHT : Theme.WHITE, Graphics.COLOR_TRANSPARENT);
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
            dc.setColor(Theme.BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, R + 6, Graphics.ARC_COUNTER_CLOCKWISE, 100, 170);
            dc.setColor(Theme.NAVY, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, R + 6, Graphics.ARC_COUNTER_CLOCKWISE, 10, 80);
            dc.drawArc(cx, cy, R + 6, Graphics.ARC_COUNTER_CLOCKWISE, 280, 350);
            dc.setColor(Theme.RED, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, R + 6, Graphics.ARC_COUNTER_CLOCKWISE, 190, 260);
            dc.setPenWidth(1);
        }

        dc.setColor(Theme.BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, R);
        dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, ri);
        dc.setColor(_asleep ? Theme.GREY_MID : Theme.BLUE, Graphics.COLOR_TRANSPARENT);
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
        dc.setColor(Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Theme.FONT_LABEL, txt,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---- glyphs (drawn on the detail pages) ------------------------------

    private function drawHeart(dc as Dc, x as Numeric, y as Numeric, s as Numeric, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - s * 0.25, y - s * 0.15, s * 0.28);
        dc.fillCircle(x + s * 0.25, y - s * 0.15, s * 0.28);
        dc.fillPolygon([[x - s * 0.51, y - s * 0.02], [x + s * 0.51, y - s * 0.02], [x, y + s * 0.55]]);
    }

    // Walking figure facing right, in the same stroked style as the body battery
    // person: head, leaning torso, swinging arms, and two legs with a knee bend.
    private function drawWalker(dc as Dc, x as Numeric, y as Numeric, s as Numeric, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(Theme.glyphPen(s));
        dc.fillCircle(x + s * 0.06, y - s * 0.40, s * 0.11);
        dc.drawLine(x + s * 0.04, y - s * 0.24, x - s * 0.02, y + s * 0.08);          // torso
        dc.drawLine(x + s * 0.03, y - s * 0.18, x + s * 0.22, y - s * 0.02);          // front arm
        dc.drawLine(x + s * 0.03, y - s * 0.18, x - s * 0.15, y - s * 0.04);          // back arm
        dc.drawLine(x - s * 0.02, y + s * 0.08, x + s * 0.14, y + s * 0.26);          // front thigh
        dc.drawLine(x + s * 0.14, y + s * 0.26, x + s * 0.20, y + s * 0.50);          // front shin
        dc.drawLine(x - s * 0.02, y + s * 0.08, x - s * 0.16, y + s * 0.28);          // back thigh
        dc.drawLine(x - s * 0.16, y + s * 0.28, x - s * 0.30, y + s * 0.46);          // back shin
        dc.setPenWidth(1);
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
        dc.setPenWidth(Theme.glyphPen(s));
        dc.setColor(Theme.GREY_MID, Graphics.COLOR_TRANSPARENT);
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
        dc.setColor(_asleep ? Theme.GREY_MID : Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
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

        drawHand(dc, cx, cy, hourDeg, r * 0.56, r * 0.07, r * 0.1, Theme.WHITE, Theme.BLUE);
        drawHand(dc, cx, cy, minDeg, r * 0.88, r * 0.05, r * 0.12, Theme.WHITE, Theme.BLUE);

        if (!_asleep) {
            var a = rad(t.sec * 6.0);
            var tail = r * 0.18;
            var len = r * 0.94;
            dc.setPenWidth(3);
            dc.setColor(Theme.RED, Graphics.COLOR_TRANSPARENT);
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
        dc.setColor(_asleep ? Theme.BLACK : lume, Graphics.COLOR_TRANSPARENT);
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
