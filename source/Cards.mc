import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;
import Toybox.Weather;

// The quick card shown over the dial when a zone is touched: a little more detail than the face
// shows. Every card is the same size. Weather (reached by touching the date) leads with the full
// day and date; battery and heart rate have an icon there; activity has none (its rows carry their
// ring's colour). It is not a page: it disappears by itself after a
// few seconds, or when you touch elsewhere. The weather card is the only place the temperature
// appears.
class Cards {

    function drawCard(dc as Dc, kind as Symbol) as Void {
        var cx = dc.getWidth() / 2;
        var ch = Theme.CARD_H;                          // every card is the same size
        var left = cx - Theme.CARD_W / 2;
        var top = dc.getHeight() / 2 - ch / 2;

        dc.setColor(Theme.BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(left, top, Theme.CARD_W, ch, Theme.CARD_R);
        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(left, top, Theme.CARD_W, ch, Theme.CARD_R);
        dc.setPenWidth(1);

        if (kind == :activity) {
            drawActivityRows(dc, left, top, ch);
            return;
        }

        // A card is an optional small line, one big line, and up to two small lines under it,
        // stacked from the real font heights and centred in the card.
        var above = "";
        var icon = false;                                // the battery icon in the small line's place
        var heart = false;                               // or the heart, on the heart rate card
        var big = "--";
        var below = [] as Array<String>;

        if (kind == :battery) {
            var st = System.getSystemStats();
            icon = true;                                 // the dial's battery icon says what this is
            big = st.battery.toNumber().toString() + "%";
            below.add(Stats.daysText(st.batteryInDays) + " left" + (st.charging ? " · Charging" : ""));

        } else if (kind == :weather) {
            // the small line is the day and date, like "Wed, 25 Sep, 2026": the card is reached
            // through the date
            var d = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
            above = d.day_of_week.toString() + ", " + d.day.toString() + " " + d.month.toString() + ", " + d.year.toString();
            var cond = (Toybox has :Weather) ? Weather.getCurrentConditions() : null;
            if (cond != null && cond.temperature != null) {
                big = tempNum(cond.temperature).toString() + tempUnit();
                var line = conditionText(cond.condition);
                if (cond.feelsLikeTemperature != null) {
                    line += (line.length() > 0 ? " · " : "") + "feels " + tempNum(cond.feelsLikeTemperature).toString() + "°";
                }
                below.add(line);
                var hi = (cond.highTemperature != null) ? tempNum(cond.highTemperature).toString() + "°" : "--";
                var lo = (cond.lowTemperature != null) ? tempNum(cond.lowTemperature).toString() + "°" : "--";
                below.add("High " + hi + " · Low " + lo);
            } else {
                below.add("No weather data");
            }

        } else {
            // :hr, the roundel: a heart in the small line's place, the number says bpm
            heart = true;
            var act = Activity.getActivityInfo();
            if (act != null && act.currentHeartRate != null) { big = act.currentHeartRate.toString() + " bpm"; }
            var prof = UserProfile.getProfile();
            var st2 = ActivityMonitor.getInfo().stressScore;
            below.add("Resting " + ((prof != null && prof.restingHeartRate != null) ? prof.restingHeartRate.toString() : "--")
                + " · Stress " + (st2 == null ? "--" : st2.toString()));
        }

        var j = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var hl = dc.getFontHeight(Fonts.label);
        var ht = dc.getFontHeight(Fonts.title);
        var gap = Theme.CARD_LINE_GAP;
        var hasAbove = icon || heart || above.length() > 0;
        var total = ht + below.size() * (hl + gap) + (hasAbove ? hl + gap : 0);
        var y = top + (ch - total) / 2;
        if (icon) {
            BatteryIcon.draw(dc, cx - BatteryIcon.width() / 2, y + hl / 2, System.getSystemStats().battery, Theme.RED);
            y += hl + gap;
        } else if (heart) {
            drawHeart(dc, cx, y + hl / 2, Theme.CARD_HEART_S);
            y += hl + gap;
        } else if (above.length() > 0) {
            dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y + hl / 2, Fonts.label, above, j);
            y += hl + gap;
        }
        dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y + ht / 2, Fonts.title, big, j);
        y += ht;
        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < below.size(); i++) {
            y += gap;
            dc.drawText(cx, y + hl / 2, Fonts.label, below[i], j);
            y += hl;
        }
    }

    // A filled heart in red, centred on (x, y), s pixels wide.
    private function drawHeart(dc as Dc, x as Numeric, y as Numeric, s as Numeric) as Void {
        var cy = y - s * 0.06;                           // its shape runs from -0.43 s to +0.55 s: centre it
        dc.setColor(Theme.RED, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - s * 0.25, cy - s * 0.15, s * 0.28);
        dc.fillCircle(x + s * 0.25, cy - s * 0.15, s * 0.28);
        dc.fillPolygon([[x - s * 0.51, cy - s * 0.02], [x + s * 0.51, cy - s * 0.02], [x, cy + s * 0.55]]);
    }

    // The three activity figures, one row each, centred in the card. Each row wears the colour of
    // its ring on the dial, as a slanted M stripe (the badge's own geometry, from Logo).
    private function drawActivityRows(dc as Dc, left as Number, top as Number, ch as Number) as Void {
        var info = ActivityMonitor.getInfo();
        var stepsTxt = (info.steps == null) ? "--" : info.steps.toString()
            + ((info.stepGoal != null) ? " / " + info.stepGoal.toString() : "");
        var wk = info.activeMinutesWeek;
        var actTxt = (wk == null) ? "--" : wk.total.toString()
            + ((info.activeMinutesWeekGoal != null) ? " / " + info.activeMinutesWeekGoal.toString() : "") + " min";
        var bb = Vitals.bodyBattery();
        var names = ["Steps", "Active", "Body battery"];
        var vals = [stepsTxt, actTxt, bb == null ? "--" : bb.toString()];
        var colors = [Theme.metricColor(:steps), Theme.metricColor(:active), Theme.metricColor(:body)];
        var k = Theme.CARD_SWATCH_H / Logo.HEIGHT.toFloat();
        var sw = ((Logo.STRIPE_W + Logo.LEAN) * k).toNumber();
        for (var i = 0; i < 3; i++) {
            var y = top + ch / 2 + (i - 1) * Theme.CARD_ROW_PITCH;
            dc.setColor(colors[i], Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(Logo.stripePoints(0, left + Theme.CARD_PAD, y - Theme.CARD_SWATCH_H / 2, k));
            dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(left + Theme.CARD_PAD + sw + Theme.CARD_SWATCH_GAP, y, Fonts.label, names[i],
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(left + Theme.CARD_W - Theme.CARD_PAD, y, Fonts.value, vals[i],
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
