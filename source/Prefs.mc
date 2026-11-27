import Toybox.Application;
import Toybox.Lang;

// The face's settings that are read while drawing, cached so that a draw never reads them from the
// watch's storage. reload() is called at start-up and when the setting changes.
class Prefs {

    private static var _alwaysOn as Boolean = false;
    private static var _loaded as Boolean = false;

    // True if the wearer has said Always-On Display is on, so the low-power frame should be the
    // dimmed dial. False (the default): the low-power frame is black, which looks like the screen
    // turning off and costs the watch nothing to draw. Connect IQ gives a face no way to ask which.
    static function alwaysOn() as Boolean {
        if (!_loaded) {
            reload();
        }
        return _alwaysOn;
    }

    static function reload() as Void {
        _loaded = true;
        try {
            var v = Application.Properties.getValue("AlwaysOn");
            _alwaysOn = (v instanceof Boolean) ? v : false;
        } catch (e) {
            _alwaysOn = false;               // setting unavailable: treat as off
        }
    }
}
