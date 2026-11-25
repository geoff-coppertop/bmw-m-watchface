import Toybox.Activity;
import Toybox.Complications;
import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
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
    private var _gTenths as Boolean = false;      // values are tenths of a degree: label with one decimal
    // Sleep band on the body battery and heart rate graphs, as bucket indices
    // (null when there is none) plus a caption saying where it came from.
    private var _gSleepA as Number or Null = null;
    private var _gSleepB as Number or Null = null;     // exclusive
    private var _gCaption as String = "";
    // Weather graph overlays, one value per hour: chance of precipitation and cloud cover (percent)
    private var _gRain as Array<Numeric or Null> = [] as Array<Numeric or Null>;
    private var _gCloud as Array<Numeric or Null> = [] as Array<Numeric or Null>;
    private var _gFrozen as Array<Boolean> = [] as Array<Boolean>;     // that hour's precipitation is snow or ice

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
        if (sub >= 1) {
            drawGraph(dc, w, h, graphKind(kind, sub));
        } else if (kind == :weather) {
            drawWeather(dc, w, h);
        } else {
            drawMetric(dc, w, h, kind);
        }
        drawNav(dc, w, h, sub, fromActivity, PageNav.subCount(kind));
    }

    // Body Battery has more pages than the others: sub 1 is its own graph, 2 stress, 3 temperature.
    private function graphKind(kind as Symbol, sub as Number) as Symbol {
        if (kind != :body) { return kind; }
        return sub == 2 ? :stress : (sub == 3 ? :temp : :body);
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
            barColor = Theme.metricColor(kind);
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
                dist = Units.distanceText(info.distance, Units.distImperial());
            }
            var floors = "--";
            if (info.floorsClimbed != null && info.floorsClimbedGoal != null) {
                floors = info.floorsClimbed.toString() + " / " + info.floorsClimbedGoal.toString();
            }
            labels = ["Distance", "Calories", "Floors"];
            values = [dist, numStr(info.calories, " kcal"), floors];

        } else if (kind == :active) {
            title = "ACTIVE MINUTES";
            barColor = Theme.metricColor(kind);
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
                barColor = Theme.metricColor(kind);
                if (bb >= 76) { sub = "High energy"; }
                else if (bb >= 51) { sub = "Good"; }
                else if (bb >= 26) { sub = "Moderate"; }
                else { sub = "Low"; }
            }
            var st = ActivityMonitor.getInfo().stressScore;
            var stText = (st == null) ? "--" : st.toString() + " · " + Stats.stressBand(st);
            var ss = sleepScore();
            labels = ["24 h low / high", "Stress", "Sleep score"];
            values = [(lo == null || hi == null) ? "--" : lo.toNumber().toString() + " / " + hi.toNumber().toString(),
                      stText, ss == null ? "--" : ss.toString()];
        }

        _face.drawGlyph(dc, kind, cx, Theme.Y_GLYPH, Theme.GLYPH_BIG);

        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.Y_TITLE_UNDER_GLYPH, Theme.FONT_TITLE, title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.Y_HERO, Theme.FONT_HERO, big,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.Y_SUB, Theme.FONT_LABEL, sub,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (frac >= 0.0) {
            drawBar(dc, cx, Theme.Y_BAR, frac, barColor);
        }
        for (var i = 0; i < labels.size(); i++) {
            drawRow(dc, w, Theme.Y_ROWS + i * Theme.ROW_PITCH, labels[i], values[i]);
        }
    }

    // Complications.COMPLICATION_TYPE_SLEEP_SCORE: the SDK documents it as id 42, API 6.0.2.
    // A number rather than the constant so the file still builds if the SDK's API level
    // is older; null means not available (older firmware, no score yet, or no permission).
    const COMPLICATION_SLEEP_SCORE = 42;

    private function sleepScore() as Number or Null {
        if (!(Toybox has :Complications)) { return null; }
        try {
            var comp = Complications.getComplication(new Complications.Id(COMPLICATION_SLEEP_SCORE));
            if (comp != null && comp.value != null && comp.value instanceof Number) {
                return comp.value;
            }
        } catch (e) {
            // ComplicationNotFoundException: this watch does not provide it
        }
        return null;
    }

    // ---- quick cards (touch and hold on the dial) ------------------------------
    // A small card over the dial with a little more detail than the face shows. It is
    // not a page: it disappears by itself after a few seconds, or on the next tap.

    function drawCard(dc as Dc, kind as Symbol) as Void {
        var w = dc.getWidth();
        var cx = w / 2;
        var rows = (kind == :activity);
        var ch = rows ? Theme.CARD_H_ROWS : Theme.CARD_H;
        var left = cx - Theme.CARD_W / 2;
        var top = dc.getHeight() / 2 - ch / 2;

        dc.setColor(Theme.BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(left, top, Theme.CARD_W, ch, Theme.CARD_R);
        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(left, top, Theme.CARD_W, ch, Theme.CARD_R);
        dc.setPenWidth(1);

        var title = "";
        var big = "--";
        var detail = "";
        var j = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        if (kind == :battery) {
            var st = System.getSystemStats();
            title = "WATCH BATTERY";
            big = st.battery.toNumber().toString() + "%";
            detail = Stats.daysText(st.batteryInDays) + " left" + (st.charging ? " · Charging" : "");

        } else if (kind == :date) {
            var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
            title = "TODAY";
            big = info.day_of_week.toString();
            detail = info.day.toString() + " " + info.month.toString() + " " + info.year.toString();

        } else if (kind == :weather) {
            title = "WEATHER";
            var cond = (Toybox has :Weather) ? Weather.getCurrentConditions() : null;
            if (cond != null && cond.temperature != null) {
                big = tempNum(cond.temperature).toString() + tempUnit();
                detail = conditionText(cond.condition);
                if (cond.feelsLikeTemperature != null) {
                    detail += (detail.length() > 0 ? " · " : "") + "feels " + tempNum(cond.feelsLikeTemperature).toString() + "°";
                }
            } else {
                detail = "No weather data";
            }

        } else if (kind == :hr) {
            title = "HEART RATE";
            var act = Activity.getActivityInfo();
            if (act != null && act.currentHeartRate != null) { big = act.currentHeartRate.toString() + " bpm"; }
            var prof = UserProfile.getProfile();
            var st2 = ActivityMonitor.getInfo().stressScore;
            detail = "Resting " + ((prof != null && prof.restingHeartRate != null) ? prof.restingHeartRate.toString() : "--")
                + " · Stress " + (st2 == null ? "--" : st2.toString());

        } else {
            // :activity, the rings: three rows
            title = "ACTIVITY";
            var info2 = ActivityMonitor.getInfo();
            var stepsTxt = (info2.steps == null) ? "--" : info2.steps.toString()
                + ((info2.stepGoal != null) ? " / " + info2.stepGoal.toString() : "");
            var wk = info2.activeMinutesWeek;
            var actTxt = (wk == null) ? "--" : wk.total.toString()
                + ((info2.activeMinutesWeekGoal != null) ? " / " + info2.activeMinutesWeekGoal.toString() : "") + " min";
            var bb = bodyBatteryNow();
            var names = ["Steps", "Active (week)", "Body battery"];
            var vals = [stepsTxt, actTxt, bb == null ? "--" : bb.toString()];
            for (var i = 0; i < 3; i++) {
                var y = top + Theme.CARD_ROW_Y + i * Theme.CARD_ROW_PITCH;
                dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(left + Theme.CARD_PAD, y, Theme.FONT_LABEL, names[i],
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(left + Theme.CARD_W - Theme.CARD_PAD, y, Theme.FONT_VALUE, vals[i],
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top + Theme.CARD_TITLE_Y, Theme.FONT_LABEL, title, j);
        if (!rows) {
            dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, top + Theme.CARD_BIG_Y, Theme.FONT_TITLE, big, j);
            dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, top + Theme.CARD_DETAIL_Y, Theme.FONT_LABEL, detail, j);
        }
    }

    private function bodyBatteryNow() as Number or Null {
        if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
            var it = SensorHistory.getBodyBatteryHistory({ :period => 1 });
            var smp = (it != null) ? it.next() : null;
            if (smp != null && smp.data != null) { return smp.data.toNumber(); }
        }
        return null;
    }

    // ---- Activity page (tap the ring zone on the dial) ---------------------
    // Each row opens that metric's page; the chevrons show that they are tappable.

    private function drawActivity(dc as Dc, w as Number, h as Number) as Void {
        var cx = w / 2;
        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
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
        var colors = [Theme.metricColor(:steps), Theme.metricColor(:active), Theme.metricColor(:body)];

        for (var i = 0; i < 3; i++) {
            var y = Theme.ACTIVITY_ROW_TOP + 50 + i * Theme.ACTIVITY_ROW_PITCH;
            _face.drawGlyph(dc, kinds[i], Theme.MARGIN + Theme.ACT_GLYPH_DX, y, Theme.ACT_GLYPH);
            dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.MARGIN + Theme.ACT_TEXT_DX, y + Theme.ACT_LABEL_DY, Theme.FONT_LABEL, names[i],
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(Theme.MARGIN + Theme.ACT_TEXT_DX, y + Theme.ACT_VALUE_DY, Theme.FONT_VALUE, vals[i],
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            drawBar(dc, cx, y + Theme.ACT_BAR_DY, fracs[i], colors[i]);
            chevron(dc, w - Theme.ACT_CHEVRON_X, y + Theme.ACT_CHEVRON_DY, true);
        }
    }

    // ---- weather ---------------------------------------------------------

    private function drawWeather(dc as Dc, w as Number, h as Number) as Void {
        var cx = w / 2;
        var cond = null;
        if (Toybox has :Weather) {
            cond = Weather.getCurrentConditions();
        }

        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.Y_TITLE, Theme.FONT_TITLE, "WEATHER",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (cond == null || cond.temperature == null) {
            dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2, Theme.FONT_TITLE, "No weather data",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2 + Theme.WEATHER_NODATA_DY, Theme.FONT_LABEL, "Sync with Garmin Connect",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // big temperature, unit drawn small to its right
        var big = tempNum(cond.temperature).toString();
        var bw = dc.getTextWidthInPixels(big, Theme.FONT_HERO);
        dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.WEATHER_Y_HERO, Theme.FONT_HERO, big,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + bw / 2 + Theme.WEATHER_UNIT_DX, Theme.WEATHER_Y_UNIT, Theme.FONT_TITLE, tempUnit(),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.WEATHER_Y_COND, Theme.FONT_TITLE, conditionText(cond.condition),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (cond.feelsLikeTemperature != null) {
            dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, Theme.WEATHER_Y_FEELS, Theme.FONT_LABEL,
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
                dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(x, Theme.Y_ROWS + Theme.ROW_PITCH, Theme.FONT_LABEL, hourLabel(fc[i].forecastTime),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                if (fc[i].temperature != null) {
                    dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(x, Theme.Y_ROWS + 2 * Theme.ROW_PITCH, Theme.FONT_VALUE, tempNum(fc[i].temperature).toString() + "°",
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
        if (c == Weather.CONDITION_FLURRIES) { return "Flurries"; }
        if (c == Weather.CONDITION_SLEET) { return "Sleet"; }
        if (c == Weather.CONDITION_WINTRY_MIX || c == Weather.CONDITION_RAIN_SNOW) { return "Wintry mix"; }
        if (c == Weather.CONDITION_FREEZING_RAIN) { return "Freezing rain"; }
        if (c == Weather.CONDITION_HAIL) { return "Hail"; }
        if (c == Weather.CONDITION_MOSTLY_CLEAR) { return "Mostly clear"; }
        return "";
    }

    private function windText(cond as Weather.CurrentConditions) as String {
        if (cond.windSpeed == null) { return "--"; }
        var imperial = Units.distImperial();
        var txt = Units.windSpeed(cond.windSpeed, imperial).toString() + " " + Units.windUnit(imperial);
        if (cond.windBearing != null) {
            var dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
            txt = txt + " " + dirs[((cond.windBearing + 22.5) / 45).toNumber() % 8];
        }
        return txt;
    }

    private function tempNum(c as Numeric) as Number {
        return Units.temp(c, Units.tempImperial());
    }

    private function tempUnit() as String {
        return Units.tempUnit(Units.tempImperial());
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

        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.Y_TITLE, Theme.FONT_TITLE, _gTitle,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (_gCaption.length() > 0) {
            dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, Theme.Y_CAPTION, Theme.FONT_LABEL, _gCaption,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        if (_gBars) {
            drawBarChart(dc, w);
        } else {
            drawLineChart(dc, w);
            var x1 = w - Theme.CHART_X;
            var xs = [Theme.CHART_X, cx, x1];
            var js = [Graphics.TEXT_JUSTIFY_LEFT, Graphics.TEXT_JUSTIFY_CENTER, Graphics.TEXT_JUSTIFY_RIGHT];
            dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < _gXl.size() && i < 3; i++) {
                dc.drawText(xs[i], Theme.Y_XLABELS, Theme.FONT_LABEL, _gXl[i], js[i] | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.Y_STATS, Theme.FONT_LABEL, _gStats,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Reads the data for one graph into the cache fields.
    private function loadGraph(kind as Symbol) as Void {
        var vals = [] as Array<Numeric or Null>;
        _gGoal = null;
        _gBars = false;
        _gTenths = false;
        _gXl = [] as Array<String>;
        _gStats = "";
        _gSleepA = null;
        _gSleepB = null;
        _gCaption = "";
        _gRain = [] as Array<Numeric or Null>;
        _gCloud = [] as Array<Numeric or Null>;
        _gFrozen = [] as Array<Boolean>;

        if (kind == :steps || kind == :active) {
            _gBars = true;
            var hist = ActivityMonitor.getHistory();
            var info = ActivityMonitor.getInfo();
            // getHistory() is newest first, at most 7 entries. Today is taken from
            // getInfo(), so skip a history entry that starts today.
            var days = [] as Array<ActivityMonitor.History>;
            var todayStart = Time.today().value();
            for (var i = 0; hist != null && i < hist.size(); i++) {
                var sod = hist[i].startOfDay;
                if (sod != null && sod.value() >= todayStart) { continue; }
                days.add(hist[i]);
            }
            var n = days.size();
            if (n > 6) { n = 6; }
            // the chart wants oldest first, with today last
            for (var i = n - 1; i >= 0; i--) {
                if (kind == :steps) {
                    vals.add(days[i].steps);
                    if (_gGoal == null) { _gGoal = days[i].stepGoal; }
                } else {
                    var am = days[i].activeMinutes;
                    vals.add(am == null ? null : am.total);
                }
            }
            if (kind == :steps) {
                _gTitle = "STEPS · 7 DAYS";
                _gColor = Theme.metricColor(kind);
                vals.add(info.steps);
                if (info.stepGoal != null) { _gGoal = info.stepGoal; }
            } else {
                _gTitle = "ACTIVE MIN · 7 DAYS";
                _gColor = Theme.metricColor(kind);
                vals.add(info.activeMinutesDay == null ? null : info.activeMinutesDay.total);
                if (info.activeMinutesWeekGoal != null) { _gGoal = info.activeMinutesWeekGoal / 7; }
            }
            _gXl = dayLabels(vals.size());
            _gStats = "Avg " + Stats.fmt(Stats.avgOf(vals)) + "   Best " + Stats.fmt(Stats.maxOf(vals))
                + (_gGoal == null ? "" : (kind == :steps ? "   Goal " : "   Daily target ") + _gGoal.toString());

        } else if (kind == :body) {
            _gTitle = "BODY BATTERY · 24 H";
            _gColor = Theme.metricColor(kind);
            vals = bucketSeries(86400, :body);
            findSleep(bucketSeries(86400, :hr), vals);
            _gXl = ["24h ago", "12h", "now"];
            _gStats = "Low " + Stats.fmt(Stats.minOf(vals)) + "   High " + Stats.fmt(Stats.maxOf(vals));

        } else if (kind == :stress) {
            _gTitle = "STRESS · 24 H";
            _gColor = Theme.metricColor(kind);
            vals = bucketSeries(86400, :stress);
            findSleep(bucketSeries(86400, :hr), bucketSeries(86400, :body));
            _gXl = ["24h ago", "12h", "now"];
            _gStats = "Avg " + Stats.fmt(Stats.avgOf(vals)) + "   Max " + Stats.fmt(Stats.maxOf(vals));

        } else if (kind == :temp) {
            // The temperature sensor behind SensorHistory.getTemperatureHistory. The docs
            // only call it "temperature"; whether it is skin temperature on the Venu X1
            // is unconfirmed, hence the neutral title.
            _gTitle = "SENSOR TEMP · 24 H";
            _gColor = Theme.metricColor(kind);
            _gTenths = true;
            vals = bucketSeries(86400, :temp);
            findSleep(bucketSeries(86400, :hr), bucketSeries(86400, :body));
            _gXl = ["24h ago", "12h", "now"];
            _gStats = "Low " + tenthsOrDash(Stats.minOf(vals)) + "°   High " + tenthsOrDash(Stats.maxOf(vals)) + "°";

        } else if (kind == :hr) {
            _gTitle = "HEART RATE · 24 H";
            _gColor = Theme.metricColor(kind);
            vals = bucketSeries(86400, :hr);
            findSleep(vals, bucketSeries(86400, :body));
            _gXl = ["24h ago", "12h", "now"];
            _gStats = "Min " + Stats.fmt(Stats.minOf(vals)) + "   Max " + Stats.fmt(Stats.maxOf(vals));

        } else {
            _gTitle = "TEMPERATURE · 12 H";
            _gColor = Theme.metricColor(kind);
            var fc = null;
            if (Toybox has :Weather) { fc = Weather.getHourlyForecast(); }
            var n = (fc == null) ? 0 : fc.size();
            if (n > 12) { n = 12; }
            for (var i = 0; i < n; i++) {
                vals.add(fc[i].temperature == null ? null : tempNum(fc[i].temperature));
                _gRain.add(fc[i].precipitationChance);
                _gCloud.add(fc[i].cloudCover);
                _gFrozen.add(Precip.isFrozen(fc[i].condition));
            }
            if (n > 1) { _gCaption = "Bars: precipitation · Strip: cloud cover"; }
            if (n > 0) {
                _gXl = [hourLabel(fc[0].forecastTime), hourLabel(fc[n / 2].forecastTime), hourLabel(fc[n - 1].forecastTime)];
            }
            _gStats = "Low " + Stats.fmt(Stats.minOf(vals)) + "°   High " + Stats.fmt(Stats.maxOf(vals)) + "°";
        }
        _gVals = vals;
    }

    // Reads the last span seconds of body battery, heart rate, stress or sensor temperature
    // (which is :body, :hr, :stress or :temp) into 48 time buckets, averaging the samples in
    // each. All three come from SensorHistory. The docs say heart rate and temperature
    // history only go back to the last power cycle, so a freshly restarted watch will
    // show gaps at the left. Temperature is held in tenths of a degree, in the
    // watch's own unit (Celsius or Fahrenheit).
    private function bucketSeries(span as Number, which as Symbol) as Array<Numeric or Null> {
        var buckets = 48;
        var out = new [buckets] as Array<Numeric or Null>;
        if (!(Toybox has :SensorHistory)) { return out; }

        var it = null;
        var opts = { :period => new Time.Duration(span), :order => SensorHistory.ORDER_OLDEST_FIRST };
        if (which == :body) {
            if (SensorHistory has :getBodyBatteryHistory) { it = SensorHistory.getBodyBatteryHistory(opts); }
        } else if (which == :stress) {
            if (SensorHistory has :getStressHistory) { it = SensorHistory.getStressHistory(opts); }
        } else if (which == :temp) {
            if (SensorHistory has :getTemperatureHistory) { it = SensorHistory.getTemperatureHistory(opts); }
        } else {
            if (SensorHistory has :getHeartRateHistory) { it = SensorHistory.getHeartRateHistory(opts); }
        }
        if (it == null) { return out; }

        var sums = new [buckets] as Array<Number>;
        var cnts = new [buckets] as Array<Number>;
        for (var i = 0; i < buckets; i++) {
            sums[i] = 0;
            cnts[i] = 0;
        }
        var t0 = Time.now().value() - span;
        var step = span / buckets;
        var smp = it.next();
        while (smp != null) {
            var v = smp.data;
            if (v != null && smp.when != null && (which != :hr || v != ActivityMonitor.INVALID_HR_SAMPLE)
                && (which != :stress || (v >= 0 && v <= 100))) {
                var idx = Stats.bucketIndex(smp.when.value(), t0, step, buckets);
                if (idx >= 0) {
                    sums[idx] += sampleValue(v, which);
                    cnts[idx] += 1;
                }
            }
            smp = it.next();
        }
        return Stats.bucketAverages(sums, cnts);
    }

    // One sample as a whole number: tenths of a degree for temperature (converted to
    // Fahrenheit if the Units setting or the watch says so), otherwise the value itself.
    private function sampleValue(v as Numeric, which as Symbol) as Number {
        if (which != :temp) { return v.toNumber(); }
        var c = v.toFloat();
        if (Units.tempImperial()) {
            c = Units.toFahrenheit(c);
        }
        return Math.round(c * 10).toNumber();
    }

    private function tenthsOrDash(v as Numeric or Null) as String {
        return v == null ? "--" : Stats.tenthsText(v.toNumber());
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
            if (_gGoal != null) {
                // empty track up to the goal, in the same dark tint the dial gauges use
                var th = _gGoal.toFloat() * (bot - top) / maxV;
                dc.setColor(Theme.dimOf(_gColor), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, bot - th, bw, th);
            }
            if (v != null) {
                var hgt = v.toFloat() * (bot - top) / maxV;
                dc.setColor(_gColor, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, bot - hgt, bw, hgt);
            }
            dc.setColor(i == n - 1 ? Theme.WHITE : Theme.GREY, Graphics.COLOR_TRANSPARENT);
            if (i < _gXl.size()) {
                dc.drawText(x + bw / 2, Theme.Y_XLABELS, Theme.FONT_LABEL, _gXl[i],
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        dc.setPenWidth(2);
        dc.setColor(Theme.BLUE_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x0, bot, x0 + n * bw + (n - 1) * gap, bot);
        dc.setPenWidth(1);
    }

    private function drawLineChart(dc as Dc, w as Number) as Void {
        var n = _gVals.size();
        var x0 = Theme.CHART_X;
        var x1 = w - Theme.CHART_X;
        var top = Theme.CHART_TOP;
        var bot = Theme.CHART_BOTTOM;

        var lo = Stats.minOf(_gVals);
        var hi = Stats.maxOf(_gVals);
        dc.setPenWidth(2);
        dc.setColor(Theme.BLUE_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x0, bot, x1, bot);
        dc.drawLine(x0, top, x1, top);
        dc.setPenWidth(1);
        if (n < 2 || lo == null || hi == null) {
            dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, (top + bot) / 2, Theme.FONT_VALUE, "No data",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        if (hi == lo) { hi = lo + 1; }

        // weather overlays: precipitation chance as bars behind the line, cloud cover as a strip above
        if (_gRain.size() == n && n > 1) {
            var colStep = (x1 - x0).toFloat() / (n - 1);
            for (var i = 0; i < n; i++) {
                var cx = x0 + colStep * i;
                var rain = _gRain[i];
                if (rain != null && rain > 0) {
                    var rh = rain.toFloat() * (bot - top) / 100.0;
                    // blue for rain, white for snow and other frozen precipitation
                    dc.setColor(_gFrozen[i] ? Theme.WHITE : Theme.BLUE, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(cx - colStep * 0.35, bot - rh, colStep * 0.7, rh);
                }
                var cloud = _gCloud[i];
                if (cloud != null) {
                    var sx = cx - colStep / 2;
                    var sw = colStep;
                    if (sx < x0) { sw -= (x0 - sx); sx = x0; }
                    if (sx + sw > x1) { sw = x1 - sx; }
                    dc.setColor(Stats.greyLevel(cloud.toNumber()), Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(sx, top + Theme.CLOUD_STRIP_DY, sw, Theme.CLOUD_STRIP_H);
                }
            }
        }

        // sleep band behind the line, with a moon at bedtime and a sun at wake time
        if (_gSleepA != null && _gSleepB != null && n > 1) {
            var xa = x0 + (x1 - x0) * _gSleepA / (n - 1);
            var xb = x0 + (x1 - x0) * (_gSleepB - 1) / (n - 1);
            dc.setColor(Theme.BLUE_DIM, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(xa, top, xb - xa, bot - top);
            if (_gSleepA > 0) { drawMoon(dc, xa, top + Theme.MARK_DY); }
            if (_gSleepB < n) { drawSun(dc, xb, top + Theme.MARK_DY); }
        }

        // axis values on the right
        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x1 + 6, top, Theme.FONT_LABEL, _gTenths ? Stats.tenthsText(hi.toNumber()) : hi.toString(),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x1 + 6, bot, Theme.FONT_LABEL, _gTenths ? Stats.tenthsText(lo.toNumber()) : lo.toString(),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

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
        if (px != null) { dc.fillCircle(px, py, Theme.LINE_END_R); }      // marks the latest value
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

    // ---- sleep band ---------------------------------------------------------
    // Connect IQ does not expose measured sleep (only the schedule set in Garmin
    // Connect), so the band is a guess: first from the data, then from the schedule.

    private function findSleep(hr as Array<Numeric or Null>, bb as Array<Numeric or Null>) as Void {
        _gSleepA = null;
        _gSleepB = null;
        _gCaption = "";
        var n = hr.size();
        var now = Time.now().value();
        var t0 = now - 86400;
        var step = 86400 / n;

        var inferred = SleepInference.infer(hr, bb);
        if (inferred != null) {
            _gSleepA = inferred[0];
            _gSleepB = inferred[1];
            _gCaption = "Sleep " + clock(t0 + inferred[0] * step) + "–" + clock(t0 + inferred[1] * step)
                + " · estimated";
            return;
        }

        // Fallback: the typical sleep and wake time set in Garmin Connect.
        var prof = UserProfile.getProfile();
        if (prof == null || prof.sleepTime == null || prof.wakeTime == null) { return; }
        var sched = SleepInference.fromSchedule(prof.sleepTime.value(), prof.wakeTime.value(),
                                                Time.today().value(), now, n);
        if (sched == null) { return; }
        _gSleepA = sched[0];
        _gSleepB = sched[1];
        _gCaption = "Sleep " + clock(sched[2]) + "–" + clock(sched[3]) + " · schedule";
    }

    private function clock(seconds as Number) as String {
        var info = Gregorian.info(new Time.Moment(seconds), Time.FORMAT_SHORT);
        return Stats.clockText(info.hour, info.min, System.getDeviceSettings().is24Hour);
    }

    private function drawMoon(dc as Dc, x as Numeric, y as Numeric) as Void {
        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, Theme.MOON_R);
        dc.setColor(Theme.BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + Theme.MOON_CUT_DX, y + Theme.MOON_CUT_DY, Theme.MOON_CUT_R);
    }

    private function drawSun(dc as Dc, x as Numeric, y as Numeric) as Void {
        dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, Theme.SUN_R);
        dc.setPenWidth(2);
        for (var i = 0; i < 8; i++) {
            var a = i * Math.PI / 4.0;
            dc.drawLine(x + Math.cos(a) * Theme.SUN_RAY_IN, y + Math.sin(a) * Theme.SUN_RAY_IN,
                        x + Math.cos(a) * Theme.SUN_RAY_OUT, y + Math.sin(a) * Theme.SUN_RAY_OUT);
        }
        dc.setPenWidth(1);
    }

    // ---- navigation affordances ------------------------------------------

    // Chevrons at the edges and page dots at the bottom. The right chevron means
    // "graph"; the left one means "back".
    private function drawNav(dc as Dc, w as Number, h as Number, sub as Number, fromActivity as Boolean,
                             count as Number) as Void {
        if (sub < count - 1) {
            chevron(dc, w - Theme.NAV_CHEVRON_X, h / 2, true);
        }
        if (sub >= 1 || fromActivity) {
            chevron(dc, Theme.NAV_CHEVRON_X, h / 2, false);
        }
        var cx = w / 2;
        for (var i = 0; i < count; i++) {
            dc.setColor(i == sub ? Theme.WHITE : Theme.GREY, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx + (i - (count - 1) / 2.0) * Theme.DOT_PITCH, Theme.Y_DOTS, Theme.DOT_R);
        }
    }

    private function chevron(dc as Dc, x as Numeric, y as Numeric, right as Boolean) as Void {
        var d = right ? -Theme.CHEVRON_HALF_W : Theme.CHEVRON_HALF_W;
        dc.setPenWidth(3);
        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x + d, y - Theme.CHEVRON_HALF_H, x - d, y);
        dc.drawLine(x - d, y, x + d, y + Theme.CHEVRON_HALF_H);
        dc.setPenWidth(1);
    }

    // ---- shared bits -----------------------------------------------------

    // Three small slanted M stripes as an accent at the top of every page.
    private function drawStripes(dc as Dc, cx as Numeric, y as Numeric) as Void {
        var colors = [Theme.BLUE, Theme.NAVY, Theme.RED];
        for (var i = 0; i < 3; i++) {
            var x = cx + Theme.STRIPE_X0 + i * Theme.STRIPE_PITCH;
            dc.setColor(colors[i], Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[x + Theme.STRIPE_SLANT, y - Theme.STRIPE_HALF_H],
                            [x + Theme.STRIPE_SLANT + Theme.STRIPE_W, y - Theme.STRIPE_HALF_H],
                            [x + Theme.STRIPE_W, y + Theme.STRIPE_HALF_H], [x, y + Theme.STRIPE_HALF_H]]);
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
        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
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
