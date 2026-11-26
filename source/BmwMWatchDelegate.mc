import Toybox.Lang;
import Toybox.WatchUi;

// Forwards touches on the watch face to the view, which decides what was hit.
// A watch face is only sent onPress (Garmin documents it as touch and hold); a plain tap is not
// delivered to a WatchFaceDelegate. onTap is kept in case a device does send it; the view counts
// a touch reported both ways once.
class BmwMWatchDelegate extends WatchUi.WatchFaceDelegate {

    private var _view as BmwMWatchView;

    function initialize(view as BmwMWatchView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var c = clickEvent.getCoordinates();
        System.println("TOUCH onTap " + c[0] + "," + c[1]);
        return _view.handleTouch(c[0], c[1]);
    }

    function onPress(clickEvent as WatchUi.ClickEvent) as Boolean {
        var c = clickEvent.getCoordinates();
        System.println("TOUCH onPress " + c[0] + "," + c[1]);
        return _view.handleTouch(c[0], c[1]);
    }
}
