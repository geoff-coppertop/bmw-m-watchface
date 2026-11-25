import Toybox.Lang;
import Toybox.Test;

(:test)
function unitsAutoFollowsTheWatch(logger as Test.Logger) as Boolean {
    Test.assert(Units.resolve(Units.AUTO, true));
    Test.assert(!Units.resolve(Units.AUTO, false));
    return true;
}

(:test)
function unitsAnOverrideBeatsTheWatch(logger as Test.Logger) as Boolean {
    Test.assert(Units.resolve(Units.IMPERIAL, false));
    Test.assert(Units.resolve(Units.IMPERIAL, true));
    Test.assert(!Units.resolve(Units.METRIC, true));
    Test.assert(!Units.resolve(Units.METRIC, false));
    return true;
}

(:test)
function unitsTemperature(logger as Test.Logger) as Boolean {
    Test.assertEqual(Units.temp(20, false), 20);
    Test.assertEqual(Units.temp(20, true), 68);
    Test.assertEqual(Units.temp(0, true), 32);
    Test.assertEqual(Units.temp(-40, true), -40);        // the two scales meet here
    return true;
}

(:test)
function unitsTemperatureRoundsToTheNearestDegree(logger as Test.Logger) as Boolean {
    Test.assertEqual(Units.temp(21.6, false), 22);
    Test.assertEqual(Units.temp(21.4, false), 21);
    Test.assertEqual(Units.temp(-1.6, false), -2);       // not -1: rounded, not truncated
    Test.assertEqual(Units.temp(-0.4, false), 0);
    return true;
}

(:test)
function unitsTemperatureLabels(logger as Test.Logger) as Boolean {
    Test.assertEqual(Units.tempUnit(false), "°C");
    Test.assertEqual(Units.tempUnit(true), "°F");
    return true;
}

(:test)
function unitsWindSpeed(logger as Test.Logger) as Boolean {
    Test.assertEqual(Units.windSpeed(10, false), 36);    // 36 km/h
    Test.assertEqual(Units.windSpeed(10, true), 22);     // 22.4 mph
    Test.assertEqual(Units.windUnit(false), "km/h");
    Test.assertEqual(Units.windUnit(true), "mph");
    return true;
}

(:test)
function unitsDistance(logger as Test.Logger) as Boolean {
    Test.assertEqual(Units.distanceText(470000, false), "4.7 km");
    Test.assertEqual(Units.distanceText(470000, true), "2.9 mi");
    Test.assertEqual(Units.distanceText(0, false), "0.0 km");
    return true;
}
