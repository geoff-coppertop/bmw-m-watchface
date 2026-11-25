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

    function initialize(face as BmwMWatchView) {
        _face = face;
    }

    function draw(dc as Dc, kind as Symbol) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        drawStripes(dc, cx, 34);

        if (kind == :weather) {
            drawWeather(dc, w, h);
            return;
        }
        if (kind == :rings) {
            drawRings(dc, w, h);
            return;
        }

        var title = "";
        var big = "--";
        var sub = "";
        var frac = -1.0;
        var barColor = Graphics.COLOR_WHITE;
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
            barColor = 0x0066B1;
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
            barColor = 0x003C78;
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
                barColor = 0xE32618;
                if (bb >= 76) { sub = "High energy"; }
                else if (bb >= 51) { sub = "Good"; }
                else if (bb >= 26) { sub = "Moderate"; }
                else { sub = "Low"; }
            }
            labels = ["24 h low", "24 h high"];
            values = [lo == null ? "--" : lo.toNumber().toString(),
                      hi == null ? "--" : hi.toNumber().toString()];
        }

        _face.drawGlyph(dc, kind, cx, 100, 62);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 168, Graphics.FONT_SMALL, title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 240, Graphics.FONT_NUMBER_HOT, big,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 298, Graphics.FONT_XTINY, sub,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (frac >= 0.0) {
            drawBar(dc, cx, 326, frac, barColor);
        }
        for (var i = 0; i < labels.size(); i++) {
            drawRow(dc, w, 366 + i * 34, labels[i], values[i]);
        }
    }

    // ---- combined ring page (tap anywhere on the ring zone) ---------------

    private function drawRings(dc as Dc, w as Number, h as Number) as Void {
        var cx = w / 2;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 76, Graphics.FONT_SMALL, "ACTIVITY RINGS",
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
        var colors = [0x0066B1, 0x003C78, 0xE32618];

        for (var i = 0; i < 3; i++) {
            var y = 150 + i * 100;
            _face.drawGlyph(dc, kinds[i], 84, y, 24);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(116, y - 14, Graphics.FONT_XTINY, names[i],
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(116, y + 10, Graphics.FONT_TINY, vals[i],
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            drawBar(dc, cx, y + 40, fracs[i], colors[i]);
        }
    }

    // ---- weather ---------------------------------------------------------

    private function drawWeather(dc as Dc, w as Number, h as Number) as Void {
        var cx = w / 2;
        var cond = null;
        if (Toybox has :Weather) {
            cond = Weather.getCurrentConditions();
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 76, Graphics.FONT_SMALL, "WEATHER",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (cond == null || cond.temperature == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2, Graphics.FONT_SMALL, "No weather data",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2 + 34, Graphics.FONT_XTINY, "Sync with Garmin Connect",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // big temperature, unit drawn small to its right
        var big = tempNum(cond.temperature).toString();
        var bw = dc.getTextWidthInPixels(big, Graphics.FONT_NUMBER_HOT);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 142, Graphics.FONT_NUMBER_HOT, big,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + bw / 2 + 8, 120, Graphics.FONT_SMALL, tempUnit(),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 204, Graphics.FONT_SMALL, conditionText(cond.condition),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (cond.feelsLikeTemperature != null) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 234, Graphics.FONT_XTINY,
                "Feels like " + tempNum(cond.feelsLikeTemperature).toString() + "°",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        var hl = "--";
        if (cond.highTemperature != null && cond.lowTemperature != null) {
            hl = tempNum(cond.highTemperature).toString() + "° / " + tempNum(cond.lowTemperature).toString() + "°";
        }
        drawRow(dc, w, 274, "High / low", hl);
        drawRow(dc, w, 304, "Rain chance", numStr(cond.precipitationChance, "%"));
        drawRow(dc, w, 334, "Wind", windText(cond));
        drawRow(dc, w, 364, "Humidity", numStr(cond.relativeHumidity, "%"));

        // next few hours
        var fc = Weather.getHourlyForecast();
        if (fc != null) {
            for (var i = 0; i < 4 && i < fc.size(); i++) {
                var x = w * (0.2 + 0.2 * i);
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(x, 410, Graphics.FONT_XTINY, hourLabel(fc[i].forecastTime),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                if (fc[i].temperature != null) {
                    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(x, 438, Graphics.FONT_TINY, tempNum(fc[i].temperature).toString() + "°",
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

    // ---- shared bits -----------------------------------------------------

    // Three small slanted M stripes as an accent at the top of every page.
    private function drawStripes(dc as Dc, cx as Numeric, y as Numeric) as Void {
        var colors = [0x0066B1, 0x003C78, 0xE32618];
        for (var i = 0; i < 3; i++) {
            var x = cx - 40 + i * 28;
            dc.setColor(colors[i], Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[x + 8, y - 7], [x + 28, y - 7], [x + 20, y + 7], [x, y + 7]]);
        }
    }

    private function drawBar(dc as Dc, cx as Numeric, y as Numeric, frac as Float, color as Number) as Void {
        var bw = 280;
        var bh = 10;
        if (frac > 1.0) { frac = 1.0; }
        // empty track = dark tint of the bar colour, same as the rings on the dial
        var track = 0x2A2A2A;
        if (color == 0x0066B1) { track = 0x00203A; }
        else if (color == 0x003C78) { track = 0x00101F; }
        else if (color == 0xE32618) { track = 0x3A0C08; }
        dc.setColor(track, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - bw / 2, y - bh / 2, bw, bh, 5);
        if (frac > 0.01) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw / 2, y - bh / 2, bw * frac, bh, 5);
        }
    }

    private function drawRow(dc as Dc, w as Number, y as Numeric, label as String, value as String) as Void {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(70, y, Graphics.FONT_XTINY, label,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 70, y, Graphics.FONT_TINY, value,
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
