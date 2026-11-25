import Toybox.Lang;
import Toybox.Weather;

// Tells snow and other frozen precipitation apart from rain, from the forecast's
// condition code, so the weather graph can colour the two differently.
// See source/tests/PrecipTests.mc.
module Precip {

    // True for snow, flurries, sleet, hail, ice, freezing rain, or a rain/snow or
    // wintry mix. False for rain, showers, storms, anything dry, and null.
    function isFrozen(c as Number or Null) as Boolean {
        if (c == null) { return false; }
        if (c == Weather.CONDITION_SNOW || c == Weather.CONDITION_LIGHT_SNOW
            || c == Weather.CONDITION_HEAVY_SNOW || c == Weather.CONDITION_CHANCE_OF_SNOW
            || c == Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW || c == Weather.CONDITION_FLURRIES) {
            return true;
        }
        if (c == Weather.CONDITION_RAIN_SNOW || c == Weather.CONDITION_LIGHT_RAIN_SNOW
            || c == Weather.CONDITION_HEAVY_RAIN_SNOW || c == Weather.CONDITION_CHANCE_OF_RAIN_SNOW
            || c == Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW || c == Weather.CONDITION_ICE_SNOW
            || c == Weather.CONDITION_WINTRY_MIX) {
            return true;
        }
        return c == Weather.CONDITION_SLEET || c == Weather.CONDITION_HAIL
            || c == Weather.CONDITION_ICE || c == Weather.CONDITION_FREEZING_RAIN;
    }
}
