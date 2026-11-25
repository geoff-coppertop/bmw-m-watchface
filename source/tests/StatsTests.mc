import Toybox.Lang;
import Toybox.Test;

(:test)
function statsMinMax(logger as Test.Logger) as Boolean {
    var v = [5, null, 3, 9] as Array<Numeric or Null>;
    Test.assertEqual(Stats.minOf(v), 3);
    Test.assertEqual(Stats.maxOf(v), 9);
    return true;
}

(:test)
function statsMinMaxWithNoData(logger as Test.Logger) as Boolean {
    var none = [null, null] as Array<Numeric or Null>;
    var empty = [] as Array<Numeric or Null>;
    Test.assert(Stats.minOf(none) == null);
    Test.assert(Stats.maxOf(none) == null);
    Test.assert(Stats.minOf(empty) == null);
    Test.assert(Stats.maxOf(empty) == null);
    return true;
}

(:test)
function statsAverageIgnoresNulls(logger as Test.Logger) as Boolean {
    Test.assertEqual(Stats.avgOf([2, null, 4] as Array<Numeric or Null>), 3);
    Test.assertEqual(Stats.avgOf([null] as Array<Numeric or Null>), 0);
    Test.assertEqual(Stats.avgOf([] as Array<Numeric or Null>), 0);
    return true;
}

(:test)
function statsFormat(logger as Test.Logger) as Boolean {
    Test.assertEqual(Stats.fmt(null), "--");
    Test.assertEqual(Stats.fmt(7), "7");
    return true;
}

(:test)
function statsBucketIndex(logger as Test.Logger) as Boolean {
    // 48 buckets of 1800 s starting at t0 = 1000
    Test.assertEqual(Stats.bucketIndex(999, 1000, 1800, 48), -1);      // just before: must not land in bucket 0
    Test.assertEqual(Stats.bucketIndex(1000, 1000, 1800, 48), 0);
    Test.assertEqual(Stats.bucketIndex(2799, 1000, 1800, 48), 0);
    Test.assertEqual(Stats.bucketIndex(2800, 1000, 1800, 48), 1);
    Test.assertEqual(Stats.bucketIndex(1000 + 48 * 1800 - 1, 1000, 1800, 48), 47);
    Test.assertEqual(Stats.bucketIndex(1000 + 48 * 1800, 1000, 1800, 48), -1);   // end is exclusive
    return true;
}

(:test)
function statsBucketAverages(logger as Test.Logger) as Boolean {
    var out = Stats.bucketAverages([10, 0, 9] as Array<Number>, [2, 0, 3] as Array<Number>);
    Test.assertEqual(out[0], 5);
    Test.assert(out[1] == null);
    Test.assertEqual(out[2], 3);
    return true;
}

(:test)
function statsClockText(logger as Test.Logger) as Boolean {
    Test.assertEqual(Stats.clockText(23, 5, true), "23:05");
    Test.assertEqual(Stats.clockText(0, 7, false), "12:07a");
    Test.assertEqual(Stats.clockText(13, 30, false), "1:30p");
    Test.assertEqual(Stats.clockText(12, 0, false), "12:00p");
    return true;
}

(:test)
function statsGreyLevel(logger as Test.Logger) as Boolean {
    Test.assertEqual(Stats.greyLevel(0), 0x000000);
    Test.assertEqual(Stats.greyLevel(50), 0x5D5D5D);
    Test.assertEqual(Stats.greyLevel(100), 0xBBBBBB);
    Test.assertEqual(Stats.greyLevel(150), 0xBBBBBB);     // clamped
    Test.assertEqual(Stats.greyLevel(-5), 0x000000);
    return true;
}

(:test)
function statsTenthsText(logger as Test.Logger) as Boolean {
    Test.assertEqual(Stats.tenthsText(341), "34.1");
    Test.assertEqual(Stats.tenthsText(305), "30.5");
    Test.assertEqual(Stats.tenthsText(0), "0.0");
    Test.assertEqual(Stats.tenthsText(-12), "-1.2");
    Test.assertEqual(Stats.tenthsText(95), "9.5");
    return true;
}
