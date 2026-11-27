import Toybox.Lang;
import Toybox.Test;

(:test)
function statsTenthsText(logger as Test.Logger) as Boolean {
    Test.assertEqual(Stats.tenthsText(341), "34.1");
    Test.assertEqual(Stats.tenthsText(305), "30.5");
    Test.assertEqual(Stats.tenthsText(0), "0.0");
    Test.assertEqual(Stats.tenthsText(-12), "-1.2");
    Test.assertEqual(Stats.tenthsText(95), "9.5");
    return true;
}

(:test)
function statsLowBatteryThreshold(logger as Test.Logger) as Boolean {
    Test.assert(Stats.isLowBattery(19));
    Test.assert(!Stats.isLowBattery(20));
    Test.assert(!Stats.isLowBattery(100));
    return true;
}

(:test)
function statsDaysText(logger as Test.Logger) as Boolean {
    Test.assertEqual(Stats.daysText(null), "--");
    Test.assertEqual(Stats.daysText(6.34), "6.3 days");
    Test.assertEqual(Stats.daysText(0.5), "0.5 days");
    Test.assertEqual(Stats.daysText(12.7), "12 days");
    return true;
}

(:test)
function statsStressBands(logger as Test.Logger) as Boolean {
    Test.assertEqual(Stats.stressBand(0), "resting");
    Test.assertEqual(Stats.stressBand(25), "resting");
    Test.assertEqual(Stats.stressBand(26), "low");
    Test.assertEqual(Stats.stressBand(50), "low");
    Test.assertEqual(Stats.stressBand(51), "medium");
    Test.assertEqual(Stats.stressBand(75), "medium");
    Test.assertEqual(Stats.stressBand(76), "high");
    Test.assertEqual(Stats.stressBand(100), "high");
    return true;
}
