import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class GarminAppBackyardApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    private var mDelegate as GarminAppBackyardDelegate?;

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new GarminAppBackyardView();
        mDelegate = new GarminAppBackyardDelegate(view);
        return [ view, mDelegate ];
    }

    function getDelegate() as GarminAppBackyardDelegate? {
        return mDelegate;
    }

}

function getApp() as GarminAppBackyardApp {
    return Application.getApp() as GarminAppBackyardApp;
}
