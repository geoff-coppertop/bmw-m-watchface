import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class BmwMWatchApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // A setting was changed in Garmin Connect: re-read the one the drawing uses, and redraw.
    function onSettingsChanged() as Void {
        Prefs.reload();
        WatchUi.requestUpdate();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new BmwMWatchView();
        return [ view, new BmwMWatchDelegate(view) ];
    }
}
