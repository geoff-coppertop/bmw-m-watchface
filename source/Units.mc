import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

// Temperature, distance and wind speed in the units the wearer wants. One setting, "Units"
// (Garmin Connect app settings): Auto follows the watch, Metric or Imperial override it for
// temperature, distance and wind together. In Auto each quantity follows its own watch setting
// exactly as before (temperature from the temperature units, distance and wind from the
// distance units). The 12/24 hour clock always follows the watch. Everything below the
// "resolving" section is pure arithmetic and is covered by source/tests/UnitsTests.mc.
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

    function distImperial() as Boolean {
        return resolve(choice(), System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE);
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

    // Metres per second as km/h or mph, whole numbers.
    function windSpeed(metersPerSecond as Numeric, imperial as Boolean) as Number {
        return round(metersPerSecond * (imperial ? 2.23694 : 3.6));
    }

    function windUnit(imperial as Boolean) as String {
        return imperial ? "mph" : "km/h";
    }

    // Centimetres as "4.7 km" or "2.9 mi".
    function distanceText(cm as Numeric, imperial as Boolean) as String {
        if (imperial) {
            return (cm / 160934.0).format("%.1f") + " mi";
        }
        return (cm / 100000.0).format("%.1f") + " km";
    }
}
