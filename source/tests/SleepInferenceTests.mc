import Toybox.Lang;
import Toybox.Test;

// Inference: a clear night is found, and awkward data is rejected.

(:test)
function sleepFindsAClearNight(logger as Test.Logger) as Boolean {
    var r = SleepInference.infer(TestData.hrNight(30, 44), TestData.bbRising(30, 44));
    Test.assert(r != null);
    Test.assertEqual(r[0], 30);
    Test.assertEqual(r[1], 44);
    return true;
}

(:test)
function sleepRejectsFlatHeartRate(logger as Test.Logger) as Boolean {
    // Every bucket would count as "low" without the minimum contrast rule.
    Test.assert(SleepInference.infer(TestData.flat(70), TestData.flat(null)) == null);
    return true;
}

(:test)
function sleepRejectsADeskLullWhileBatteryDrains(logger as Test.Logger) as Boolean {
    Test.assert(SleepInference.infer(TestData.hrNight(20, 30), TestData.bbFalling()) == null);
    return true;
}

(:test)
function sleepToleratesOneMissingBucket(logger as Test.Logger) as Boolean {
    var hr = TestData.hrNight(30, 44);
    hr[36] = null;
    var r = SleepInference.infer(hr, TestData.bbRising(30, 44));
    Test.assert(r != null);
    Test.assertEqual(r[0], 30);
    Test.assertEqual(r[1], 44);
    return true;
}

(:test)
function sleepRejectsARestUnderFourHours(logger as Test.Logger) as Boolean {
    Test.assert(SleepInference.infer(TestData.hrNight(30, 36), TestData.bbRising(30, 36)) == null);
    return true;
}

(:test)
function sleepWorksWithoutBodyBattery(logger as Test.Logger) as Boolean {
    var r = SleepInference.infer(TestData.hrNight(30, 44), TestData.flat(null));
    Test.assert(r != null);
    Test.assertEqual(r[0], 30);
    return true;
}

(:test)
function sleepNeedsEnoughHeartRateData(logger as Test.Logger) as Boolean {
    var hr = TestData.flat(null);
    for (var i = 30; i < 40; i++) {
        hr[i] = 52;
    }
    Test.assert(SleepInference.infer(hr, TestData.flat(null)) == null);
    return true;
}

(:test)
function sleepPicksTheNightOverANap(logger as Test.Logger) as Boolean {
    var hr = TestData.hrNight(30, 44);
    for (var i = 10; i < 18; i++) {
        hr[i] = 52;
    }
    var r = SleepInference.infer(hr, TestData.bbRising(30, 44));
    Test.assert(r != null);
    Test.assertEqual(r[0], 30);
    Test.assertEqual(r[1], 44);
    return true;
}

// Schedule fallback. Times are seconds; todayStart is local midnight.

(:test)
function scheduleOvernightWindow(logger as Test.Logger) as Boolean {
    var T = 1000000;
    // sleep 23:00, wake 06:30, now 08:00
    var r = SleepInference.fromSchedule(82800, 23400, T, T + 28800, 48);
    Test.assert(r != null);
    Test.assertEqual(r[0], 30);
    Test.assertEqual(r[1], 45);
    Test.assertEqual(r[2], T - 3600);
    Test.assertEqual(r[3], T + 23400);
    return true;
}

(:test)
function scheduleStillAsleepIsClippedToNow(logger as Test.Logger) as Boolean {
    var T = 1000000;
    // same schedule, but it is only 02:00, so the window ends now
    var r = SleepInference.fromSchedule(82800, 23400, T, T + 7200, 48);
    Test.assert(r != null);
    Test.assertEqual(r[0], 42);
    Test.assertEqual(r[1], 48);
    Test.assertEqual(r[3], T + 7200);
    return true;
}

(:test)
function scheduleSleepAfterMidnight(logger as Test.Logger) as Boolean {
    var T = 1000000;
    // sleep 01:00, wake 09:00, now 12:00
    var r = SleepInference.fromSchedule(3600, 32400, T, T + 43200, 48);
    Test.assert(r != null);
    Test.assertEqual(r[0], 26);
    Test.assertEqual(r[1], 42);
    return true;
}

(:test)
function scheduleTooShortIsIgnored(logger as Test.Logger) as Boolean {
    var T = 1000000;
    Test.assert(SleepInference.fromSchedule(82800, 82800 + 1000, T, T + 86000, 48) == null);
    return true;
}
