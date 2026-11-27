import Toybox.Lang;
import Toybox.Test;

(:test)
function snapshotFractionOfAGoal(logger as Test.Logger) as Boolean {
    Test.assertEqual(Snapshot.frac(50, 100), 0.5);
    Test.assertEqual(Snapshot.frac(0, 100), 0.0);
    Test.assertEqual(Snapshot.frac(150, 100), 1.5);           // the ring clamps this when it draws
    return true;
}

(:test)
function snapshotFractionWithNothingKnownIsEmpty(logger as Test.Logger) as Boolean {
    Test.assertEqual(Snapshot.frac(null, 100), 0.0);
    Test.assertEqual(Snapshot.frac(50, null), 0.0);
    Test.assertEqual(Snapshot.frac(50, 0), 0.0);              // no goal set
    return true;
}
