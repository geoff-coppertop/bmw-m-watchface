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

// The quick card shown over the dial when a zone is touched: a little more detail than the face
// shows (weather and feels-like, the date in full, battery and days left, heart rate with resting
// rate and stress, steps / active minutes / body battery). It is not a page: it disappears by
// itself after a few seconds, or when you touch elsewhere.
class Cards {

    function drawCard(dc as Dc, kind as Symbol) as Void {
        var w = dc.getWidth();
        var cx = w / 2;
        var rows = (kind == :activity);
        var ch = rows ? Theme.CARD_H_ROWS : (kind == :weather ? Theme.CARD_H_TWO : Theme.CARD_H);
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
        var detail2 = "";
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
                var hi = (cond.highTemperature != null) ? tempNum(cond.highTemperature).toString() + "°" : "--";
                var lo = (cond.lowTemperature != null) ? tempNum(cond.lowTemperature).toString() + "°" : "--";
                detail2 = "High " + hi + " · Low " + lo;
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
            var names = ["Steps", "Active", "Body battery"];
            var vals = [stepsTxt, actTxt, bb == null ? "--" : bb.toString()];
            // each row wears the colour of its ring on the dial
            var colors = [Theme.metricColor(:steps), Theme.metricColor(:active), Theme.metricColor(:body)];
            for (var i = 0; i < 3; i++) {
                var y = top + Theme.CARD_ROW_Y + i * Theme.CARD_ROW_PITCH;
                dc.setColor(colors[i], Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(left + Theme.CARD_PAD, y - Theme.CARD_SWATCH_H / 2,
                    Theme.CARD_SWATCH_W, Theme.CARD_SWATCH_H, Theme.CARD_SWATCH_W / 2);
                dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(left + Theme.CARD_PAD + Theme.CARD_SWATCH_W + Theme.CARD_SWATCH_GAP, y, Fonts.label, names[i],
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(left + Theme.CARD_W - Theme.CARD_PAD, y, Fonts.value, vals[i],
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top + Theme.CARD_TITLE_Y, Fonts.label, title, j);
        if (!rows) {
            dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, top + Theme.CARD_BIG_Y, Fonts.title, big, j);
            dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, top + Theme.CARD_DETAIL_Y, Fonts.label, detail, j);
            if (detail2.length() > 0) {
                dc.drawText(cx, top + Theme.CARD_DETAIL_Y + Theme.CARD_DETAIL2_PITCH, Fonts.label, detail2, j);
            }
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

    private function tempNum(c as Numeric) as Number {
        return Units.temp(c, Units.tempImperial());
    }

    private function tempUnit() as String {
        return Units.tempUnit(Units.tempImperial());
    }
}
