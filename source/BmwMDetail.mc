import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;
import Toybox.Weather;

// Full-screen detail pages shown when a ring, a corner glyph or the top row
// is tapped. Drawn by the watch face itself in place of the dial.
class DetailPage {

    private var _face as BmwMWatchView;

    // Graph data is read once per page and cached, because the face redraws every
    // second and the history iterators are slow.
    private var _gKind as Symbol or Null = null;
    private var _gVals as Array<Numeric or Null> = [] as Array<Numeric or Null>;
    private var _gXl as Array<String> = [] as Array<String>;
    private var _gGoal as Numeric or Null = null;
    private var _gTitle as String = "";
    private var _gStats as String = "";
    private var _gColor as Number = Theme.WHITE;
    private var _gBars as Boolean = false;

    function initialize(face as BmwMWatchView) {
        _face = face;
    }

    function reset() as Void {
        _gKind = null;
    }

    // kind: :activity, :steps, :active, :body, :hr, :weather.
    // sub: 0 = the detail page, 1 = the graph page behind it.
    function draw(dc as Dc, kind as Symbol, sub as Number, fromActivity as Boolean) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Theme.WHITE, Theme.BLACK);
        dc.clear();
        drawStripes(dc, cx, Theme.Y_STRIPES);

        if (kind == :activity) {
            drawActivity(dc, w, h);
            return;
        }
        if (sub == 1) {
            drawGraph(dc, w, h, kind);
        } else if (kind == :weather) {
            drawWeather(dc, w, h);
        } else {
            drawMetric(dc, w, h, kind);
        }
        drawNav(dc, w, h, sub, fromActivity);
    }

    // ---- metric detail page (steps, active minutes, body battery, heart rate) ----

    private function drawMetric(dc as Dc, w as Number, h as Number, kind as Symbol) as Void {
        var cx = w / 2;

        var title = "";
        var big = "--";
        var sub = "";
        var frac = -1.0;
        var barColor = Theme.WHITE;
        var labels = [] as Array<String>;
        var values = [] as Array<String>;

        if (kind == :hr) {
            title = "HEART RATE";
            sub = "bpm";
            var act = Activity.getActivityInfo();
            if (act != null && act.currentHeartRate != null) {
                big = act.currentHeartRate.toString();
            }
            var rest = null;
            var prof = UserProfile.getProfile();
            if (prof != null && prof.restingHeartRate != null) {
                rest = prof.restingHeartRate;
            }
            var lo = null;
            var hi = null;
            var it = ActivityMonitor.getHeartRateHistory(new Time.Duration(Gregorian.SECONDS_PER_DAY), false);
            if (it != null) {
                lo = validHr(it.getMin());
                hi = validHr(it.getMax());
            }
            labels = ["Resting", "Today low", "Today high"];
            values = [numStr(rest, " bpm"), numStr(lo, " bpm"), numStr(hi, " bpm")];

        } else if (kind == :steps) {
            title = "STEPS";
            barColor = Theme.BLUE;
            var info = ActivityMonitor.getInfo();
            if (info.steps != null) {
                big = info.steps.toString();
            }
            if (info.steps != null && info.stepGoal != null && info.stepGoal > 0) {
                frac = info.steps.toFloat() / info.stepGoal;
                sub = "of " + info.stepGoal.toString() + " goal";
            }
            var dist = "--";
            if (info.distance != null) {
                if (System.getDeviceSettings().distanceUnits == System.UNIT_METRIC) {
                    dist = (info.distance / 100000.0).format("%.1f") + " km";
                } else {
                    dist = (info.distance / 160934.0).format("%.1f") + " mi";
                }
            }
            var floors = "--";
            if (info.floorsClimbed != null && info.floorsClimbedGoal != null) {
                floors = info.floorsClimbed.toString() + " / " + info.floorsClimbedGoal.toString();
            }
            labels = ["Distance", "Calories", "Floors"];
            values = [dist, numStr(info.calories, " kcal"), floors];

        } else if (kind == :active) {
            title = "ACTIVE MINUTES";
            barColor = Theme.NAVY;
            var info = ActivityMonitor.getInfo();
            var wk = info.activeMinutesWeek;
            var day = info.activeMinutesDay;
            var goal = info.activeMinutesWeekGoal;
            if (wk != null) {
                big = wk.total.toString();
                if (goal != null && goal > 0) {
                    frac = wk.total.toFloat() / goal;
                    sub = "min this week, goal " + goal.toString();
                }
            }
            labels = ["Today", "Moderate (week)", "Vigorous (week)"];
            values = [day == null ? "--" : day.total.toString() + " min",
                      wk == null ? "--" : wk.moderate.toString() + " min",
                      wk == null ? "--" : wk.vigorous.toString() + " min"];

        } else {
            title = "BODY BATTERY";
            var bb = null;
            var lo = null;
            var hi = null;
            if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
                var it = SensorHistory.getBodyBatteryHistory({ :period => new Time.Duration(Gregorian.SECONDS_PER_DAY) });
                if (it != null) {
                    var smp = it.next();
                    if (smp != null && smp.data != null) {
                        bb = smp.data.toNumber();
                    }
                    lo = it.getMin();
                    hi = it.getMax();
                }
            }
            if (bb != null) {
                big = bb.toString();
                frac = bb / 100.0;
                barColor = Theme.RED;
                if (bb >= 76) { sub = "High energy"; }
                else if (bb >= 51) { sub = "Good"; }
                else if (bb >= 26) { sub = "Moderate"; }
                else { sub = "Low"; }
            }
            labels = ["24 h low", "24 h high"];
            values = [lo == null ? "--" : lo.toNumber().toString(),
                      hi == null ? "--" : hi.toNumber().toString()];
        }

        _face.drawGlyph(dc, kind, cx, Theme.Y_GLYPH, Theme.GLYPH_BIG);

        dc.setColor(Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.Y_TITLE_UNDER_GLYPH, Theme.FONT_TITLE, title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.Y_HERO, Theme.FONT_HERO, big,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.Y_SUB, Theme.FONT_LABEL, sub,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (frac >= 0.0) {
            drawBar(dc, cx, Theme.Y_BAR, frac, barColor);
        }
        for (var i = 0; i < labels.size(); i++) {
            drawRow(dc, w, Theme.Y_ROWS + i * Theme.ROW_PITCH, labels[i], values[i]);
        }
    }

    // ---- Activity page (tap the ring zone on the dial) ---------------------
    // Each row opens that metric's page; the chevrons show that they are tappable.

    private function drawActivity(dc as Dc, w as Number, h as Number) as Void {
        var cx = w / 2;
        dc.setColor(Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.Y_TITLE, Theme.FONT_TITLE, "ACTIVITY",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var info = ActivityMonitor.getInfo();

        var stepsTxt = "--";
        var stepsFrac = 0.0;
        if (info.steps != null) {
            stepsTxt = info.steps.toString();
            if (info.stepGoal != null && info.stepGoal > 0) {
                stepsTxt = stepsTxt + " / " + info.stepGoal.toString();
                stepsFrac = info.steps.toFloat() / info.stepGoal;
            }
        }

        var actTxt = "--";
        var actFrac = 0.0;
        var wk = info.activeMinutesWeek;
        if (wk != null) {
            actTxt = wk.total.toString();
            if (info.activeMinutesWeekGoal != null && info.activeMinutesWeekGoal > 0) {
                actTxt = actTxt + " / " + info.activeMinutesWeekGoal.toString() + " min";
                actFrac = wk.total.toFloat() / info.activeMinutesWeekGoal;
            }
        }

        var bb = null;
        if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
            var it = SensorHistory.getBodyBatteryHistory({ :period => 1 });
            var smp = (it != null) ? it.next() : null;
            if (smp != null && smp.data != null) {
                bb = smp.data.toNumber();
            }
        }
        var bbTxt = (bb == null) ? "--" : bb.toString() + " / 100";
        var bbFrac = (bb == null) ? 0.0 : bb / 100.0;

        var kinds = [:steps, :active, :body];
        var names = ["Steps", "Active minutes (week)", "Body battery"];
        var vals = [stepsTxt, actTxt, bbTxt];
        var fracs = [stepsFrac, actFrac, bbFrac];
        var colors = [Theme.BLUE, Theme.NAVY, Theme.RED];

        for (var i = 0; i < 3; i++) {
            var y = Theme.ACTIVITY_ROW_TOP + 50 + i * Theme.ACTIVITY_ROW_PITCH;
            _face.drawGlyph(dc, kinds[i], Theme.MARGIN + 14, y, 24);
            dc.setColor(Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.MARGIN + 46, y - 14, Theme.FONT_LABEL, names[i],
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.MARGIN + 46, y + 10, Theme.FONT_VALUE, vals[i],
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            drawBar(dc, cx, y + 40, fracs[i], colors[i]);
            chevron(dc, w - 36, y + 8, true);
        }
    }

    // ---- weather ---------------------------------------------------------

    private function drawWeather(dc as Dc, w as Number, h as Number) as Void {
        var cx = w / 2;
        var cond = null;
        if (Toybox has :Weather) {
            cond = Weather.getCurrentConditions();
        }

        dc.setColor(Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.Y_TITLE, Theme.FONT_TITLE, "WEATHER",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (cond == null || cond.temperature == null) {
            dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2, Theme.FONT_TITLE, "No weather data",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2 + 34, Theme.FONT_LABEL, "Sync with Garmin Connect",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // big temperature, unit drawn small to its right
        var big = tempNum(cond.temperature).toString();
        var bw = dc.getTextWidthInPixels(big, Theme.FONT_HERO);
        dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 142, Theme.FONT_HERO, big,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + bw / 2 + 8, 120, Theme.FONT_TITLE, tempUnit(),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 204, Theme.FONT_TITLE, conditionText(cond.condition),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (cond.feelsLikeTemperature != null) {
            dc.setColor(Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 234, Theme.FONT_LABEL,
                "Feels like " + tempNum(cond.feelsLikeTemperature).toString() + "°",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        var hl = "--";
        if (cond.highTemperature != null && cond.lowTemperature != null) {
            hl = tempNum(cond.highTemperature).toString() + "° / " + tempNum(cond.lowTemperature).toString() + "°";
        }
        drawRow(dc, w, Theme.Y_WEATHER_ROWS, "High / low", hl);
        drawRow(dc, w, Theme.Y_WEATHER_ROWS + Theme.ROW_PITCH, "Rain chance", numStr(cond.precipitationChance, "%"));
        drawRow(dc, w, Theme.Y_WEATHER_ROWS + 2 * Theme.ROW_PITCH, "Wind", windText(cond));
        drawRow(dc, w, Theme.Y_WEATHER_ROWS + 3 * Theme.ROW_PITCH, "Humidity", numStr(cond.relativeHumidity, "%"));

        // next few hours
        var fc = Weather.getHourlyForecast();
        if (fc != null) {
            for (var i = 0; i < 4 && i < fc.size(); i++) {
                var x = w * (0.2 + 0.2 * i);
                dc.setColor(Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
                dc.drawText(x, 410, Theme.FONT_LABEL, hourLabel(fc[i].forecastTime),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                if (fc[i].temperature != null) {
                    dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(x, 438, Theme.FONT_VALUE, tempNum(fc[i].temperature).toString() + "°",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                }
            }
        }
    }

    private function conditionText(c as Number or Null) as String {
        if (c == null) { return ""; }
        if (c == Weather.CONDITION_CLEAR || c == Weather.CONDITION_FAIR) { return "Clear"; }
        if (c == Weather.CONDITION_PARTLY_CLOUDY) { return "Partly cloudy"; }
        if (c == Weather.CONDITION_MOSTLY_CLOUDY) { return "Mostly cloudy"; }
        if (c == Weather.CONDITION_CLOUDY) { return "Cloudy"; }
        if (c == Weather.CONDITION_LIGHT_RAIN || c == Weather.CONDITION_DRIZZLE) { return "Light rain"; }
        if (c == Weather.CONDITION_RAIN) { return "Rain"; }
        if (c == Weather.CONDITION_HEAVY_RAIN) { return "Heavy rain"; }
        if (c == Weather.CONDITION_SHOWERS || c == Weather.CONDITION_SCATTERED_SHOWERS) { return "Showers"; }
        if (c == Weather.CONDITION_LIGHT_SNOW) { return "Light snow"; }
        if (c == Weather.CONDITION_SNOW) { return "Snow"; }
        if (c == Weather.CONDITION_HEAVY_SNOW) { return "Heavy snow"; }
        if (c == Weather.CONDITION_THUNDERSTORMS) { return "Thunderstorms"; }
        if (c == Weather.CONDITION_FOG || c == Weather.CONDITION_MIST) { return "Fog"; }
        if (c == Weather.CONDITION_HAZY) { return "Hazy"; }
        if (c == Weather.CONDITION_WINDY) { return "Windy"; }
        return "";
    }

    private function windText(cond as Weather.CurrentConditions) as String {
        if (cond.windSpeed == null) { return "--"; }
        var metric = System.getDeviceSettings().distanceUnits == System.UNIT_METRIC;
        var spd = metric ? cond.windSpeed * 3.6 : cond.windSpeed * 2.23694;
        var txt = spd.toNumber().toString() + (metric ? " km/h" : " mph");
        if (cond.windBearing != null) {
            var dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
            txt = txt + " " + dirs[((cond.windBearing + 22.5) / 45).toNumber() % 8];
        }
        return txt;
    }

    private function tempNum(c as Numeric) as Number {
        if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
            return (c * 9.0 / 5.0 + 32.0).toNumber();
        }
        return c.toNumber();
    }

    private function tempUnit() as String {
        return (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) ? "°F" : "°C";
    }

    private function hourLabel(t as Time.Moment) as String {
        var hr = Gregorian.info(t, Time.FORMAT_SHORT).hour;
        if (System.getDeviceSettings().is24Hour) {
            return hr.format("%02d") + ":00";
        }
        var h12 = hr % 12;
        if (h12 == 0) { h12 = 12; }
        return h12.toString() + (hr >= 12 ? "p" : "a");
    }

    // ---- graph pages (the second page behind each detail page) -------------

    private function drawGraph(dc as Dc, w as Number, h as Number, kind as Symbol) as Void {
        var cx = w / 2;
        if (_gKind != kind) {
            loadGraph(kind);
            _gKind = kind;
        }

        dc.setColor(Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.Y_TITLE, Theme.FONT_TITLE, _gTitle,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (_gBars) {
            drawBarChart(dc, w);
        } else {
            drawLineChart(dc, w);
            var x1 = w - Theme.CHART_X;
            var xs = [Theme.CHART_X, cx, x1];
            var js = [Graphics.TEXT_JUSTIFY_LEFT, Graphics.TEXT_JUSTIFY_CENTER, Graphics.TEXT_JUSTIFY_RIGHT];
            dc.setColor(Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < _gXl.size() && i < 3; i++) {
                dc.drawText(xs[i], Theme.Y_XLABELS, Theme.FONT_LABEL, _gXl[i], js[i] | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        dc.setColor(Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.Y_STATS, Theme.FONT_LABEL, _gStats,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Reads the data for one graph into the cache fields.
    private function loadGraph(kind as Symbol) as Void {
        var vals = [] as Array<Numeric or Null>;
        _gGoal = null;
        _gBars = false;
        _gXl = [] as Array<String>;
        _gStats = "";

        if (kind == :steps || kind == :active) {
            _gBars = true;
            var hist = ActivityMonitor.getHistory();
            var info = ActivityMonitor.getInfo();
            var n = (hist == null) ? 0 : hist.size();
            if (n > 6) { n = 6; }
            // history is newest first; the chart wants oldest first, with today last
            for (var i = n - 1; i >= 0; i--) {
                if (kind == :steps) {
                    vals.add(hist[i].steps);
                    if (_gGoal == null) { _gGoal = hist[i].stepGoal; }
                } else {
                    var am = (hist[i] has :activeMinutes) ? hist[i].activeMinutes : null;
                    vals.add(am == null ? null : am.total);
                }
            }
            if (kind == :steps) {
                _gTitle = "STEPS · 7 DAYS";
                _gColor = Theme.BLUE;
                vals.add(info.steps);
                if (info.stepGoal != null) { _gGoal = info.stepGoal; }
            } else {
                _gTitle = "ACTIVE MIN · 7 DAYS";
                _gColor = Theme.NAVY;
                vals.add(info.activeMinutesDay == null ? null : info.activeMinutesDay.total);
                if (info.activeMinutesWeekGoal != null) { _gGoal = info.activeMinutesWeekGoal / 7; }
            }
            _gXl = dayLabels(vals.size());
            _gStats = "Avg " + fmt(avgOf(vals)) + "   Best " + fmt(maxOf(vals))
                + (_gGoal == null ? "" : (kind == :steps ? "   Goal " : "   Daily target ") + _gGoal.toString());

        } else if (kind == :body) {
            _gTitle = "BODY BATTERY · 24 H";
            _gColor = Theme.RED;
            vals = bucketSeries(86400, true);
            _gXl = ["24h ago", "12h", "now"];
            _gStats = "Low " + fmt(minOf(vals)) + "   High " + fmt(maxOf(vals));

        } else if (kind == :hr) {
            _gTitle = "HEART RATE · 4 H";
            _gColor = Theme.RED;
            vals = bucketSeries(14400, false);
            _gXl = ["4h ago", "2h", "now"];
            _gStats = "Min " + fmt(minOf(vals)) + "   Max " + fmt(maxOf(vals));

        } else {
            _gTitle = "TEMPERATURE · 12 H";
            _gColor = Theme.WHITE;
            var fc = null;
            if (Toybox has :Weather) { fc = Weather.getHourlyForecast(); }
            var n = (fc == null) ? 0 : fc.size();
            if (n > 12) { n = 12; }
            for (var i = 0; i < n; i++) {
                vals.add(fc[i].temperature == null ? null : tempNum(fc[i].temperature));
            }
            if (n > 0) {
                _gXl = [hourLabel(fc[0].forecastTime), hourLabel(fc[n / 2].forecastTime), hourLabel(fc[n - 1].forecastTime)];
            }
            _gStats = "Low " + fmt(minOf(vals)) + "°   High " + fmt(maxOf(vals)) + "°";
        }
        _gVals = vals;
    }

    // Reads the last span seconds of body battery (or heart rate) into 48 time buckets.
    private function bucketSeries(span as Number, bodyBattery as Boolean) as Array<Numeric or Null> {
        var buckets = 48;
        var out = new [buckets] as Array<Numeric or Null>;
        var t0 = Time.now().value() - span;
        var step = span / buckets;
        var it = null;
        if (bodyBattery) {
            if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
                it = SensorHistory.getBodyBatteryHistory({ :period => new Time.Duration(span) });
            }
        } else {
            it = ActivityMonitor.getHeartRateHistory(new Time.Duration(span), false);
        }
        if (it == null) { return out; }
        var smp = it.next();
        while (smp != null) {
            var v = bodyBattery ? smp.data : smp.heartRate;
            if (v != null && smp.when != null && (bodyBattery || v != ActivityMonitor.INVALID_HR_SAMPLE)) {
                var idx = (smp.when.value() - t0) / step;
                if (idx >= 0 && idx < buckets) { out[idx] = v.toNumber(); }
            }
            smp = it.next();
        }
        return out;
    }

    private function drawBarChart(dc as Dc, w as Number) as Void {
        var n = _gVals.size();
        var top = Theme.CHART_TOP;
        var bot = Theme.CHART_BOTTOM;
        var bw = Theme.BAR_COLS_W;
        var gap = Theme.BAR_COLS_GAP;
        var x0 = w / 2 - (n * bw + (n - 1) * gap) / 2;

        var maxV = (_gGoal == null) ? 0 : _gGoal;
        for (var i = 0; i < n; i++) {
            if (_gVals[i] != null && _gVals[i] > maxV) { maxV = _gVals[i]; }
        }
        if (maxV <= 0) { maxV = 1; }

        for (var i = 0; i < n; i++) {
            var x = x0 + i * (bw + gap);
            var v = _gVals[i];
            if (v != null) {
                var hgt = v.toFloat() * (bot - top) / maxV;
                dc.setColor(_gColor, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, bot - hgt, bw, hgt);
            }
            dc.setColor(i == n - 1 ? Theme.WHITE : Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
            if (i < _gXl.size()) {
                dc.drawText(x + bw / 2, Theme.Y_XLABELS, Theme.FONT_LABEL, _gXl[i],
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        dc.setPenWidth(2);
        dc.setColor(Theme.GREY_DARK, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x0, bot, x0 + n * bw + (n - 1) * gap, bot);
        if (_gGoal != null) {
            var gy = bot - _gGoal.toFloat() * (bot - top) / maxV;     // dashed goal line
            dc.setColor(Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
            for (var gx = x0; gx < x0 + n * bw + (n - 1) * gap; gx += 12) {
                dc.drawLine(gx, gy, gx + 7, gy);
            }
        }
        dc.setPenWidth(1);
    }

    private function drawLineChart(dc as Dc, w as Number) as Void {
        var n = _gVals.size();
        var x0 = Theme.CHART_X;
        var x1 = w - Theme.CHART_X;
        var top = Theme.CHART_TOP;
        var bot = Theme.CHART_BOTTOM;

        var lo = minOf(_gVals);
        var hi = maxOf(_gVals);
        dc.setPenWidth(2);
        dc.setColor(Theme.GREY_DARK, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x0, bot, x1, bot);
        dc.drawLine(x0, top, x1, top);
        dc.setPenWidth(1);
        if (n < 2 || lo == null || hi == null) {
            dc.setColor(Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, (top + bot) / 2, Theme.FONT_VALUE, "No data",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        if (hi == lo) { hi = lo + 1; }

        // axis values on the right
        dc.setColor(Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x1 + 6, top, Theme.FONT_LABEL, hi.toString(), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x1 + 6, bot, Theme.FONT_LABEL, lo.toString(), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setPenWidth(3);
        dc.setColor(_gColor, Graphics.COLOR_TRANSPARENT);
        var px = null;
        var py = null;
        for (var i = 0; i < n; i++) {
            var v = _gVals[i];
            if (v == null) {
                px = null;
                continue;
            }
            var x = x0 + (x1 - x0) * i / (n - 1);
            var y = bot - (v - lo).toFloat() * (bot - top) / (hi - lo);
            if (px != null) { dc.drawLine(px, py, x, y); }
            px = x;
            py = y;
        }
        if (px != null) { dc.fillCircle(px, py, 4); }      // marks the latest value
        dc.setPenWidth(1);
    }

    // Single-letter weekday labels for the last n days, today last.
    private function dayLabels(n as Number) as Array<String> {
        var initials = ["S", "M", "T", "W", "T", "F", "S"];
        var out = [] as Array<String>;
        for (var i = 0; i < n; i++) {
            var m = Time.now().subtract(new Time.Duration((n - 1 - i) * 86400));
            out.add(initials[Gregorian.info(m, Time.FORMAT_SHORT).day_of_week - 1]);
        }
        return out;
    }

    private function fmt(v as Numeric or Null) as String {
        return v == null ? "--" : v.toString();
    }

    private function minOf(vals as Array<Numeric or Null>) as Numeric or Null {
        var r = null;
        for (var i = 0; i < vals.size(); i++) {
            if (vals[i] != null && (r == null || vals[i] < r)) { r = vals[i]; }
        }
        return r;
    }

    private function maxOf(vals as Array<Numeric or Null>) as Numeric or Null {
        var r = null;
        for (var i = 0; i < vals.size(); i++) {
            if (vals[i] != null && (r == null || vals[i] > r)) { r = vals[i]; }
        }
        return r;
    }

    private function avgOf(vals as Array<Numeric or Null>) as Numeric {
        var sum = 0;
        var cnt = 0;
        for (var i = 0; i < vals.size(); i++) {
            if (vals[i] != null) { sum += vals[i]; cnt++; }
        }
        return cnt == 0 ? 0 : (sum / cnt).toNumber();
    }

    // ---- navigation affordances ------------------------------------------

    // Chevrons at the edges and page dots at the bottom. The right chevron means
    // "graph"; the left one means "back".
    private function drawNav(dc as Dc, w as Number, h as Number, sub as Number, fromActivity as Boolean) as Void {
        if (sub == 0) {
            chevron(dc, w - 24, h / 2, true);
        }
        if (sub == 1 || fromActivity) {
            chevron(dc, 24, h / 2, false);
        }
        var cx = w / 2;
        for (var i = 0; i < 2; i++) {
            dc.setColor(i == sub ? Theme.WHITE : Theme.GREY_MID, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - 10 + i * 20, Theme.Y_DOTS, Theme.DOT_R);
        }
    }

    private function chevron(dc as Dc, x as Numeric, y as Numeric, right as Boolean) as Void {
        var d = right ? -6 : 6;
        dc.setPenWidth(3);
        dc.setColor(Theme.GREY_MID, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x + d, y - 12, x - d, y);
        dc.drawLine(x - d, y, x + d, y + 12);
        dc.setPenWidth(1);
    }

    // ---- shared bits -----------------------------------------------------

    // Three small slanted M stripes as an accent at the top of every page.
    private function drawStripes(dc as Dc, cx as Numeric, y as Numeric) as Void {
        var colors = [Theme.BLUE, Theme.NAVY, Theme.RED];
        for (var i = 0; i < 3; i++) {
            var x = cx - 40 + i * 28;
            dc.setColor(colors[i], Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[x + 8, y - 7], [x + 28, y - 7], [x + 20, y + 7], [x, y + 7]]);
        }
    }

    private function drawBar(dc as Dc, cx as Numeric, y as Numeric, frac as Float, color as Number) as Void {
        var bw = Theme.BAR_W;
        var bh = Theme.BAR_H;
        if (frac > 1.0) { frac = 1.0; }
        // empty track = dark tint of the bar colour, same as the rings on the dial
        var track = Theme.dimOf(color);
        dc.setColor(track, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - bw / 2, y - bh / 2, bw, bh, Theme.BAR_R);
        if (frac > 0.01) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw / 2, y - bh / 2, bw * frac, bh, Theme.BAR_R);
        }
    }

    private function drawRow(dc as Dc, w as Number, y as Numeric, label as String, value as String) as Void {
        dc.setColor(Theme.GREY_LIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Theme.MARGIN, y, Theme.FONT_LABEL, label,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - Theme.MARGIN, y, Theme.FONT_VALUE, value,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function validHr(v as Number or Null) as Number or Null {
        if (v == null || v == ActivityMonitor.INVALID_HR_SAMPLE) { return null; }
        return v;
    }

    private function numStr(v as Numeric or Null, suffix as String) as String {
        return v == null ? "--" : v.toNumber().toString() + suffix;
    }
}
