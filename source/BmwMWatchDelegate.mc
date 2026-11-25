import Toybox.Lang;
import Toybox.WatchUi;

// Forwards touches on the watch face to the view, which decides what was hit.
//   onTap   - a screen tap: opens pages and moves between them
//   onPress - a touch and hold (per the SDK docs): shows a quick card
class BmwMWatchDelegate extends WatchUi.WatchFaceDelegate {

    private var _view as BmwMWatchView;

    function initialize(view as BmwMWatchView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var c = clickEvent.getCoordinates();
        return _view.handleTap(c[0], c[1]);
    }

    function onPress(clickEvent as WatchUi.ClickEvent) as Boolean {
        var c = clickEvent.getCoordinates();
        return _view.handleHold(c[0], c[1]);
    }
}
