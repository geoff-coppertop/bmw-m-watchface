import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;
import Toybox.Weather;

// The quick card shown over the dial when a zone is touched. Every card has the same size and the
// same layout: rows of "label ... value", the label grey on the left and the value white on the
// right (the weather card has the date above its rows). The activity rows also carry their
// ring's colour as a slanted M stripe. It is not a page: it disappears by itself after a few
// seconds, or when you touch elsewhere. The weather card is the only place the temperature appears.
class Cards {

    function drawCard(dc as Dc, kind as Symbol) as Void {
        var cx = dc.getWidth() / 2;
        var ch = Theme.CARD_H;
        var left = cx - Theme.CARD_W / 2;
        var top = dc.getHeight() / 2 - ch / 2;

        dc.setColor(Theme.BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(left, top, Theme.CARD_W, ch, Theme.CARD_R);
        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(left, top, Theme.CARD_W, ch, Theme.CARD_R);
        dc.setPenWidth(1);

        var headerText = "";                              // only the weather card has one: the date
        var names = [] as Array<String>;
        var vals = [] as Array<String>;
        var colors = null as Array<Number> or Null;      // a ring colour per row, for the activity card

        if (kind == :battery) {
            var st = System.getSystemStats();
            names.add("Battery");
            vals.add(st.battery.toNumber().toString() + "%");
            names.add("Time left");
            vals.add(Stats.daysText(st.batteryInDays));
            if (st.charging) {
                names.add("Status");
                vals.add("Charging");
            }

        } else if (kind == :weather) {
            // the header is the day and date, like "Wed, 25 Sep, 2026": the card is reached through
            // the date
            var d = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
            headerText = d.day_of_week.toString() + ", " + d.day.toString() + " " + d.month.toString() + ", " + d.year.toString();
            var cond = (Toybox has :Weather) ? Weather.getCurrentConditions() : null;
            if (cond != null && cond.temperature != null) {
                var hi = (cond.highTemperature != null) ? tempNum(cond.highTemperature).toString() : "--";
                var lo = (cond.lowTemperature != null) ? tempNum(cond.lowTemperature).toString() : "--";
                names.add("Now");
                vals.add(tempNum(cond.temperature).toString() + tempUnit());
                names.add("Conditions");
                vals.add(conditionText(cond.condition));
                names.add("Feels like");
                vals.add((cond.feelsLikeTemperature != null) ? tempNum(cond.feelsLikeTemperature).toString() + tempUnit() : "--");
                names.add("High / low");
                vals.add(hi + "° / " + lo + tempUnit());
            } else {
                names.add("Weather");
                vals.add("No data");
            }

        } else if (kind == :hr) {
            var act = Activity.getActivityInfo();
            var prof = UserProfile.getProfile();
            // breathing rate, in breaths per minute (brpm); some watches do not offer it, and some
            // readings are not measured, so it may be "--". Stress is a 0 to 100 score, shown with its
            // band (resting, low, medium, high).
            var ai = ActivityMonitor.getInfo();
            var rr = (ai has :respirationRate) ? ai.respirationRate : null;
            var stress = ai.stressScore;
            names.add("Current HR");
            vals.add(((act != null && act.currentHeartRate != null) ? act.currentHeartRate.toString() : "--") + " bpm");
            names.add("Resting HR");
            vals.add(((prof != null && prof.restingHeartRate != null) ? prof.restingHeartRate.toString() : "--") + " bpm");
            names.add("Breathing");
            vals.add((rr == null ? "--" : rr.toString()) + " brpm");
            names.add("Stress");
            vals.add(stress == null ? "--" : stress.toString() + " · " + Stats.stressBand(stress));

        } else {
            // :activity, the rings
            var info = ActivityMonitor.getInfo();
            var wk = info.activeMinutesWeek;
            var bb = Vitals.bodyBattery();
            names.add("Steps");
            vals.add((info.steps == null) ? "--" : info.steps.toString()
                + ((info.stepGoal != null) ? " / " + info.stepGoal.toString() : ""));
            names.add("Active");
            vals.add(((wk == null) ? "--" : wk.total.toString()
                + ((info.activeMinutesWeekGoal != null) ? " / " + info.activeMinutesWeekGoal.toString() : "")) + " min");
            names.add("Body battery");
            vals.add((bb == null ? "--" : bb.toString()) + " / 100");
            colors = [Theme.metricColor(:steps), Theme.metricColor(:active), Theme.metricColor(:body)] as Array<Number>;
        }

        // Stack the header and the rows from the real font heights, centred in the card.
        var hl = dc.getFontHeight(Fonts.label);
        var hv = dc.getFontHeight(Fonts.value);
        var gap = Theme.CARD_LINE_GAP;
        var pitch = Theme.CARD_ROW_PITCH;
        var rows = names.size();
        var headerH = (headerText.length() > 0) ? hl + gap : 0;
        var total = headerH + (rows - 1) * pitch + hv;
        var y = top + (ch - total) / 2;

        if (headerText.length() > 0) {
            dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y + hl / 2, Fonts.label, headerText,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        y += headerH;

        var k = Theme.CARD_SWATCH_H / Logo.HEIGHT.toFloat();
        var sw = ((Logo.STRIPE_W + Logo.LEAN) * k).toNumber();
        for (var i = 0; i < rows; i++) {
            var ry = y + hv / 2 + i * pitch;
            var lx = left + Theme.CARD_PAD;
            if (colors != null) {
                // a slanted M stripe, the badge's own geometry (from Logo), in the ring's colour
                dc.setColor(colors[i], Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon(Logo.stripePoints(0, lx, ry - Theme.CARD_SWATCH_H / 2, k));
                lx += sw + Theme.CARD_SWATCH_GAP;
            }
            dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(lx, ry, Fonts.label, names[i], Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(left + Theme.CARD_W - Theme.CARD_PAD, ry, Fonts.value, vals[i],
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
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

    private function tempNum(c as Numeric) as Number {
        return Units.temp(c, Units.tempImperial());
    }

    private function tempUnit() as String {
        return Units.tempUnit(Units.tempImperial());
    }
}
