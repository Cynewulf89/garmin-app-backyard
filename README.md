# Garmin Backyard Ultra App - Mode Test (250m / 2.5 min)

Version de test accélérée de l'application Connect IQ Backyard Ultra pour valider le comportement en situation réelle.

---

## ⚡ Paramètres du Mode Test

- **Distance par tour** : **250 mètres** (au lieu de 6,706 km).
- **Durée par tour** : **2.5 minutes** (150 secondes, au lieu de 60 minutes).
- **Alerte départ** : Vibration à **20 secondes** avant le départ du tour suivant.

---

## 📱 Fonctionnement & Écrans

### 1. Écran 1 (Course & Repos)
- **Pendant le tour (0 à 250 m)** :
  - **Allure moyenne** sur le tour en cours.
  - **Distance** parcourue sur le tour.
  - **Avance / Retard** (vert si en avance pour boucler en < 5 min, rouge si en retard).
- **Fin de tour (dès 250 m atteints)** :
  - **Bascule automatique** sur l'affichage de pause (que vous soyez sur l'écran 1 ou l'écran 2).
  - Haut : Nombre de tours terminés + chrono du tour achevé.
  - Bas : **Décompte du temps de repos restant** jusqu'aux 5:00.
  - Pause automatique de la trace GPS pendant le repos.
- **Nouveau départ (à 5 min pile)** :
  - **Bascule automatique** vers l'écran 1 en mode course.
  - Reprise automatique de la trace GPS et remise à zéro de la distance du tour.

### 2. Écran 2 (Statistiques Globales)
- Accessible via les touches **UP / DOWN**.
- **Batterie** (%) et **Heure actuelle** en haut.
- **Numéro du tour** et **Distance totale cumulée**.
- **Temps total ininterrompu** (ne s'arrête jamais lors des pauses de session ou de fin de boucle).

---

## 🎮 Contrôles

- **START / STOP** : Lancer l'activité / Menu de fin de session (Reprendre, Enregistrer, Ignorer).
- **UP / DOWN** : Alterner entre Écran 1 et Écran 2.
- **BACK** : Pause et menu de clôture d'activité.
