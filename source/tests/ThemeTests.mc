import Toybox.Lang;
import Toybox.Test;

(:test)
function themeDimTintMatchesItsColour(logger as Test.Logger) as Boolean {
    Test.assertEqual(Theme.dimOf(Theme.BLUE), Theme.BLUE_DIM);
    Test.assertEqual(Theme.dimOf(Theme.NAVY), Theme.NAVY_DIM);
    Test.assertEqual(Theme.dimOf(Theme.RED), Theme.RED_DIM);
    Test.assertEqual(Theme.dimOf(0x123456), Theme.GREY_DARK);       // anything else: neutral track
    return true;
}

(:test)
function themeOneColourPerMetric(logger as Test.Logger) as Boolean {
    Test.assertEqual(Theme.metricColor(:steps), Theme.BLUE);
    Test.assertEqual(Theme.metricColor(:active), Theme.NAVY);
    Test.assertEqual(Theme.metricColor(:body), Theme.RED);
    Test.assertEqual(Theme.metricColor(:hr), Theme.RED);
    Test.assertEqual(Theme.metricColor(:weather), Theme.RED);        // same red as the other line charts
    Test.assertEqual(Theme.metricColor(:anything), Theme.WHITE);
    return true;
}

(:test)
function themeGlyphPenGrowsButNeverBelowTwo(logger as Test.Logger) as Boolean {
    Test.assertEqual(Theme.glyphPen(10), 2);
    Test.assertEqual(Theme.glyphPen(24), 2);
    Test.assertEqual(Theme.glyphPen(62), 4);
    Test.assertEqual(Theme.glyphPen(100), 8);
    return true;
}
