import Toybox.Activity;
import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

class GarminAppBackyardView extends WatchUi.View {

    // Configuration de Test Rapide : 250 mètres / 2.5 minutes (150 secondes) par tour
    private const LOOP_DISTANCE_METERS = 250.0;
    private const LOOP_PERIOD_SECONDS = 150;

    // Écran actif : 1 ou 2
    private var mCurrentScreen as Number = 1;

    // Métriques calculées Écran 1
    private var mPaceStr as String = "--:--";
    private var mLoopDistStr as String = "0.00 km";
    private var mDeltaStr as String = "00:00";
    private var mIsAhead as Boolean = true;

    // Métriques calculées Écran 2
    private var mLoopNumStr as String = "1";
    private var mTotalDistStr as String = "0.00 km";
    private var mTotalTimeStr as String = "00:00:00";
    private var mBatteryStr as String = "--%";
    private var mRestCountdownStr as String = "00:00";
    private var mCompletedLoopsCount as Number = 0;
    private var mLastLoopTimeStr as String = "00:00";
    private var mClockTimeStr as String = "--:--";

    private var mIsLoopPaused as Boolean = false;
    private var mVibeAlertTriggered as Boolean = false;
    private var mIsGpsReady as Boolean = false;
    private var mGpsVibeDone as Boolean = false;

    // Timer de rafraîchissement d'interface (1 Hz)
    private var mTimer as Timer.Timer?;

    function initialize() {
        View.initialize();
    }

    function setGpsReady(ready as Boolean) as Void {
        mIsGpsReady = ready;
        if (ready && !mGpsVibeDone) {
            mGpsVibeDone = true;
            // Courte vibration indiquant le fix GPS acquis
            if (Attention has :vibrate) {
                var vibe = [ new Attention.VibeProfile(50, 200) ];
                Attention.vibrate(vibe);
            }
        }
        WatchUi.requestUpdate();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
        if (mTimer == null) {
            mTimer = new Timer.Timer();
            mTimer.start(method(:onTimerTick), 1000, true);
        }
        var app = getApp();
        if (app != null && app.getDelegate() != null) {
            app.getDelegate().startLocationTracking();
        }
    }

    function onHide() as Void {
        if (mTimer != null) {
            mTimer.stop();
            mTimer = null;
        }
        var app = getApp();
        if (app != null && app.getDelegate() != null) {
            app.getDelegate().stopLocationTracking();
        }
    }

    function onTimerTick() as Void {
        updateData();
        WatchUi.requestUpdate();
    }

    // Bascule d'écran déclenchée par le Delegate (boutons)
    function toggleScreen() as Void {
        if (mCurrentScreen == 1) {
            mCurrentScreen = 2;
        } else {
            mCurrentScreen = 1;
        }
        WatchUi.requestUpdate();
    }

    // Timestamp Epoch (s) du démarrage de la session
    private var mSessionStartEpochSec as Number = 0;

    function startSessionTimer() as Void {
        if (mSessionStartEpochSec == 0) {
            mSessionStartEpochSec = Time.now().value();
        }
    }

    // Offset de distance cumulée au début du tour courant
    private var mLastCompletedLoopIndex as Number = 0;
    private var mLoopStartDistanceMeters as Double = 0.0;

    private function updateData() as Void {
        // Heure actuelle
        var clock = System.getClockTime();
        if (clock != null) {
            mClockTimeStr = Lang.format("$1$:$2$", [
                clock.hour.format("%02d"),
                clock.min.format("%02d")
            ]);
        }

        // Niveau de batterie
        var stats = System.getSystemStats();
        if (stats != null && stats.battery != null) {
            mBatteryStr = Lang.format("$1$%", [stats.battery.toNumber()]);
        }

        var info = Activity.getActivityInfo();

        // Temps total ininterrompu basé sur l'heure absolue de début de session
        var totalElapsedSec = 0;
        if (mSessionStartEpochSec > 0) {
            totalElapsedSec = Time.now().value() - mSessionStartEpochSec;
            if (totalElapsedSec < 0) {
                totalElapsedSec = 0;
            }
        } else if (info != null) {
            if (info.elapsedTime != null && info.elapsedTime > 0) {
                mSessionStartEpochSec = Time.now().value() - (info.elapsedTime / 1000).toNumber();
                totalElapsedSec = (info.elapsedTime / 1000).toNumber();
            } else if (info.timerTime != null && info.timerTime > 0) {
                mSessionStartEpochSec = Time.now().value() - (info.timerTime / 1000).toNumber();
                totalElapsedSec = (info.timerTime / 1000).toNumber();
            }
        }

        if (info == null) {
            return;
        }

        // Détection du changement de tour (reset strict chaque LOOP_PERIOD_SECONDS)
        var currentLoopIndex = totalElapsedSec / LOOP_PERIOD_SECONDS;
        var totalDist = (info.elapsedDistance != null) ? info.elapsedDistance.toDouble() : 0.0;

        var isLoopFinished = false;

        if (currentLoopIndex > mLastCompletedLoopIndex) {
            mLastCompletedLoopIndex = currentLoopIndex;
            mLoopStartDistanceMeters = totalDist;
            mIsLoopPaused = false;
            mVibeAlertTriggered = false;
            // Retour forcé sur l'écran 1 au départ du nouveau tour
            mCurrentScreen = 1;
            // Déclenche le lap horaire officiel et relance l'enregistrement GPS
            var app = getApp();
            if (app != null && app.getDelegate() != null) {
                app.getDelegate().startNextHourlyLoop();
            }
        }

        // Distance relative au tour courant (plafonnée à 250m en test)
        var loopDist = totalDist - mLoopStartDistanceMeters;
        if (loopDist >= LOOP_DISTANCE_METERS) {
            loopDist = LOOP_DISTANCE_METERS;
            isLoopFinished = true;
            if (!mIsLoopPaused) {
                mIsLoopPaused = true;
                // Bascule automatique sur l'écran 1 (qui affiche la pause) à l'arrivée
                mCurrentScreen = 1;
                mCompletedLoopsCount = currentLoopIndex + 1;
                // Calcul du chrono du tour terminé
                var lSec = totalElapsedSec % LOOP_PERIOD_SECONDS;
                var lMin = lSec / 60;
                var lRemainingSec = lSec % 60;
                mLastLoopTimeStr = Lang.format("$1$:$2$", [lMin.format("%02d"), lRemainingSec.format("%02d")]);

                var app = getApp();
                if (app != null && app.getDelegate() != null) {
                    app.getDelegate().pauseRecordingForRest();
                }
            }
        }
        if (loopDist < 0.0) {
            loopDist = 0.0;
        }

        var loopDistKm = loopDist / 1000.0;
        var totalDistKm = totalDist / 1000.0;
        var currentLoopNum = currentLoopIndex + 1;

        mLoopDistStr = loopDistKm.format("%.2f");
        mTotalDistStr = totalDistKm.format("%.2f");
        mLoopNumStr = Lang.format("$1$", [currentLoopNum]);

        // Temps écoulé dans le tour courant (0 à LOOP_PERIOD_SECONDS - 1)
        var loopTimeSec = totalElapsedSec % LOOP_PERIOD_SECONDS;

        // Évaluation Course vs Marche (seuil de cadence standard 145 spm ou vitesse de marche)
        var isWalking = false;
        if (!isLoopFinished) {
            if (info.currentCadence != null) {
                isWalking = (info.currentCadence > 40 && info.currentCadence < 145);
            } else if (info.currentSpeed != null) {
                isWalking = (info.currentSpeed > 0.4 && info.currentSpeed < 1.7);
            }
        }

        var app = getApp();
        if (app != null && app.getDelegate() != null) {
            app.getDelegate().recordActivitySecond(isWalking, isLoopFinished);
        }

        // Si la boucle est finie, affichage du temps de repos restant avant le prochain départ
        if (isLoopFinished) {
            var restTimeSec = LOOP_PERIOD_SECONDS - loopTimeSec;
            var rMin = restTimeSec / 60;
            var rSec = restTimeSec % 60;
            mRestCountdownStr = Lang.format("$1$:$2$", [rMin.format("%02d"), rSec.format("%02d")]);

            // Alarme vibration unique à 20 secondes avant de reprendre le tour (mode test 2.5 min)
            if (restTimeSec <= 20 && !mVibeAlertTriggered) {
                mVibeAlertTriggered = true;
                triggerOneMinuteAlert();
            }
        } else {
            // Allure moyenne réinitialisée pour la boucle en cours
            if (loopDistKm > 0.05 && loopTimeSec > 5) {
                var paceSecPerKm = (loopTimeSec / loopDistKm).toNumber();
                var paceMin = paceSecPerKm / 60;
                var paceSec = paceSecPerKm % 60;
                mPaceStr = Lang.format("$1$:$2$", [paceMin.format("%d"), paceSec.format("%02d")]);
            } else {
                mPaceStr = "--:--";
            }

            // Delta avance/retard calculé par rapport à la vitesse seuil de test
            var expectedTimeSec = (loopDist / (LOOP_DISTANCE_METERS / LOOP_PERIOD_SECONDS.toDouble())).toNumber();
            var deltaSec = expectedTimeSec - loopTimeSec;
            if (deltaSec >= 0) {
                mIsAhead = true;
                var dMin = deltaSec / 60;
                var dSec = deltaSec % 60;
                mDeltaStr = Lang.format("+$1$:$2$", [dMin.format("%02d"), dSec.format("%02d")]);
            } else {
                mIsAhead = false;
                var absDelta = -deltaSec;
                var dMin = absDelta / 60;
                var dSec = absDelta % 60;
                mDeltaStr = Lang.format("-$1$:$2$", [dMin.format("%02d"), dSec.format("%02d")]);
            }
        }

        // Temps total avec secondes (HH:MM:SS) pour l'Écran 2
        var totalHours = totalElapsedSec / 3600;
        var totalMinutes = (totalElapsedSec % 3600) / 60;
        var totalSeconds = totalElapsedSec % 60;
        mTotalTimeStr = Lang.format("$1$:$2$:$3$", [
            totalHours.format("%02d"),
            totalMinutes.format("%02d"),
            totalSeconds.format("%02d")
        ]);
    }

    // Déclenche une vibration pour avertir 1 minute avant le départ du nouveau tour
    private function triggerOneMinuteAlert() as Void {
        if (Attention has :vibrate) {
            var vibeData = [
                new Attention.VibeProfile(100, 500),
                new Attention.VibeProfile(0, 250),
                new Attention.VibeProfile(100, 500)
            ];
            Attention.vibrate(vibeData);
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (mCurrentScreen == 1) {
            drawScreenOne(dc, width, height, centerX);
        } else {
            drawScreenTwo(dc, width, height, centerX);
        }
    }

    // Écran 1 : Course (Allure/Distance/Delta) OU Repos dédié (Chrono tour / Repos géant) - Version Little (Données pures agrandies)
    private function drawScreenOne(dc as Graphics.Dc, width as Number, height as Number, centerX as Number) as Void {
        if (mIsLoopPaused) {
            // Mode Pause Dédié : 1/4 Haut (Fond Noir) & 3/4 Bas (Fond Blanc)
            var splitY = (height * 0.25).toNumber();

            // Fond blanc pour les 3/4 inférieurs
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
            dc.fillRectangle(0, splitY, width, height - splitY);

            // Ligne de démarcation
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawLine(0, splitY, width, splitY);

            // --- 1/4 HAUT (Fond noir) : Tour complété + Chrono du tour ---
            // Numéro de tour à gauche
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var loopNumText = Lang.format("$1$", [mCompletedLoopsCount]);
            dc.drawText((width * 0.28).toNumber(), (height * 0.13).toNumber(), Graphics.FONT_MEDIUM, loopNumText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            // Chrono du tour tout juste achevé à droite
            dc.drawText((width * 0.70).toNumber(), (height * 0.13).toNumber(), Graphics.FONT_MEDIUM, mLastLoopTimeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            // --- 3/4 BAS (Fond blanc) : Décompte géant sans texte parasite ---
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, (height * 0.60).toNumber(), Graphics.FONT_NUMBER_HOT, mRestCountdownStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            // Indicateur de statut GPS tout en haut (Cercle vert = FIX OK, Rouge = Recherche)
            var gpsDotY = (height * 0.04).toNumber();
            var gpsColor = mIsGpsReady ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;
            dc.setColor(gpsColor, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(centerX, gpsDotY, 3);

            // Mode Course : 3 zones de données pures agrandies au maximum sans déborder
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawLine(25, (height * 0.32).toNumber(), width - 25, (height * 0.32).toNumber());
            dc.drawLine(25, (height * 0.68).toNumber(), width - 25, (height * 0.68).toNumber());

            // Zone 1 : Allure boucle (centrée verticalement dans le tiers haut)
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, (height * 0.19).toNumber(), Graphics.FONT_LARGE, mPaceStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            // Zone 2 : Distance boucle (Chiffres géants centrés au milieu de l'écran)
            dc.drawText(centerX, (height * 0.50).toNumber(), Graphics.FONT_NUMBER_HOT, mLoopDistStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            // Zone 3 : Avance / Retard (centré verticalement dans le tiers bas)
            var deltaColor = mIsAhead ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;
            dc.setColor(deltaColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, (height * 0.81).toNumber(), Graphics.FONT_LARGE, mDeltaStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Écran 2 : Heure & Batterie côte à côte en haut (sans icône), Tour & Distance, Grand Temps Total en bas
    private function drawScreenTwo(dc as Graphics.Dc, width as Number, height as Number, centerX as Number) as Void {
        // En haut : Heure à gauche | % Batterie à droite (sans logo)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var topY = (height * 0.11).toNumber();
        dc.drawText((width * 0.35).toNumber(), topY, Graphics.FONT_MEDIUM, mClockTimeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText((width * 0.67).toNumber(), topY, Graphics.FONT_MEDIUM, mBatteryStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Séparateur horizontal supérieur
        var topLineY = (height * 0.21).toNumber();
        var midLineY = (height * 0.48).toNumber();
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(35, topLineY, width - 35, topLineY);
        dc.drawLine(20, midLineY, width - 20, midLineY);

        // Séparateur vertical entre Tour et KM Total
        dc.drawLine(centerX, topLineY, centerX, midLineY);

        // Zone Tour (Donnée seule agrandie)
        var leftX = width * 0.28;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftX.toNumber(), (height * 0.34).toNumber(), Graphics.FONT_LARGE, mLoopNumStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Zone Distance totale (Donnée seule agrandie sans "km")
        var rightX = width * 0.72;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightX.toNumber(), (height * 0.34).toNumber(), Graphics.FONT_LARGE, mTotalDistStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Bas : Grand affichage TEMPS TOTAL (FONT_NUMBER_MEDIUM respecte l'arc inférieur sur 8 caractères HH:MM:SS)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 0.69).toNumber(), Graphics.FONT_NUMBER_MEDIUM, mTotalTimeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

}
