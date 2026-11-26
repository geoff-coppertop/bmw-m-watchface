import Toybox.Graphics;
import Toybox.Lang;

// One place for the face's colours, spacing and font roles. The dial and the
// detail pages both read from here, so changing a value changes everything.
module Theme {

    // ---- palette ------------------------------------------------------------
    // Eight colours plus black, and nothing else is ever drawn:
    //   the three BMW M logo colours, a muted (dark) tint of each, white, and one grey.
    // Black is the AMOLED background. (The cloud strip shades between black and the
    // grey; that is a ramp of the one grey, not another colour.)
    const BLUE = 0x0066B1;
    const NAVY = 0x003C78;
    const RED  = 0xE32618;

    // Muted tints of each: empty tracks, the sleep band, axes.
    const BLUE_DIM = 0x00203A;
    const NAVY_DIM = 0x00101F;
    const RED_DIM  = 0x3A0C08;

    const WHITE = 0xFFFFFF;   // primary text, the M letter, the active page dot
    const GREY  = 0x999999;   // secondary text, labels, glyph strokes, chevrons,
                              // inactive dots, low-power (sleep) accents
    const BLACK = 0x000000;

    // ---- font roles ---------------------------------------------------------
    // Text is drawn with vector fonts at these pixel sizes (see Fonts.mc), so it can be smaller
    // than the smallest system font. If the device has no vector font, Fonts falls back to the
    // system fonts XTINY, TINY, SMALL and NUMBER_HOT. Change a size here and the wireframes follow.
    const FONT_PX_LABEL = 22;      // labels, date row
    const FONT_PX_VALUE = 28;      // values
    const FONT_PX_TITLE = 32;      // page titles, conditions
    const FONT_PX_HERO = 80;       // the big number on a metric or weather page

    // ---- dial spacing (pixels unless noted) -------------------------------
    const GAP = 2;               // between badge stripes and between the ring bars
    const RING_TICK_GAP = 6;     // between the outer ring and the major ticks (a visible margin)
    const TICK_INSET = 8;        // outer end of the ticks, in from the dial edge
    const TICK_MAJOR = 0.09;     // major tick length, as a fraction of dial radius
    const TICK_MINOR = 0.035;    // minor tick length, as a fraction of dial radius

    // ---- detail page layout (448 x 486, the Venu X1) ----------------------
    const MARGIN = 70;           // left and right edge of rows
    const ROW_PITCH = 32;        // distance between rows in every list
    const BAR_W = 280;
    const BAR_H = 10;
    const BAR_R = 5;
    const Y_STRIPES = 34;        // the badge stripes at the top of every page
    const Y_TITLE = 76;          // page title
    const Y_HERO = 142;          // the big number (a metric's value, or the temperature)
    const Y_SUB = 204;           // the line under it (a goal, or the conditions)
    const Y_NOTE = 234;          // the next line (feels-like), or the progress bar on a metric page
    const Y_ROWS = 270;          // the first detail row on every page; rows are ROW_PITCH apart

    // ---- graph pages and navigation ---------------------------------------
    const CHART_X = 60;           // left/right inset of the plot area
    const CHART_TOP = 140;
    const CHART_BOTTOM = 360;
    const CAPTION_MARGIN = 40;    // a caption wider than the screen minus this on each side switches to its short form
    const Y_CAPTION = 108;        // one-line note under the graph title (sleep source)
    const Y_XLABELS = 384;
    const Y_STATS = 424;
    const Y_DOTS = 462;           // page dots
    const DOT_R = 4;
    const NAV_ZONE = 0.35;        // tap the outer 35% of the width to go back / forward
    const CLOSE_Y = 64;           // tap above this to close the page
    const ACTIVITY_ROW_TOP = 100; // tappable rows on the Activity page
    const ACTIVITY_ROW_PITCH = 100;
    const BAR_COLS_W = 34;        // 7-day bar chart: bar width and gap
    const BAR_COLS_GAP = 8;

    // ---- dial windows ------------------------------------------------------------
    // The temperature (12 o'clock), the date (3) and the watch battery (9) all sit on one
    // arc: the middle ring's distance from the centre (Geometry.middleRingR).
    // The date's two lines are stacked from the real font heights (Dc.getFontHeight), so they
    // never overlap whatever the device's fonts are. The date also sits a little inside the arc
    // so it clears the 3 o'clock tick.
    const WINDOW_DATE_DX = -6;

    // ---- watch battery icon (9 o'clock) ---------------------------------------
    const BATT_W = 34;            // small enough to clear the 9 o'clock tick (about 8 px)
    const BATT_H = 17;
    const BATT_R = 3;             // corner radius
    const BATT_TERM_W = 3;
    const BATT_TERM_H = 8;
    const BATT_PAD = 2;           // gap between the outline and the fill

    // ---- quick cards (press a zone) -------------------------------------------
    const CARD_W = 300;
    const CARD_H = 124;           // one big value: title, value, detail
    const CARD_H_ROWS = 164;      // the Activity card: title and three rows
    const CARD_R = 14;
    const CARD_PAD = 24;          // side padding for rows
    const CARD_TITLE_Y = 24;      // from the top of the card
    const CARD_BIG_Y = 62;
    const CARD_DETAIL_Y = 98;
    const CARD_ROW_Y = 62;
    const CARD_ROW_PITCH = 36;
    const CARD_MS = 4000;         // how long a card stays up
    const PAGE_MS = 20000;        // a page closes after this long with no touch

    // ---- touch targets on the dial (Geometry.hitTest and the touch-targets wireframe) --
    const TOUCH_R = 0.36;         // radius of the roundel, date and battery circles, as a fraction of the dial radius
    const TOUCH_ARC_ANGLE = 42;   // the temperature and rings targets are arcs: degrees either side of 12 / 6 o'clock
    const TOUCH_TEMP_HALF_R = 30; // the temperature arc: half its thickness, around the temperature's own radius
    const TOUCH_RING_OUT = 14;    // pixels beyond the outer ring
    const TOUCH_RING_IN = 20;     // pixels inside the inner ring

    // ---- page furniture: accents, chevrons, marks ---------------------------
    const STRIPE_H = 26;          // the stripes at the top of every page: the face badge's stripes, scaled to this height
    const NAV_CHEVRON_X = 24;     // edge chevrons, from the screen edge
    const CHEVRON_HALF_W = 6;
    const CHEVRON_HALF_H = 12;
    const DOT_PITCH = 20;         // page dots
    const MARK_DY = -12;          // moon and sun, above the top of the chart
    const MOON_R = 7;
    const MOON_CUT_R = 6;
    const MOON_CUT_DX = 4;
    const MOON_CUT_DY = -2;
    const SUN_R = 4;
    const SUN_RAY_IN = 6;
    const SUN_RAY_OUT = 9;
    const LINE_END_R = 4;         // dot on the latest value of a line chart
    const CLOUD_STRIP_DY = -22;   // cloud cover strip, from the top of the chart
    const CLOUD_STRIP_H = 12;

    // ---- Activity page rows ------------------------------------------------
    const ACT_GLYPH = 24;         // glyph size
    const ACT_GLYPH_DX = 14;      // glyph centre, from the left margin
    const ACT_TEXT_DX = 46;       // label and value, from the left margin
    // Each row's label and value are stacked from the real font heights (Dc.getFontHeight), the
    // block centred ACT_BLOCK_DY from the row's middle, with the bar ACT_BAR_GAP below it.
    const ACT_BLOCK_DY = -12;
    const ACT_BAR_GAP = 8;
    const ACT_CHEVRON_X = 36;     // row chevron, from the right edge
    const ACT_CHEVRON_DY = 8;

    // ---- Weather page ------------------------------------------------------
    // Its rows sit on the same grid as the metric pages: the last of the four detail
    // rows is at Y_ROWS, and the hourly strip uses the two rows below it.
    const WEATHER_Y_UNIT = 120;
    const WEATHER_UNIT_DX = 8;
    const WEATHER_NODATA_DY = 34;

    // Line weight for stroked glyphs: grows with glyph size, never below 2 px.
    function glyphPen(s as Numeric) as Number {
        var p = (s * 0.08).toNumber();
        return p < 2 ? 2 : p;
    }

    // Which colour each metric uses everywhere: dial rings, Activity page bars,
    // detail page bars and graphs.
    function metricColor(kind as Symbol) as Number {
        if (kind == :steps) { return BLUE; }
        if (kind == :active) { return NAVY; }
        if (kind == :body || kind == :hr || kind == :weather || kind == :temp
            || kind == :stress) { return RED; }
        return WHITE;
    }

    // The muted tint that goes with a bar colour (its empty track).
    function dimOf(color as Number) as Number {
        if (color == BLUE) { return BLUE_DIM; }
        if (color == NAVY) { return NAVY_DIM; }
        if (color == RED) { return RED_DIM; }
        return BLUE_DIM;     // anything else: the muted blue, so tracks stay inside the palette
    }
}
