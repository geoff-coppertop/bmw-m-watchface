import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.System;

// Everything the dial shows that comes from the watch (the three ring fractions and the battery
// level), read in one place and kept. The view refreshes it in a step of its own before drawing, at
// most every REFRESH_MS and without slow reads in the low-power draw, and the drawing code only
// reads these fields. So a draw never waits on the watch's sensors, which matters most for the
// low-power draw, where the watch gives very little time.
class Snapshot {

    const REFRESH_MS = 10000;

    var stepsFrac as Float = 0.0;
    var activeFrac as Float = 0.0;
    var bodyFrac as Float = 0.0;
    var battery as Float = 0.0;                    // percent, 0 to 100

    private var _at as Number = -100000;           // System.getTimer() of the last refresh
    private var _loaded as Boolean = false;

    // value as a fraction of its goal; nothing known, or no goal, is empty. (Pure: tested.)
    static function frac(value as Numeric or Null, goal as Numeric or Null) as Float {
        if (value == null || goal == null || goal == 0) { return 0.0; }
        return value.toFloat() / goal;
    }

    // Read the watch now, if the snapshot is stale. allowSlow false (the low-power draw) refreshes
    // only if nothing has ever been read, and then without the slow sensor-history read.
    function refresh(allowSlow as Boolean) as Void {
        var now = System.getTimer();
        if (_loaded && (!allowSlow || now - _at < REFRESH_MS)) {
            return;
        }
        _at = now;
        _loaded = true;

        var info = ActivityMonitor.getInfo();
        stepsFrac = frac(info.steps, info.stepGoal);
        var wk = info.activeMinutesWeek;
        activeFrac = frac(wk != null ? wk.total : null, info.activeMinutesWeekGoal);
        var bb = Vitals.bodyBattery(allowSlow);
        bodyFrac = (bb == null) ? 0.0 : bb / 100.0;
        battery = System.getSystemStats().battery;
    }
}
