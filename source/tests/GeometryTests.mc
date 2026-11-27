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
    Test.assert((Geometry.ringOuterR(220) - 179.2).abs() < 0.01);   // 192.2 (major tick) - 6 gap - 7 half a ring
    return true;
}

(:test)
function geometryHitTestOnTheVenuX1(logger as Test.Logger) as Boolean {
    // screen 448 x 486, dial radius 220, centre (224, 243)
    Test.assert(Geometry.hitTest(224, 76, 448, 486, 220) == null);           // 12 o'clock: no temperature zone any more
    Test.assertEqual(Geometry.hitTest(391, 243, 448, 486, 220), :date);      // the date window at 3 o'clock
    Test.assertEqual(Geometry.hitTest(57, 243, 448, 486, 220), :battery);    // the battery icon at 9 o'clock
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
function geometryBadgeIsCentredBetweenTheRoundelAndTheTicks(logger as Test.Logger) as Boolean {
    Test.assert((Geometry.tickInnerR(220) - 192.2).abs() < 0.01);            // 220 - 8 inset - 19.8 major tick
    Test.assert((Geometry.roundelOuterR(220) - 32.7).abs() < 0.01);          // 24.2 + 6 + half the 5 px pen
    Test.assert((Geometry.badgeCenterY(243, 220) - 130.55).abs() < 0.01);    // 243 - (32.7 + 192.2) / 2
    return true;
}

(:test)
function geometryMiddleRingRadius(logger as Test.Logger) as Boolean {
    Test.assert((Geometry.middleRingR(220) - 163.2).abs() < 0.01);          // 179.2 minus one 14 + 2 pitch
    return true;
}

(:test)
function geometryDateAndBatteryZonesMatchTheRoundelsSize(logger as Test.Logger) as Boolean {
    // Radius 79.2 centred at (391, 243) and (57, 243): 70 px away still hits, vertically or horizontally
    Test.assertEqual(Geometry.hitTest(391, 313, 448, 486, 220), :date);
    Test.assertEqual(Geometry.hitTest(321, 243, 448, 486, 220), :date);
    Test.assertEqual(Geometry.hitTest(57, 313, 448, 486, 220), :battery);
    Test.assertEqual(Geometry.hitTest(127, 243, 448, 486, 220), :battery);
    // and the roundel keeps what is nearer to it
    Test.assertEqual(Geometry.hitTest(284, 243, 448, 486, 220), :hr);
    return true;
}

(:test)
function geometryTouchRadiusComesFromTheTheme(logger as Test.Logger) as Boolean {
    var edge = (Theme.TOUCH_R * 220).toNumber();                            // 79 px on the Venu X1
    Test.assertEqual(Geometry.hitTest(224 + edge - 2, 243, 448, 486, 220), :hr);     // just inside
    Test.assert(Geometry.hitTest(224 + edge + 2, 243, 448, 486, 220) == null);       // just outside
    return true;
}
