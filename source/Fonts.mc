import Toybox.Graphics;
import Toybox.Lang;

// The four font roles, loaded once. label, value and title are vector fonts at the pixel sizes
// in Theme (so they can be smaller than the smallest system font); hero is the system numerals.
// A device without a vector font keeps the system fonts, so the face still draws.
class Fonts {
    static var label as Graphics.FontType = Graphics.FONT_XTINY;
    static var value as Graphics.FontType = Graphics.FONT_TINY;
    static var title as Graphics.FontType = Graphics.FONT_SMALL;
    static var hero as Graphics.FontType = Graphics.FONT_NUMBER_HOT;
    static var vector as Boolean = false;

    // Faces are tried in order: RobotoCondensedBold is on the Venu X1; RobotoRegular is what its
    // simulator offers. Names vary by device (see the Connect IQ device reference).
    static function load() as Void {
        if (!(Graphics has :getVectorFont)) { return; }
        var faces = ["RobotoCondensedBold", "RobotoRegular"];
        var l = Graphics.getVectorFont({ :face => faces, :size => Theme.FONT_PX_LABEL });
        var v = Graphics.getVectorFont({ :face => faces, :size => Theme.FONT_PX_VALUE });
        var t = Graphics.getVectorFont({ :face => faces, :size => Theme.FONT_PX_TITLE });
        if (l != null && v != null && t != null) {
            label = l;
            value = v;
            title = t;
            vector = true;
        }
    }
}
