import Toybox.Lang;
import Toybox.Test;

(:test)
function navOpensOnTheDetailPage(logger as Test.Logger) as Boolean {
    var nav = new PageNav();
    Test.assert(!nav.isOpen());
    nav.open(:hr);
    Test.assert(nav.isOpen());
    Test.assertEqual(nav.page, :hr);
    Test.assertEqual(nav.sub, 0);
    return true;
}

(:test)
function navRightGoesToGraphLeftComesBack(logger as Test.Logger) as Boolean {
    var nav = new PageNav();
    nav.open(:hr);
    nav.tap(400, 240, 448);
    Test.assertEqual(nav.sub, 1);
    nav.tap(400, 240, 448);               // already on the graph: stays
    Test.assertEqual(nav.sub, 1);
    nav.tap(20, 240, 448);                // back to the detail page
    Test.assertEqual(nav.sub, 0);
    Test.assertEqual(nav.page, :hr);
    nav.tap(20, 240, 448);                // back again: nothing to return to, so close
    Test.assert(!nav.isOpen());
    return true;
}

(:test)
function navCentreTapDoesNothing(logger as Test.Logger) as Boolean {
    var nav = new PageNav();
    nav.open(:weather);
    nav.tap(224, 240, 448);
    Test.assertEqual(nav.page, :weather);
    Test.assertEqual(nav.sub, 0);
    return true;
}

(:test)
function navTopStripCloses(logger as Test.Logger) as Boolean {
    var nav = new PageNav();
    nav.open(:steps);
    nav.tap(224, 30, 448);
    Test.assert(!nav.isOpen());
    return true;
}

(:test)
function navActivityRowsOpenTheirMetric(logger as Test.Logger) as Boolean {
    var kinds = [:steps, :active, :body];
    var ys = [150, 250, 350];
    for (var i = 0; i < 3; i++) {
        var nav = new PageNav();
        nav.open(:activity);
        nav.tap(224, ys[i], 448);
        Test.assertEqual(nav.page, kinds[i]);
        Test.assertEqual(nav.from, :activity);
        Test.assertEqual(nav.sub, 0);
    }
    return true;
}

(:test)
function navActivityTapOutsideRowsCloses(logger as Test.Logger) as Boolean {
    var nav = new PageNav();
    nav.open(:activity);
    nav.tap(224, 80, 448);                // between the top strip and the first row
    Test.assert(!nav.isOpen());
    nav.open(:activity);
    nav.tap(224, 420, 448);               // below the last row
    Test.assert(!nav.isOpen());
    return true;
}

(:test)
function navBackFromAMetricReturnsToActivity(logger as Test.Logger) as Boolean {
    var nav = new PageNav();
    nav.open(:activity);
    nav.tap(224, 150, 448);               // Steps, opened from Activity
    nav.tap(400, 240, 448);               // forward to the graph
    Test.assertEqual(nav.sub, 1);
    nav.tap(20, 240, 448);                // graph -> detail
    Test.assertEqual(nav.page, :steps);
    Test.assertEqual(nav.sub, 0);
    nav.tap(20, 240, 448);                // detail -> Activity
    Test.assertEqual(nav.page, :activity);
    Test.assert(nav.from == null);
    nav.tap(224, 30, 448);                // top strip closes
    Test.assert(!nav.isOpen());
    return true;
}

(:test)
function navIgnoresTapsWhenClosed(logger as Test.Logger) as Boolean {
    var nav = new PageNav();
    nav.tap(400, 240, 448);
    Test.assert(!nav.isOpen());
    return true;
}

(:test)
function navPageCounts(logger as Test.Logger) as Boolean {
    Test.assertEqual(PageNav.subCount(:activity), 1);
    Test.assertEqual(PageNav.subCount(:steps), 2);
    Test.assertEqual(PageNav.subCount(:hr), 2);
    Test.assertEqual(PageNav.subCount(:weather), 2);
    Test.assertEqual(PageNav.subCount(:body), 3);       // the sensor temperature page
    return true;
}

(:test)
function navBodyHasAThirdPage(logger as Test.Logger) as Boolean {
    var nav = new PageNav();
    nav.open(:body);
    nav.tap(400, 240, 448);
    Test.assertEqual(nav.sub, 1);
    nav.tap(400, 240, 448);
    Test.assertEqual(nav.sub, 2);
    nav.tap(400, 240, 448);               // no fourth page
    Test.assertEqual(nav.sub, 2);
    nav.tap(20, 240, 448);
    Test.assertEqual(nav.sub, 1);
    return true;
}

(:test)
function navOtherPagesStopAtTheGraph(logger as Test.Logger) as Boolean {
    var nav = new PageNav();
    nav.open(:steps);
    nav.tap(400, 240, 448);
    nav.tap(400, 240, 448);
    Test.assertEqual(nav.sub, 1);
    return true;
}
