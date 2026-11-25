import Toybox.Lang;
import Toybox.Test;
import Toybox.Weather;

(:test)
function precipSnowAndMixesAreFrozen(logger as Test.Logger) as Boolean {
    Test.assert(Precip.isFrozen(Weather.CONDITION_SNOW));
    Test.assert(Precip.isFrozen(Weather.CONDITION_LIGHT_SNOW));
    Test.assert(Precip.isFrozen(Weather.CONDITION_HEAVY_SNOW));
    Test.assert(Precip.isFrozen(Weather.CONDITION_FLURRIES));
    Test.assert(Precip.isFrozen(Weather.CONDITION_RAIN_SNOW));
    Test.assert(Precip.isFrozen(Weather.CONDITION_WINTRY_MIX));
    Test.assert(Precip.isFrozen(Weather.CONDITION_SLEET));
    Test.assert(Precip.isFrozen(Weather.CONDITION_FREEZING_RAIN));
    return true;
}

(:test)
function precipRainAndDryAreNotFrozen(logger as Test.Logger) as Boolean {
    Test.assert(!Precip.isFrozen(Weather.CONDITION_RAIN));
    Test.assert(!Precip.isFrozen(Weather.CONDITION_LIGHT_RAIN));
    Test.assert(!Precip.isFrozen(Weather.CONDITION_SHOWERS));
    Test.assert(!Precip.isFrozen(Weather.CONDITION_THUNDERSTORMS));
    Test.assert(!Precip.isFrozen(Weather.CONDITION_CLEAR));
    Test.assert(!Precip.isFrozen(null));
    return true;
}
