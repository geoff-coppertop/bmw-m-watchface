import Toybox.Lang;
import Toybox.WatchUi;

// Forwards touches on the watch face to the view, which decides what was hit.
// A watch face is documented to receive only onPress (touch and hold); a plain tap is not delivered
// to a WatchFaceDelegate (the simulator does not send one). onTap is kept in case a device does.
//   onTap   - shows a card, and a tap anywhere dismisses it
//   onPress - shows a card on a hold-only device; holding the card (or the zone again) opens the page
class BmwMWatchDelegate extends WatchUi.WatchFaceDelegate {

    private var _view as BmwMWatchView;

    function initialize(view as BmwMWatchView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var c = clickEvent.getCoordinates();
        System.println("TOUCH onTap " + c[0] + "," + c[1]);
        return _view.handleTap(c[0], c[1]);
    }

    function onPress(clickEvent as WatchUi.ClickEvent) as Boolean {
        var c = clickEvent.getCoordinates();
        System.println("TOUCH onPress " + c[0] + "," + c[1]);
        return _view.handleHold(c[0], c[1]);
    }
}
