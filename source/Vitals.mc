import Toybox.Application;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;

// Body battery, read once for the whole face. The newest history sample can be empty for a while
// (the ring went unfilled and the card showed "--"), so this takes the newest sample that has data
// and remembers the last good reading, in memory and in the watch's storage, so the gauge keeps
// showing it (including after the face restarts) until a newer one arrives. It reads the history
// at most once a minute, or every 10 seconds while it has nothing to show (each read is slow).
class Vitals {

    private static const KEY_VALUE = "bodyBattery";
    private static const KEY_TIME = "bodyBatteryAt";
    private static const STALE_SECONDS = 86400;          // a stored reading older than a day is ignored

    private static var _bb as Number or Null = null;     // the last good reading
    private static var _at as Number = -100000;          // System.getTimer() of the last read
    private static var _loaded as Boolean = false;

    // allowRead false means "do not touch the sensor history": return what is already known. The
    // always-on (low-power) draw passes false, because the watch gives that draw very little time
    // and the history read is slow; a draw that runs over can be cut off and leave the screen stuck
    // on a half-drawn frame.
    static function bodyBattery(allowRead as Boolean) as Number or Null {
        if (!_loaded) {
            _loaded = true;
            _bb = stored();                               // the reading from before the face (re)started
        }
        var now = System.getTimer();
        if (!allowRead || now - _at < (_bb != null ? 60000 : 10000)) {
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
                        store(_bb);
                        break;
                    }
                    smp = it.next();
                }
            }
        }
        return _bb;                                       // the last good value if this read found none
    }

    private static function stored() as Number or Null {
        try {
            var v = Application.Storage.getValue(KEY_VALUE);
            var t = Application.Storage.getValue(KEY_TIME);
            if (v instanceof Number && t instanceof Number && Time.now().value() - t < STALE_SECONDS) {
                return v;
            }
        } catch (e) {
            // storage unavailable: no stored reading
        }
        return null;
    }

    private static function store(v as Number) as Void {
        try {
            Application.Storage.setValue(KEY_VALUE, v);
            Application.Storage.setValue(KEY_TIME, Time.now().value());
        } catch (e) {
            // storage unavailable: the in-memory value still works
        }
    }
}
