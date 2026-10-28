# Garmin Backyard Ultra - Version Little (Chiffres Géants / Sans Texte) - Mode TEST

Application autonome (**Watch-App**) Connect IQ pour montres Garmin, édition **Little** (affichage minimaliste **100 % données pures sans libellés de texte** pour une taille de police maximale), configurée ici en **mode test rapide** (**250 mètres en 2,5 minutes** par boucle).

Lien du dépôt : [https://github.com/Cynewulf89/garmin-app-backyard](https://github.com/Cynewulf89/garmin-app-backyard)

---

## 📱 Aperçu des Écrans (Version Little - Chiffres Géants)

| Écran 1 (En Avance) | Écran 1 (En Retard) | Écran 1 (Repos / Terminé) | Écran 2 (Stats & Batterie) |
| :---: | :---: | :---: | :---: |
| ![Écran 1 Avance](screenshots/screen1_avance.jpg) | ![Écran 1 Retard](screenshots/screen1_retard.jpg) | ![Écran 1 Repos](screenshots/screen1_repos.jpg) | ![Écran 2 Total](screenshots/screen2_total.jpg) |

---

## ⚙️ Contrôles des Boutons & Enregistrement

- **Bouton START / STOP** : Démarre l'épreuve. Un nouvel appui met en pause l'activité et ouvre le menu natif pour **Reprendre**, **Enregistrer** ou **Ignorer**.
- **Boutons UP / DOWN** : Basculent entre l'**Écran 1** (gestion de la boucle) et l'**Écran 2** (statistiques globales).
- **Bouton BACK** : Met en pause et ouvre également le menu de clôture d'activité si une session est active.

### Écran 1 : Gestion de la Boucle (Affichage Géant Sans Texte)

Tous les intitulés (`ALLURE MOY.`, `DISTANCE`, `AVANCE`/`RETARD`) sont supprimés pour afficher les données le plus gros possible :

- **Haut (`FONT_LARGE`)** : Allure moyenne sur la boucle en cours (`MM:SS`).
- **Milieu (`FONT_NUMBER_HOT`)** : Distance parcourue sur la boucle actuelle en chiffres géants purs sans unité (`0.00` à `0.25`).
- **Bas (`FONT_LARGE`)** : Avance (**Vert `+MM:SS`**) ou Retard (**Rouge `-MM:SS`**) par rapport à la cible.
- **Réinitialisation automatique** : Remise à zéro et bascule sur l'Écran 1 à chaque nouveau départ (toutes les 2 min 30 en mode test).

### Écran de Pause automatique (Dès 250 m atteints en mode test)

- **Déclenchement automatique** : Dès que la distance cible du tour est atteinte, l'enregistrement GPS se met en pause et l'écran bascule automatiquement sur l'affichage de repos.
- **Quart supérieur (1/4 - fond noir)** : Uniquement le nombre de tours terminés à gauche et le chrono du tour terminé `MM:SS` à droite (`FONT_MEDIUM`), sans texte ni symbole superflu.
- **Trois quarts inférieurs (3/4 - fond blanc)** : Uniquement le décompte géant (`FONT_NUMBER_HOT`) du temps de repos restant (**MM:SS**) en noir sur fond blanc.
- **Alarme unique (Vibration)** : Une vibration retentit automatiquement **20 secondes** avant le départ du tour suivant (en mode test).
- **Reprise automatique** : Au départ suivant, le GPS reprend et l'écran repasse automatiquement sur le mode course.

### Écran 2 : Statistiques Globales & Autonomie (Données Pures)

- **En-tête (`FONT_MEDIUM`)** : Heure actuelle (**HH:MM**) à gauche et pourcentage de batterie (**XX%**) côte à côte à droite, sans icône de batterie.
- **Milieu (`FONT_LARGE`)** : Numéro du tour en cours (`1`, `2`...) à gauche et kilométrage total cumulé (`0.00`) à droite, sans intitulés ni unité `km`.
- **Bas (`FONT_NUMBER_MEDIUM`)** : Chronomètre global ininterrompu (**HH:MM:SS**) affiché en taille maximale respectant l'arc inférieur des écrans ronds.

---

## 📊 Rendu dans Garmin Connect (Analyse des Circuits)

Grâce aux champs personnalisés Connect IQ (**FitContributor**), chaque tour est automatiquement enrichi dans Garmin Connect :

![Garmin Connect Laps](screenshots/garmin_connect_laps.jpg)

- **Temps Course** : Temps effectif passé à courir (cadence ≥ 145 spm).
- **Temps Marche** : Temps passé à marcher pendant la boucle (cadence < 145 spm).
- **Temps Repos** : Temps passé au repos au ravitaillement avant le départ suivant.

---

## 🚀 Installation

### Prérequis

- Une montre Garmin compatible : **Forerunner 945**, **Fenix 6**, **Enduro**, ou **Epix Pro (51mm)**.

### Installation manuelle (`.prg`)

1. Téléchargez le fichier correspondant à votre modèle (ex : `backyard-little-fr945.prg`) depuis les [Releases](https://github.com/Cynewulf89/garmin-app-backyard/releases).
2. Connectez la montre en USB à votre PC et copiez le fichier dans `/GARMIN/APPS/`.
