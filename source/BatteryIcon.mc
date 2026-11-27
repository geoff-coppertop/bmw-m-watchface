import Toybox.Graphics;
import Toybox.Lang;

// The watch battery as a simple icon that empties as the battery drains: a grey outline and
// terminal, a white fill (red below 20%; lowColor is that red, dimmed in the low-power draw).
// Drawn at 9 o'clock on the dial.
module BatteryIcon {

    // The icon centred vertically on y, with its body's left edge at left.
    function draw(dc as Dc, left as Numeric, y as Numeric, pct as Numeric, lowColor as Number) as Void {
        var top = y - Theme.BATT_H / 2;
        dc.setColor(Theme.GREY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(left, top, Theme.BATT_W, Theme.BATT_H, Theme.BATT_R);
        dc.setPenWidth(1);
        dc.fillRectangle(left + Theme.BATT_W, y - Theme.BATT_TERM_H / 2, Theme.BATT_TERM_W, Theme.BATT_TERM_H);
        var fillW = (Theme.BATT_W - 2 * Theme.BATT_PAD) * pct / 100.0;
        if (fillW > 0) {
            dc.setColor(Stats.isLowBattery(pct.toNumber()) ? lowColor : Theme.WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(left + Theme.BATT_PAD, top + Theme.BATT_PAD, fillW, Theme.BATT_H - 2 * Theme.BATT_PAD);
        }
    }
}
