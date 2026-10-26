import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.FitContributor;
import Toybox.Lang;
import Toybox.Position;
import Toybox.WatchUi;

class GarminAppBackyardDelegate extends WatchUi.BehaviorDelegate {

    private var mView as GarminAppBackyardView;
    private var mSession as ActivityRecording.Session?;
    private var mPositionEnabled as Boolean = false;

    // Champs FIT personnalisés par circuit (Lap)
    private var mFitRestField as FitContributor.Field?;
    private var mFitWalkField as FitContributor.Field?;
    private var mFitRunField as FitContributor.Field?;

    // Métriques courantes du tour
    private var mLoopWalkTimeSec as Number = 0;
    private var mLoopRunTimeSec as Number = 0;
    private var mLoopRestTimeSec as Number = 0;

    function initialize(view as GarminAppBackyardView) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function startLocationTracking() as Void {
        if (!mPositionEnabled && (Toybox has :Position)) {
            mPositionEnabled = true;
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        }
    }

    function stopLocationTracking() as Void {
        if (mPositionEnabled && (Toybox has :Position)) {
            mPositionEnabled = false;
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        }
    }

    function onPosition(info as Position.Info) as Void {
        if (info != null) {
            var isGpsReady = (info.accuracy != null && info.accuracy >= Position.QUALITY_USABLE);
            mView.setGpsReady(isGpsReady);
        }
    }

    // Démarrage ou pause manuelle de la session avec menu d'options (Enregistrer / Reprendre / Ignorer)
    function onSelect() as Boolean {
        if (Toybox has :ActivityRecording) {
            if (mSession == null) {
                mSession = ActivityRecording.createSession({
                    :name => "Backyard Ultra",
                    :sport => Activity.SPORT_RUNNING,
                    :subSport => Activity.SUB_SPORT_GENERIC
                });

                // Création des 3 champs de métriques par tour dans Garmin Connect
                mFitRestField = mSession.createField(
                    "rest_time",
                    0,
                    FitContributor.DATA_TYPE_UINT32,
                    { :mesgType => FitContributor.MESG_TYPE_LAP, :units => "s" }
                );
                mFitWalkField = mSession.createField(
                    "walk_time",
                    1,
                    FitContributor.DATA_TYPE_UINT32,
                    { :mesgType => FitContributor.MESG_TYPE_LAP, :units => "s" }
                );
                mFitRunField = mSession.createField(
                    "run_time",
                    2,
                    FitContributor.DATA_TYPE_UINT32,
                    { :mesgType => FitContributor.MESG_TYPE_LAP, :units => "s" }
                );

                mSession.start();
                mView.startSessionTimer();
            } else if (mSession.isRecording()) {
                // Pause de l'enregistrement et affichage du menu d'action
                mSession.stop();
                showStopMenu();
            } else {
                // Si la session était déjà en pause manuelle, ré-afficher le menu
                showStopMenu();
            }
        }
        WatchUi.requestUpdate();
        return true;
    }

    private function showStopMenu() as Void {
        var menu = new WatchUi.Menu();
        menu.setTitle("Session");
        menu.addItem("Reprendre", :resume);
        menu.addItem("Enregistrer", :save);
        menu.addItem("Ignorer", :discard);
        WatchUi.pushView(menu, new BackyardMenuDelegate(self), WatchUi.SLIDE_UP);
    }

    function resumeSession() as Void {
        if (mSession != null && !mSession.isRecording()) {
            mSession.start();
            WatchUi.requestUpdate();
        }
    }

    function saveSession() as Void {
        if (mSession != null) {
            if (mSession.isRecording()) {
                mSession.stop();
            }
            mSession.save();
            mSession = null;
        }
        Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function discardSession() as Void {
        if (mSession != null) {
            if (mSession.isRecording()) {
                mSession.stop();
            }
            mSession.discard();
            mSession = null;
        }
        Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    // Accumulation à 1 Hz des secondes de marche vs course
    function recordActivitySecond(isWalking as Boolean, isResting as Boolean) as Void {
        if (isResting) {
            mLoopRestTimeSec++;
        } else if (isWalking) {
            mLoopWalkTimeSec++;
        } else {
            mLoopRunTimeSec++;
        }
    }

    // Mise en pause dès 6,706 km atteints
    function pauseRecordingForRest() as Void {
        if (mSession != null && mSession.isRecording()) {
            mSession.stop();
        }
    }

    // Finalisation du Lap FIT horaire avec injection des 3 métriques
    function startNextHourlyLoop() as Void {
        if (mSession != null) {
            if (mFitRestField != null) {
                mFitRestField.setData(mLoopRestTimeSec);
            }
            if (mFitWalkField != null) {
                mFitWalkField.setData(mLoopWalkTimeSec);
            }
            if (mFitRunField != null) {
                mFitRunField.setData(mLoopRunTimeSec);
            }

            mSession.addLap();

            // Réinitialisation des compteurs pour la nouvelle boucle
            mLoopWalkTimeSec = 0;
            mLoopRunTimeSec = 0;
            mLoopRestTimeSec = 0;

            if (!mSession.isRecording()) {
                mSession.start();
            }
        }
    }

    // Bouton DOWN / NEXT PAGE
    function onNextPage() as Boolean {
        mView.toggleScreen();
        return true;
    }

    // Bouton UP / PREVIOUS PAGE
    function onPreviousPage() as Boolean {
        mView.toggleScreen();
        return true;
    }

    // Bouton BACK : Sauvegarde finale de l'épreuve
    function onBack() as Boolean {
        if (mSession != null) {
            if (mSession.isRecording()) {
                mSession.stop();
                showStopMenu();
                return true;
            }
        }
        return false;
    }

}

class BackyardMenuDelegate extends WatchUi.MenuInputDelegate {

    private var mDelegate as GarminAppBackyardDelegate;

    function initialize(delegate as GarminAppBackyardDelegate) {
        MenuInputDelegate.initialize();
        mDelegate = delegate;
    }

    function onMenuItem(item as Symbol) as Void {
        if (item == :resume) {
            mDelegate.resumeSession();
        } else if (item == :save) {
            mDelegate.saveSession();
        } else if (item == :discard) {
            mDelegate.discardSession();
        }
    }

}
