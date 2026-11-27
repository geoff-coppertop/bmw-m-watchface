import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;

// Body battery, read once for the whole face. The newest history sample can be empty for a while
// (the ring went unfilled and the card showed "--"), so this takes the newest sample that has data,
// remembers the last good value, and reads the history at most once a minute (the face redraws
// every second, and each read is slow).
class Vitals {

    private static var _bb as Number or Null = null;     // the last good reading
    private static var _at as Number = -100000;          // System.getTimer() of the last read

    static function bodyBattery() as Number or Null {
        var now = System.getTimer();
        if (now - _at < 60000 && _bb != null) {
            return _bb;
        }
        _at = now;
        if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
            var it = SensorHistory.getBodyBatteryHistory({ :period => 5, :order => SensorHistory.ORDER_NEWEST_FIRST });
            if (it != null) {
                var smp = it.next();
                for (var i = 0; i < 5 && smp != null; i++) {
                    if (smp.data != null) {
                        _bb = smp.data.toNumber();
                        break;
                    }
                    smp = it.next();
                }
            }
        }
        return _bb;                                       // the last good value if this read found none
    }
}
