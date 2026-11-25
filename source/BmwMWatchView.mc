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
    private var _nav as PageNav = new PageNav();
    private var _card as Symbol or Null = null;       // the quick card showing, if any
    private var _cardTimer as Timer.Timer or Null = null;
    private var _detail as DetailPage or Null = null;
    private var _timer as Timer.Timer or Null = null;
    private var _w as Number = 0;
    private var _h as Number = 0;
    private var _r as Number = 0;

    function initialize() {
        WatchFace.initialize();
        _detail = new DetailPage(self);
        _timer = new Timer.Timer();
        _cardTimer = new Timer.Timer();
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

        if (_nav.isOpen() && !_asleep && _detail != null) {
            _detail.draw(dc, _nav.page, _nav.sub, _nav.from != null);
            return;
        }

        dc.setColor(Theme.WHITE, Theme.BLACK);
        dc.clear();

        drawBezel(dc, cx, cy, r);
        drawMMark(dc, cx, cy - r * 0.4, r);
        drawTemperature(dc, cx, Geometry.tempY(cy, r));
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        drawWindow(dc, cx + Geometry.middleRingR(r), cy, info.day_of_week.toString().toUpper(), info.day.toString());
        drawBatteryIcon(dc, cx - Geometry.middleRingR(r), cy);

        drawHands(dc, cx, cy, r);

        if (_card != null && !_asleep && _detail != null) {
            _detail.drawCard(dc, _card);      // a quick card over the dial
        }
    }

    // ---- dial -----------------------------------------------------------

    // ---- taps -------------------------------------------------------------

    // A tap goes deeper (see PageNav.tapOpens): on the dial it opens that zone's page, if it
    // has one, and while a page is open it moves between pages. A tap never shows a card. If a
    // card is up, any touch dismisses it first and the tap then does what it normally does, so
    // a tap behaves the same whether or not a card was showing. Returns true if it was used.
    function handleTap(x as Number, y as Number) as Boolean {
        var dismissed = false;
        if (_card != null) {
            closeCard();
            dismissed = true;
        }
        if (!_nav.isOpen()) {
            var hit = Geometry.hitTest(x, y, _w, _h, _r);
            if (hit == null || !PageNav.tapOpens(hit)) {
                return dismissed;       // the date and battery have no page: a tap does nothing
            }
            _nav.open(hit);
            restartTimer();
            WatchUi.requestUpdate();
            return true;
        }
        restartTimer();
        _nav.tap(x, y, _w);
        if (!_nav.isOpen()) {
            closePage();
        } else {
            WatchUi.requestUpdate();
        }
        return true;
    }

    // A hold peeks (see PageNav.holdShowsCard): a quick card for the element held, never a page.
    // Not used while a page is open.
    function handleHold(x as Number, y as Number) as Boolean {
        if (_nav.isOpen()) {
            return false;
        }
        var hit = Geometry.hitTest(x, y, _w, _h, _r);
        if (hit == null || !PageNav.holdShowsCard(hit)) {
            return false;
        }
        showCard(hit);
        return true;
    }

    private function showCard(kind as Symbol) as Void {
        _card = kind;
        if (_cardTimer != null) {
            _cardTimer.stop();
            _cardTimer.start(method(:closeCard), Theme.CARD_MS, false);
        }
        WatchUi.requestUpdate();
    }

    function closeCard() as Void {
        _card = null;
        if (_cardTimer != null) {
            _cardTimer.stop();
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
        _nav.close();
        _card = null;
        if (_cardTimer != null) {
            _cardTimer.stop();
        }
        if (_timer != null) {
            _timer.stop();
        }
        if (_detail != null) {
            _detail.reset();      // drop cached graph data
        }
        WatchUi.requestUpdate();
    }

    // Glyph used by the detail pages.
    function drawGlyph(dc as Dc, kind as Symbol, x as Numeric, y as Numeric, s as Numeric) as Void {
        if (kind == :hr) {
            drawHeart(dc, x, y, s, Theme.RED);
        } else if (kind == :steps) {
            drawWalker(dc, x, y, s, Theme.BLUE);
        } else if (kind == :active) {
            drawBolt(dc, x, y, s, Theme.WHITE);
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
        var w = Geometry.ringWidth(r);
        var pitch = w + Theme.GAP;
        var ringR = Geometry.ringOuterR(r);
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
            dc.setColor(major ? Theme.WHITE : Theme.GREY, Graphics.COLOR_TRANSPARENT);
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
        dc.setColor(Theme.dimOf(color), Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, R, Graphics.ARC_COUNTER_CLOCKWISE, 240, 300);
        if (frac > 1.0) { frac = 1.0; }
        if (frac > 0.01 && !_asleep) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, R, Graphics.ARC_COUNTER_CLOCKWISE, 240, 240 + 60 * frac);
        }
        dc.setPenWidth(1);
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
            dc.setColor(_asleep ? Theme.GREY : colors[i], Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(logoPoints(pts, left, top, k));
        }

        var m = [[132, 99], [189, 0], [227.5, 0], [227.5, 40], [252, 0], [290, 0], [290, 99],
                 [254.5, 99], [254.5, 58], [229.5, 99], [196.5, 99], [196.5, 58], [171.5, 99]];
        dc.setColor(_asleep ? Theme.GREY : Theme.WHITE, Graphics.COLOR_TRANSPARENT);
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
        dc.setColor(_asleep ? Theme.GREY : Theme.BLUE, Graphics.COLOR_TRANSPARENT);
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

    // The temperature alone above the badge; it is also the weather tap target.
    private function drawTemperature(dc as Dc, cx as Numeric, y as Numeric) as Void {
        dc.setColor(_asleep ? Theme.GREY : Theme.WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Theme.FONT_VALUE, weatherText(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // The watch battery as a simple icon that empties as the battery drains: a grey outline
    // and terminal, a white fill (red below 20%). The exact figure is on the quick card.
    private function drawBatteryIcon(dc as Dc, x as Numeric, y as Numeric) as Void {
        var pct = System.getSystemStats().battery;
        var left = x - Theme.BATT_W / 2;
        var top = y - Theme.BATT_H / 2;
        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(left, top, Theme.BATT_W, Theme.BATT_H, Theme.BATT_R);
        dc.setPenWidth(1);
        dc.fillRectangle(left + Theme.BATT_W, y - Theme.BATT_TERM_H / 2, Theme.BATT_TERM_W, Theme.BATT_TERM_H);
        var fillW = (Theme.BATT_W - 2 * Theme.BATT_PAD) * pct / 100.0;
        if (fillW > 0) {
            var low = Stats.isLowBattery(pct.toNumber());
            dc.setColor(_asleep ? Theme.GREY : (low ? Theme.RED : Theme.WHITE), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(left + Theme.BATT_PAD, top + Theme.BATT_PAD, fillW, Theme.BATT_H - 2 * Theme.BATT_PAD);
        }
    }

    // The date window at 3 o'clock: a small grey weekday over a white day number.
    private function drawWindow(dc as Dc, x as Numeric, y as Numeric, label as String, value as String) as Void {
        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + Theme.WINDOW_LABEL_DY, Theme.FONT_LABEL, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(_asleep ? Theme.GREY : Theme.WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + Theme.WINDOW_VALUE_DY, Theme.FONT_VALUE, value,
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
        dc.setColor(Theme.dimOf(color), Graphics.COLOR_TRANSPARENT);
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
        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
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
                var imperial = Units.tempImperial();
                return Units.temp(cond.temperature, imperial).toString() + Units.tempUnit(imperial);
            }
        }
        return "--°";
    }
}
