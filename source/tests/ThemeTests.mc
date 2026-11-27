import Toybox.Lang;
import Toybox.Test;

(:test)
function themeDimTintMatchesItsColour(logger as Test.Logger) as Boolean {
    Test.assertEqual(Theme.dimOf(Theme.BLUE), Theme.BLUE_DIM);
    Test.assertEqual(Theme.dimOf(Theme.NAVY), Theme.NAVY_DIM);
    Test.assertEqual(Theme.dimOf(Theme.RED), Theme.RED_DIM);
    Test.assertEqual(Theme.dimOf(0x123456), Theme.BLUE_DIM);        // anything else: the muted blue
    return true;
}

(:test)
function themeLowPowerDimsEachColourToSixtyPercent(logger as Test.Logger) as Boolean {
    Test.assertEqual(Theme.lowPower(Theme.BLUE), 0x003D6A);     // 00 66 B1 -> 00 3D 6A
    Test.assertEqual(Theme.lowPower(Theme.NAVY), 0x002448);     // 00 3C 78 -> 00 24 48
    Test.assertEqual(Theme.lowPower(Theme.RED), 0x88160E);      // E3 26 18 -> 88 16 0E
    Test.assertEqual(Theme.lowPower(Theme.BLACK), 0x000000);
    return true;
}

(:test)
function themeOneColourPerMetric(logger as Test.Logger) as Boolean {
    Test.assertEqual(Theme.metricColor(:steps), Theme.BLUE);
    Test.assertEqual(Theme.metricColor(:active), Theme.NAVY);
    Test.assertEqual(Theme.metricColor(:body), Theme.RED);
    Test.assertEqual(Theme.metricColor(:anything), Theme.WHITE);
    return true;
}
