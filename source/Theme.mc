import Toybox.Graphics;
import Toybox.Lang;

// One place for the face's colours, spacing and font roles. The dial and the
// cards both read from here, so changing a value changes everything.
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
    // system fonts XTINY, TINY and SMALL. Change a size here and the wireframes follow.
    const FONT_PX_LABEL = 22;      // labels, date row
    const FONT_PX_VALUE = 28;      // values
    const FONT_PX_TITLE = 32;      // the big line on a card

    // ---- dial spacing (pixels unless noted) -------------------------------
    const GAP = 2;               // between badge stripes and between the ring bars
    const RING_TICK_GAP = 6;     // between the outer ring and the major ticks (a visible margin)
    const TICK_INSET = 8;        // outer end of the ticks, in from the dial edge
    const TICK_MAJOR = 0.09;     // major tick length, as a fraction of dial radius
    const TICK_MINOR = 0.035;    // minor tick length, as a fraction of dial radius

    // ---- dial windows ------------------------------------------------------------
    // The date (3 o'clock) and the watch battery (9) sit on one arc: the middle ring's distance
    // from the centre (Geometry.middleRingR). The temperature is not on the dial: it is the weather
    // card, reached by touching the date and then its card.
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
    const CARD_W = 330;
    const CARD_H = 124;           // one big value: title, value, detail
    const CARD_H_ROWS = 164;      // the Activity card: title and three rows
    const CARD_H_TWO = 152;       // the Weather card: one more detail line (high and low)
    const CARD_R = 14;
    const CARD_PAD = 24;          // side padding for rows
    const CARD_TITLE_Y = 24;      // from the top of the card
    const CARD_BIG_Y = 62;
    const CARD_DETAIL_Y = 98;
    const CARD_DETAIL2_PITCH = 28; // the second detail line, below the first
    const CARD_ROW_Y = 62;
    const CARD_ROW_PITCH = 36;
    const CARD_SWATCH_H = 22;     // the slanted M stripe, in a ring's colour, before each Activity row
    const CARD_SWATCH_GAP = 8;    // between the stripe and the label
    const CARD_MS = 4000;         // how long a card stays up

    // ---- touch targets on the dial (Geometry.hitTest and the touch-targets wireframe) --
    const TOUCH_R = 0.36;         // radius of the roundel, date and battery circles, as a fraction of the dial radius
    const TOUCH_ARC_ANGLE = 42;   // the rings target is an arc: degrees either side of 6 o'clock
    const TOUCH_RING_OUT = 14;    // pixels beyond the outer ring
    const TOUCH_RING_IN = 20;     // pixels inside the inner ring

    // When the watch drops to low-power mode the face keeps its colours but dims them: each of the
    // three channels scaled to this percentage. (Grey would lose which colour is which, and a fill
    // dimmed to its own empty track would lose the gauge; 60% keeps both readable.)
    const LOW_POWER_PCT = 60;

    function lowPower(color as Number) as Number {
        var r = ((color >> 16) & 0xFF) * LOW_POWER_PCT / 100;
        var g = ((color >> 8) & 0xFF) * LOW_POWER_PCT / 100;
        var b = (color & 0xFF) * LOW_POWER_PCT / 100;
        return (r << 16) | (g << 8) | b;
    }

    // The colour of each of the three dial rings.
    function metricColor(kind as Symbol) as Number {
        if (kind == :steps) { return BLUE; }
        if (kind == :active) { return NAVY; }
        if (kind == :body) { return RED; }
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
