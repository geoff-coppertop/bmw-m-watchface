import Toybox.Graphics;
import Toybox.Lang;

// One place for the face's colours, spacing and font roles. The dial and the
// detail pages both read from here, so changing a value changes everything.
module Theme {

    // ---- palette: the BMW M logo ------------------------------------------
    const BLUE = 0x0066B1;
    const NAVY = 0x003C78;
    const RED  = 0xE32618;

    // Dark tints of each, used for empty ring and bar tracks.
    const BLUE_DIM = 0x00203A;
    const NAVY_DIM = 0x00101F;
    const RED_DIM  = 0x3A0C08;

    // The one deliberate exception: NAVY is nearly invisible as a small glyph on
    // black, so the active-minutes bolt uses this lighter blue instead.
    const NAVY_LIGHT = 0x4A90D9;

    // ---- neutrals: three greys plus white and black -----------------------
    const WHITE      = 0xFFFFFF;   // primary text, the M letter
    const GREY_LIGHT = 0xBBBBBB;   // secondary text, labels, glyph strokes
    const GREY_MID   = 0x555555;   // low-power (sleep) accents, outlines
    const GREY_DARK  = 0x2A2A2A;   // neutral empty track
    const BLACK      = 0x000000;

    // ---- font roles (Garmin system fonts) ---------------------------------
    const FONT_LABEL = Graphics.FONT_XTINY;        // labels, date row
    const FONT_VALUE = Graphics.FONT_TINY;         // values
    const FONT_TITLE = Graphics.FONT_SMALL;        // page titles, conditions
    const FONT_HERO  = Graphics.FONT_NUMBER_HOT;   // headline numbers

    // ---- dial spacing (pixels unless noted) -------------------------------
    const GAP = 2;               // between badge stripes, ring bars, and ring and ticks
    const TICK_INSET = 8;        // outer end of the ticks, in from the dial edge
    const TICK_MAJOR = 0.09;     // major tick length, as a fraction of dial radius
    const TICK_MINOR = 0.035;    // minor tick length, as a fraction of dial radius

    // ---- detail page layout (448 x 486, the Venu X1) ----------------------
    const MARGIN = 70;           // left and right edge of rows
    const ROW_PITCH = 32;        // distance between rows in every list
    const BAR_W = 280;
    const BAR_H = 10;
    const BAR_R = 5;
    const Y_STRIPES = 34;        // M stripe accent at the top of every page
    const Y_TITLE = 76;          // title on pages with no glyph
    const Y_GLYPH = 100;         // big glyph on the metric pages
    const GLYPH_BIG = 62;
    const Y_TITLE_UNDER_GLYPH = 168;
    const Y_HERO = 240;
    const Y_SUB = 298;
    const Y_BAR = 326;
    const Y_ROWS = 366;          // first row on the metric pages
    const Y_WEATHER_ROWS = 274;  // first row on the weather page

    // ---- graph pages and navigation ---------------------------------------
    const CHART_X = 60;           // left/right inset of the plot area
    const CHART_TOP = 140;
    const CHART_BOTTOM = 360;
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

    // Line weight for stroked glyphs: grows with glyph size, never below 2 px.
    function glyphPen(s as Numeric) as Number {
        var p = (s * 0.08).toNumber();
        return p < 2 ? 2 : p;
    }

    // The empty-track tint that goes with a bar colour.
    function dimOf(color as Number) as Number {
        if (color == BLUE) { return BLUE_DIM; }
        if (color == NAVY) { return NAVY_DIM; }
        if (color == RED) { return RED_DIM; }
        return GREY_DARK;
    }
}
