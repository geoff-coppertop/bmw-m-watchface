import Toybox.Lang;

// Small pure helpers for the quick cards and the battery icon. Nothing here touches the watch
// APIs, so all of it can be unit tested (source/tests/StatsTests.mc).
module Stats {

    // Below 20% the battery icon turns red.
    function isLowBattery(pct as Number) as Boolean {
        return pct < 20;
    }

    // A value held in tenths as text with one decimal: 341 -> "34.1", -12 -> "-1.2".
    function tenthsText(t as Number) as String {
        var a = t < 0 ? -t : t;
        return (t < 0 ? "-" : "") + (a / 10).toString() + "." + (a % 10).toString();
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
        if (score <= 25) { return "resting"; }
        if (score <= 50) { return "low"; }
        if (score <= 75) { return "medium"; }
        return "high";
    }
}
