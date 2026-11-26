import Toybox.Lang;
import Toybox.Test;

(:test)
function logoFirstStripeAtUnitScale(logger as Test.Logger) as Boolean {
    var p = Logo.stripePoints(0, 0, 0, 1);
    Test.assertEqual(p[0][0], 57);      // top left: 66 - 9
    Test.assertEqual(p[1][0], 93);      // top right: 36 wider
    Test.assertEqual(p[2][0], 36);      // foot right: leans 57 left across the 99 height
    Test.assertEqual(p[3][0], 0);       // foot left: the badge's left edge
    Test.assertEqual(p[2][1], 99);
    return true;
}

(:test)
function logoStripesAreEvenlySpacedAndTheSameWidth(logger as Test.Logger) as Boolean {
    var a = Logo.stripePoints(0, 0, 0, 1);
    var b = Logo.stripePoints(1, 0, 0, 1);
    var c = Logo.stripePoints(2, 0, 0, 1);
    Test.assertEqual(b[0][0] - a[1][0], 5);      // the gap between stripes 1 and 2
    Test.assertEqual(c[0][0] - b[1][0], 5);      // and between 2 and 3: the same
    Test.assertEqual(a[1][0] - a[0][0], 36);
    Test.assertEqual(c[1][0] - c[0][0], 36);
    return true;
}

(:test)
function logoScalesAndOffsets(logger as Test.Logger) as Boolean {
    var p = Logo.stripePoints(0, 100, 50, 0.5);
    Test.assertEqual(p[0][0], 128.5);            // 100 + (66 - 9) * 0.5
    Test.assertEqual(p[0][1], 50);
    Test.assertEqual(p[3][0], 100);              // the foot sits at the left edge
    Test.assertEqual(p[3][1], 99.5);             // 50 + 99 * 0.5
    Test.assertEqual(Logo.STRIPES_WIDTH, 175);   // 184 - 9
    return true;
}
