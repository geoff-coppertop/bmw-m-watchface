import Toybox.Lang;

// Series builders for the unit tests. Plain functions, no assertions, so they are
// harmless in a release build.
module TestData {

    // 48 half-hour buckets of heart rate: 72 bpm by day, 52 bpm from bucket s up to e.
    function hrNight(s as Number, e as Number) as Array<Numeric or Null> {
        var a = new [48] as Array<Numeric or Null>;
        for (var i = 0; i < 48; i++) {
            a[i] = (i >= s && i < e) ? 52 : 72;
        }
        return a;
    }

    function flat(v as Numeric or Null) as Array<Numeric or Null> {
        var a = new [48] as Array<Numeric or Null>;
        for (var i = 0; i < 48; i++) {
            a[i] = v;
        }
        return a;
    }

    // Body battery gaining 4 points per bucket from s up to e, otherwise 80.
    function bbRising(s as Number, e as Number) as Array<Numeric or Null> {
        var a = new [48] as Array<Numeric or Null>;
        for (var i = 0; i < 48; i++) {
            a[i] = (i >= s && i < e) ? 34 + (i - s) * 4 : 80;
        }
        return a;
    }

    // Body battery draining one point per bucket, from 90.
    function bbFalling() as Array<Numeric or Null> {
        var a = new [48] as Array<Numeric or Null>;
        for (var i = 0; i < 48; i++) {
            a[i] = 90 - i;
        }
        return a;
    }
}
