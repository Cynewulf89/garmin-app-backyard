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

    // Constante : distance exacte d'un tour Backyard Ultra (6,706 km)
    private const LOOP_DISTANCE_METERS = 6706.0;

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

        // Détection du changement d'heure pile (reset strict chaque 3600 secondes)
        var currentLoopIndex = totalElapsedSec / 3600;
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

        // Distance relative au tour courant (plafonnée à 6,706 km)
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
                var lSec = totalElapsedSec % 3600;
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

        mLoopDistStr = Lang.format("$1$ km", [loopDistKm.format("%.2f")]);
        mTotalDistStr = Lang.format("$1$ km", [totalDistKm.format("%.2f")]);
        mLoopNumStr = Lang.format("$1$", [currentLoopNum]);

        // Temps écoulé dans l'heure courante (0 à 3599 s)
        var loopTimeSec = totalElapsedSec % 3600;

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
            var restTimeSec = 3600 - loopTimeSec;
            var rMin = restTimeSec / 60;
            var rSec = restTimeSec % 60;
            mRestCountdownStr = Lang.format("$1$:$2$", [rMin.format("%02d"), rSec.format("%02d")]);

            // Alarme vibration unique à 1 minute avant de reprendre le tour (restTimeSec <= 60)
            if (restTimeSec <= 60 && !mVibeAlertTriggered) {
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

            // Delta avance/retard calculé par rapport à la vitesse seuil Backyard (6,706 km en 3600s)
            var expectedTimeSec = (loopDist / (LOOP_DISTANCE_METERS / 3600.0)).toNumber();
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

    // Écran 1 : Course (Allure/Distance/Delta) OU Repos dédié (1/3 TOUR TERMINÉ, 2/3 REPOS)
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

            // --- 1/4 HAUT (Fond noir) ---
            var loopLabel = (mCompletedLoopsCount > 1)
                ? Lang.format("$1$ TOURS TERMINÉS", [mCompletedLoopsCount])
                : (mCompletedLoopsCount == 1 ? "1 TOUR TERMINÉ" : "TOUR TERMINÉ");

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, (height * 0.05).toNumber(), Graphics.FONT_XTINY, loopLabel, Graphics.TEXT_JUSTIFY_CENTER);

            // Chrono du tour avec petite icône chronomètre ⏱️ vectorielle
            var timeFont = Graphics.FONT_SMALL;
            var timeDims = dc.getTextDimensions(mLastLoopTimeStr, timeFont);
            var textWidth = timeDims[0];
            var iconRadius = 4;
            var gap = 5;
            var totalBlockWidth = (iconRadius * 2) + gap + textWidth;
            var startX = centerX - (totalBlockWidth / 2);
            var chronoY = (height * 0.13).toNumber();

            // Dessin icône chronomètre
            var iconCenterX = startX + iconRadius;
            var iconCenterY = chronoY + (timeDims[1] / 2);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(iconCenterX, iconCenterY, iconRadius);
            dc.drawLine(iconCenterX, iconCenterY - iconRadius - 2, iconCenterX, iconCenterY - iconRadius);
            dc.drawLine(iconCenterX, iconCenterY, iconCenterX, iconCenterY - 2);

            // Temps du tour
            dc.drawText(startX + (iconRadius * 2) + gap, chronoY, timeFont, mLastLoopTimeStr, Graphics.TEXT_JUSTIFY_LEFT);

            // --- 3/4 BAS (Fond blanc) ---
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, (height * 0.35).toNumber(), Graphics.FONT_TINY, "TEMPS DE REPOS", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(centerX, (height * 0.48).toNumber(), Graphics.FONT_NUMBER_HOT, mRestCountdownStr, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            // Indicateur de statut GPS tout en haut (Cercle vert = FIX OK, Rouge = Recherche)
            var gpsDotY = (height * 0.04).toNumber();
            var gpsColor = mIsGpsReady ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;
            dc.setColor(gpsColor, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(centerX, gpsDotY, 3);

            // Mode Course normal : 3 zones bien équilibrées pour écran rond
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawLine(25, (height * 0.35).toNumber(), width - 25, (height * 0.35).toNumber());
            dc.drawLine(25, (height * 0.67).toNumber(), width - 25, (height * 0.67).toNumber());

            // Zone 1 : Allure moyenne
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, (height * 0.10).toNumber(), Graphics.FONT_XTINY, "ALLURE MOY.", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, (height * 0.18).toNumber(), Graphics.FONT_MEDIUM, mPaceStr, Graphics.TEXT_JUSTIFY_CENTER);

            // Zone 2 : Distance boucle
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, (height * 0.40).toNumber(), Graphics.FONT_XTINY, "DISTANCE", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, (height * 0.49).toNumber(), Graphics.FONT_LARGE, mLoopDistStr, Graphics.TEXT_JUSTIFY_CENTER);

            // Zone 3 : Avance / Retard
            var deltaLabel = mIsAhead ? "AVANCE" : "RETARD";
            var deltaColor = mIsAhead ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;
            dc.setColor(deltaColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, (height * 0.71).toNumber(), Graphics.FONT_XTINY, deltaLabel, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(centerX, (height * 0.79).toNumber(), Graphics.FONT_MEDIUM, mDeltaStr, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Écran 2 : Batterie & Heure en haut, Tour & Distance, Grand Temps Total en bas
    private function drawScreenTwo(dc as Graphics.Dc, width as Number, height as Number, centerX as Number) as Void {
        // En haut : Icône batterie + pourcentage
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        var battX = centerX - 26;
        var battY = (height * 0.05).toNumber();
        dc.drawRectangle(battX, battY, 18, 9);
        dc.fillRectangle(battX + 18, battY + 2, 2, 5);
        dc.drawText(centerX + 6, battY - 3, Graphics.FONT_XTINY, mBatteryStr, Graphics.TEXT_JUSTIFY_LEFT);

        // Heure actuelle juste sous la batterie
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 0.12).toNumber(), Graphics.FONT_XTINY, mClockTimeStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Séparateur supérieur (sous la zone supérieure)
        var lineY = (height * 0.44).toNumber();
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(20, lineY, width - 20, lineY);

        // Séparateur vertical entre Tour et KM Total
        dc.drawLine(centerX, (height * 0.23).toNumber(), centerX, lineY);

        // Zone Tour
        var leftX = width * 0.28;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftX.toNumber(), (height * 0.24).toNumber(), Graphics.FONT_XTINY, "TOUR", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftX.toNumber(), (height * 0.31).toNumber(), Graphics.FONT_MEDIUM, mLoopNumStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Zone Distance (adaptée aux centaines de km sans déborder)
        var rightX = width * 0.72;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightX.toNumber(), (height * 0.24).toNumber(), Graphics.FONT_XTINY, "TOTAL KM", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightX.toNumber(), (height * 0.31).toNumber(), Graphics.FONT_SMALL, mTotalDistStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Bas : Grand affichage TEMPS TOTAL parfaitement calé dans l'arc inférieur
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 0.49).toNumber(), Graphics.FONT_TINY, "TEMPS TOTAL", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 0.59).toNumber(), Graphics.FONT_NUMBER_MEDIUM, mTotalTimeStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

}
