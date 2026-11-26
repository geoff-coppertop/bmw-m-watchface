import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

// Temperature in the units the wearer wants. One setting, "Units" (Garmin Connect app settings):
// Auto follows the watch's temperature units, Metric (°C) or Imperial (°F) override it.
// Everything below the "pure" section is plain arithmetic, covered by source/tests/UnitsTests.mc.
module Units {
    const AUTO = 0;
    const METRIC = 1;
    const IMPERIAL = 2;

    // ---- resolving: the setting and the watch --------------------------------------

    function choice() as Number {
        var v = null;
        try {
            v = Application.Properties.getValue("Units");
        } catch (e) {
            // setting unavailable: behave as Auto
        }
        return (v instanceof Number) ? v : AUTO;
    }

    function tempImperial() as Boolean {
        return resolve(choice(), System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE);
    }

    // ---- pure -----------------------------------------------------------------------

    // The Units setting against what the watch is set to: Auto follows the watch.
    function resolve(setting as Number, watchImperial as Boolean) as Boolean {
        if (setting == IMPERIAL) { return true; }
        if (setting == METRIC) { return false; }
        return watchImperial;
    }

    function toFahrenheit(c as Numeric) as Float {
        return c * 9.0 / 5.0 + 32.0;
    }

    // Round to the nearest whole number (halves away from zero).
    function round(x as Float) as Number {
        return (x < 0 ? x - 0.5 : x + 0.5).toNumber();
    }

    // A Celsius temperature as a whole number in the chosen unit.
    function temp(c as Numeric, imperial as Boolean) as Number {
        return round(imperial ? toFahrenheit(c) : c.toFloat());
    }

    function tempUnit(imperial as Boolean) as String {
        return imperial ? "°F" : "°C";
    }
}
