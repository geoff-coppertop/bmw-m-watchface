import Toybox.Lang;
import Toybox.WatchUi;

// Forwards taps on the watch face to the view, which decides what was hit.
class BmwMWatchDelegate extends WatchUi.WatchFaceDelegate {

    private var _view as BmwMWatchView;

    function initialize(view as BmwMWatchView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    function onPress(clickEvent as WatchUi.ClickEvent) as Boolean {
        var c = clickEvent.getCoordinates();
        return _view.handleTap(c[0], c[1]);
    }
}
