import Toybox.Lang;

// What a quick card shows: a label and a value per row, and optionally a ring colour per row (the
// activity card). Built by Cards.build (which reads the watch) and painted by Cards.draw (which
// does not).
class CardContent {
    var names as Array<String>;
    var vals as Array<String>;
    var colors as Array<Number> or Null;

    function initialize(names as Array<String>, vals as Array<String>, colors as Array<Number> or Null) {
        self.names = names;
        self.vals = vals;
        self.colors = colors;
    }
}
