import Toybox.Lang;
import Toybox.Test;

(:test)
function geometryDialRadius(logger as Test.Logger) as Boolean {
    Test.assertEqual(Geometry.dialRadius(448, 486), 220);    // the Venu X1 screen: width limits it
    return true;
}

(:test)
function geometryRingsMatchTheBadgeStripes(logger as Test.Logger) as Boolean {
    Test.assertEqual(Geometry.ringWidth(220), 14);           // 13.86 rounds up, it is not truncated to 13
    Test.assert((Geometry.ringOuterR(220) - 183.2).abs() < 0.01);
    return true;
}

(:test)
function geometryHitTestOnTheVenuX1(logger as Test.Logger) as Boolean {
    // screen 448 x 486, dial radius 220, centre (224, 243)
    Test.assertEqual(Geometry.hitTest(224, 76, 448, 486, 220), :weather);    // the temperature at 12 o'clock
    Test.assertEqual(Geometry.hitTest(224, 100, 448, 486, 220), :weather);
    Test.assertEqual(Geometry.hitTest(356, 243, 448, 486, 220), :date);      // the date window at 3 o'clock
    Test.assertEqual(Geometry.hitTest(92, 243, 448, 486, 220), :battery);    // the battery icon at 9 o'clock
    Test.assertEqual(Geometry.hitTest(224, 243, 448, 486, 220), :hr);        // the roundel
    Test.assertEqual(Geometry.hitTest(284, 243, 448, 486, 220), :hr);        // inside the roundel zone
    Test.assertEqual(Geometry.hitTest(224, 426, 448, 486, 220), :activity);  // the rings at 6 o'clock
    Test.assertEqual(Geometry.hitTest(114, 393, 448, 486, 220), :activity);  // toward the end of the wedge
    return true;
}

(:test)
function geometryHitTestMisses(logger as Test.Logger) as Boolean {
    Test.assert(Geometry.hitTest(10, 10, 448, 486, 220) == null);            // a corner
    Test.assert(Geometry.hitTest(304, 243, 448, 486, 220) == null);          // just outside the roundel zone
    Test.assert(Geometry.hitTest(374, 330, 448, 486, 220) == null);          // beside the rings, off the wedge
    Test.assert(Geometry.hitTest(224, 115, 448, 486, 220) == null);          // between the temperature and the badge
    Test.assert(Geometry.hitTest(224, 458, 448, 486, 220) == null);          // below the rings
    Test.assert(Geometry.hitTest(224, 243, 0, 0, 0) == null);                // before the first draw
    return true;
}

(:test)
function geometryTemperatureMirrorsTheMiddleRing(logger as Test.Logger) as Boolean {
    Test.assert((Geometry.middleRingR(220) - 167.2).abs() < 0.01);          // 183.2 minus one 14 + 2 pitch
    Test.assert((Geometry.tempY(243, 220) - 75.8).abs() < 0.01);            // the same distance above the centre
    return true;
}
