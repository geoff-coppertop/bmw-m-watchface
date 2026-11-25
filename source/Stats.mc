import Toybox.Lang;

// Small pure helpers for the graph pages. Nothing here touches the watch APIs,
// so all of it can be unit tested (source/tests/StatsTests.mc).
module Stats {

    function minOf(vals as Array<Numeric or Null>) as Numeric or Null {
        var r = null;
        for (var i = 0; i < vals.size(); i++) {
            if (vals[i] != null && (r == null || vals[i] < r)) { r = vals[i]; }
        }
        return r;
    }

    function maxOf(vals as Array<Numeric or Null>) as Numeric or Null {
        var r = null;
        for (var i = 0; i < vals.size(); i++) {
            if (vals[i] != null && (r == null || vals[i] > r)) { r = vals[i]; }
        }
        return r;
    }

    // Whole-number average of the non-null values, or 0 if there are none.
    function avgOf(vals as Array<Numeric or Null>) as Number {
        var sum = 0;
        var cnt = 0;
        for (var i = 0; i < vals.size(); i++) {
            if (vals[i] != null) {
                sum += vals[i];
                cnt++;
            }
        }
        return cnt == 0 ? 0 : (sum / cnt).toNumber();
    }

    function fmt(v as Numeric or Null) as String {
        return v == null ? "--" : v.toString();
    }

    // Which time bucket a sample falls in, or -1 if it is before t0 or past the end.
    // (Checked explicitly because integer division truncates toward zero, which would
    // otherwise put a sample just before t0 into bucket 0.)
    function bucketIndex(whenSec as Number, t0 as Number, step as Number, buckets as Number) as Number {
        if (whenSec < t0) { return -1; }
        var idx = (whenSec - t0) / step;
        return idx < buckets ? idx : -1;
    }

    // Average of each bucket's samples; null where a bucket had none.
    function bucketAverages(sums as Array<Number>, cnts as Array<Number>) as Array<Numeric or Null> {
        var out = new [sums.size()] as Array<Numeric or Null>;
        for (var i = 0; i < sums.size(); i++) {
            if (cnts[i] > 0) { out[i] = sums[i] / cnts[i]; }
        }
        return out;
    }

    // Below 20% the battery icon turns red.
    function isLowBattery(pct as Number) as Boolean {
        return pct < 20;
    }

    // "6.3 days" under ten days, "12 days" above, "--" if the watch gave no estimate.
    function daysText(days as Float or Null) as String {
        if (days == null) { return "--"; }
        if (days >= 10) { return days.toNumber().toString() + " days"; }
        return tenthsText((days * 10).toNumber()) + " days";
    }

    // The scale ActivityMonitor.Info.stressScore documents: 0-25 resting, 26-50 low,
    // 51-75 medium, 76-100 high.
    function stressBand(score as Number) as String {
        if (score <= 25) { return "Resting"; }
        if (score <= 50) { return "Low"; }
        if (score <= 75) { return "Medium"; }
        return "High";
    }

    // A value held in tenths as text with one decimal: 341 -> "34.1", -12 -> "-1.2".
    function tenthsText(t as Number) as String {
        var a = t < 0 ? -t : t;
        return (t < 0 ? "-" : "") + (a / 10).toString() + "." + (a % 10).toString();
    }

    // A shade between black (0%) and Theme.GREY (100%) for a cloud cover percentage.
    // It is a ramp of the one grey, not extra palette colours.
    function greyLevel(pct as Number) as Number {
        var p = pct < 0 ? 0 : (pct > 100 ? 100 : pct);
        var v = p * (Theme.GREY & 0xFF) / 100;
        return (v << 16) | (v << 8) | v;
    }

    // "23:05" on a 24 hour watch, "11:05p" on a 12 hour one.
    function clockText(hour as Number, min as Number, is24 as Boolean) as String {
        if (is24) {
            return hour.format("%02d") + ":" + min.format("%02d");
        }
        var h12 = hour % 12;
        if (h12 == 0) { h12 = 12; }
        return h12.toString() + ":" + min.format("%02d") + (hour >= 12 ? "p" : "a");
    }
}
