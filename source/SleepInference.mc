import Toybox.Lang;

// Estimates a sleep window from heart rate and body battery buckets, or from the
// schedule set in Garmin Connect. Connect IQ does not expose measured sleep, so
// both are guesses. Pure logic: see source/tests/SleepInferenceTests.mc.
//
// Buckets are equal slices of the last 24 hours (48 x 30 minutes in the app).
module SleepInference {
    const MIN_SAMPLES = 24;      // buckets with heart rate needed before judging what "low" is
    const MIN_RUN = 8;           // shortest stretch that counts: 4 hours of 30 minute buckets
    const MIN_CONTRAST = 8;      // bpm the quiet stretch must sit below the median
    const MIN_RISE = 8;          // body battery points gained across the stretch
    const LOW_FRACTION = 0.4;    // "low" is this far from the 10th percentile toward the median

    // The longest stretch of low heart rate during which body battery rises.
    // Returns [firstBucket, endBucketExclusive], or null if nothing convincing.
    function infer(hr as Array<Numeric or Null>, bb as Array<Numeric or Null>) as Array<Number> or Null {
        var n = hr.size();
        var vals = [] as Array<Number>;
        for (var i = 0; i < n; i++) {
            if (hr[i] != null) { vals.add(hr[i].toNumber()); }
        }
        if (vals.size() < MIN_SAMPLES) { return null; }

        for (var i = 1; i < vals.size(); i++) {            // insertion sort
            var key = vals[i];
            var j = i - 1;
            while (j >= 0 && vals[j] > key) {
                vals[j + 1] = vals[j];
                j--;
            }
            vals[j + 1] = key;
        }
        var lo = vals[vals.size() / 10];
        var med = vals[vals.size() / 2];
        if (med - lo < MIN_CONTRAST) { return null; }       // no real night/day difference
        var thr = lo + (med - lo) * LOW_FRACTION;

        var bestS = -1;
        var bestE = -1;
        var runS = -1;
        var lastLow = -1;
        var gap = 0;
        for (var i = 0; i <= n; i++) {
            var low = (i < n) && (hr[i] != null) && (hr[i] <= thr);
            if (low) {
                if (runS < 0) { runS = i; }
                lastLow = i;
                gap = 0;
            } else if (runS >= 0) {
                gap += 1;
                if (gap > 1 || i == n) {                     // a single missing bucket is tolerated
                    if (bestS < 0 || lastLow - runS > bestE - bestS) {
                        bestS = runS;
                        bestE = lastLow;
                    }
                    runS = -1;
                    gap = 0;
                }
            }
        }
        if (bestS < 0 || bestE - bestS + 1 < MIN_RUN) { return null; }
        if (!risesDuring(bb, bestS, bestE)) { return null; }
        return [bestS, bestE + 1];
    }

    // True if body battery gains at least MIN_RISE points across buckets s..e, or if
    // there is too little body battery data to say that it does not.
    function risesDuring(bb as Array<Numeric or Null>, s as Number, e as Number) as Boolean {
        var first = null;
        var last = null;
        for (var i = s; i <= e && i < s + 4 && first == null; i++) {
            if (bb[i] != null) { first = bb[i]; }
        }
        for (var i = e; i >= s && i > e - 4 && last == null; i--) {
            if (bb[i] != null) { last = bb[i]; }
        }
        if (first == null || last == null) { return true; }
        return last - first >= MIN_RISE;
    }

    // The window from the typical sleep and wake time (seconds after local midnight),
    // for the most recent night, clipped to the last 24 hours before now.
    // Returns [firstBucket, endBucketExclusive, startSeconds, endSeconds] or null.
    function fromSchedule(sleepSecs as Number, wakeSecs as Number, todayStart as Number,
                          now as Number, n as Number) as Array<Number> or Null {
        var t0 = now - 86400;
        var step = 86400 / n;
        var start = todayStart + sleepSecs;
        if (start > now) { start -= 86400; }
        var end = todayStart + wakeSecs;
        while (end <= start) { end += 86400; }
        if (end > now) { end = now; }                       // not awake yet by the schedule
        var a = (start - t0) / step;
        var b = (end - t0 + step - 1) / step;
        if (a < 0) { a = 0; }
        if (b > n) { b = n; }
        if (b - a < 2) { return null; }
        return [a, b, start, end];
    }
}
