import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class BmwMWatchApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // The Units setting was changed in Garmin Connect: redraw with the new units.
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new BmwMWatchView();
        return [ view, new BmwMWatchDelegate(view) ];
    }
}
