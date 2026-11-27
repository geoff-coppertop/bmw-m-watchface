import Toybox.Lang;

// The M badge's stripe geometry, in the logo's own units (the badge is 99 units tall, the
// stripes lean 57 units across that height, are 36 wide and start at x = 66, 107 and 148,
// with the left edge of the first stripe's foot at x = 9). The face badge and the bars
// on the Activity card both draw from this, so they always match.
// Pure: covered by source/tests/LogoTests.mc.
module Logo {
    const HEIGHT = 99;
    const ORIGIN_X = 9;          // x of the badge's left edge, in logo units
    const STRIPES_WIDTH = 175;   // the three stripes together: x = 9 to 184
    const STRIPE_W = 36;         // one stripe, measured across
    const LEAN = 57;             // how far a stripe leans over the badge's height

    function stripeTop(i as Number) as Number {
        return i == 0 ? 66 : (i == 1 ? 107 : 148);
    }

    // The four corners of stripe i, with the logo's x = ORIGIN_X at screen x = left, its top at
    // screen y = top, and k pixels per logo unit.
    function stripePoints(i as Number, left as Numeric, top as Numeric, k as Numeric) as Array<[Numeric, Numeric]> {
        var xt = stripeTop(i);
        return [
            [left + (xt - ORIGIN_X) * k, top],
            [left + (xt + STRIPE_W - ORIGIN_X) * k, top],
            [left + (xt + STRIPE_W - LEAN - ORIGIN_X) * k, top + HEIGHT * k],
            [left + (xt - LEAN - ORIGIN_X) * k, top + HEIGHT * k]
        ] as Array<[Numeric, Numeric]>;
    }
}
