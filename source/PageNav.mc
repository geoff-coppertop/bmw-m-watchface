import Toybox.Lang;

// Which page is open and how taps move between pages. No drawing and no watch
// APIs, so the navigation rules can be unit tested (source/tests/PageNavTests.mc).
//
//   page: null (the dial), :activity, :steps, :active, :body, :hr or :weather
//   sub:  0 = the detail page, 1 = the graph page behind it, 2 and 3 = more graph pages (Body only)
//   from: the page to go back to when a metric was opened from Activity
class PageNav {
    var page as Symbol or Null = null;
    var sub as Number = 0;
    var from as Symbol or Null = null;

    // How many pages a page has: detail then graph, except Body Battery, which has
    // four (detail, body battery graph, stress graph, sensor temperature). The
    // Activity page is a single page.
    static function subCount(kind as Symbol) as Number {
        if (kind == :activity) { return 1; }
        return kind == :body ? 4 : 2;
    }

    // The touch rule, in one place. A watch face is documented to receive only a press (touch and
    // hold; WatchFaceDelegate has no tap), so that is what must work on its own:
    //   hold a zone: its quick card (every zone has one);
    //   hold the card, or the same zone again: its page (only some zones have one);
    //   touch anywhere else while a card is up: dismiss it.
    // A device that also sends a tap gets: tap a zone for its card, tap anywhere to dismiss it.
    static function hasPage(zone as Symbol) as Boolean {
        return zone == :weather || zone == :hr || zone == :activity;
    }

    static function hasCard(zone as Symbol) as Boolean {
        return zone == :weather || zone == :hr || zone == :activity || zone == :date || zone == :battery;
    }

    function isOpen() as Boolean {
        return page != null;
    }

    function open(kind as Symbol) as Void {
        page = kind;
        sub = 0;
        from = null;
    }

    function close() as Void {
        page = null;
        sub = 0;
        from = null;
    }

    // Back one step: graph -> previous graph -> detail -> the Activity page it came from -> the dial.
    function back() as Void {
        if (sub > 0) {
            sub -= 1;
        } else if (from != null) {
            page = from;
            from = null;
        } else {
            close();
        }
    }

    // A press at (x, y) on a screen w pixels wide, while a page is open. The top strip
    // closes. On Activity a press on a row opens that metric (anywhere else closes).
    // Elsewhere the right edge goes forward (detail -> graph), the left edge back, and the
    // middle closes the page, so there is always an obvious way out.
    function tap(x as Number, y as Number, w as Number) as Void {
        if (page == null) { return; }
        if (y < Theme.CLOSE_Y) {
            close();
            return;
        }
        if (page == :activity) {
            var idx = (y - Theme.ACTIVITY_ROW_TOP) / Theme.ACTIVITY_ROW_PITCH;
            if (y >= Theme.ACTIVITY_ROW_TOP && idx < 3) {
                var kinds = [:steps, :active, :body];
                page = kinds[idx];
                from = :activity;
                sub = 0;
            } else {
                close();
            }
            return;
        }
        if (x > w * (1.0 - Theme.NAV_ZONE)) {
            if (sub < subCount(page) - 1) { sub += 1; }
        } else if (x < w * Theme.NAV_ZONE) {
            back();
        } else {
            close();
        }
    }
}
