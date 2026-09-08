# Grille de notation — Playtest combat mobile Les Veilleurs

Cette fiche est destinée au premier playtest humain tactile sur iPhone. Elle complète `mobile_combat_ux_audit.md`.

## 1. Conditions de la session

À relever avant chaque session :

- date ;
- build / commit ;
- modèle d’iPhone ;
- version iOS ;
- orientation ;
- résolution/rendu effectif si disponible ;
- UI scale ;
- text scale ;
- mode contraste/couleur ;
- joueur novice / joueur connaissant LITD ;
- main dominante ;
- prise en main : deux mains / une main ;
- casque / haut-parleur / muet.

Ne pas expliquer les commandes avant les tâches marquées **découverte**. Le but est de mesurer ce que l’interface enseigne réellement.

---

## 2. Échelle de score 0–4

Chaque critère reçoit une note :

- **4 — immédiat** : compris/exécuté sans hésitation ni erreur ;
- **3 — clair** : petite hésitation, aucune aide externe ;
- **2 — fragile** : compris après essai/retour en arrière ou confusion visible ;
- **1 — mauvais** : aide externe nécessaire ou plusieurs erreurs ;
- **0 — bloquant** : impossible, illisible, action inaccessible, soft-lock ou conséquence irréversible due à l’UI.

Une note 4 n’exige pas que l’interface soit belle : elle signifie que le joueur sait quoi faire et obtient le résultat attendu.

---

## 3. Mesures quantitatives obligatoires

Pour chaque combat testé, relever :

- durée totale ;
- nombre de rounds ;
- nombre d’actions joueur ;
- nombre d’erreurs de tap ;
- nombre d’actions annulées/reprises ;
- nombre de fois où le joueur cherche une information ;
- nombre d’ouvertures d’inspection ;
- nombre d’actions refusées ;
- nombre d’erreurs de cible ;
- nombre d’erreurs de zone anatomique ;
- nombre d’erreurs de compétence ;
- nombre d’actions irréversibles accidentelles ;
- nombre de moments où le joueur demande « pourquoi ? » ;
- nombre de moments où le joueur demande « qui joue ? » ;
- nombre de moments où le joueur demande « qui est ciblé ? » ;
- nombre de moments où le joueur demande « que fait cet état ? ».

### Chronométrages ponctuels

Mesurer lorsque possible :

- temps pour identifier le personnage actif ;
- temps pour choisir une cible ;
- temps pour choisir une zone anatomique ;
- temps entre sélection d’une compétence et validation de l’action ;
- temps pour trouver la raison d’une action désactivée ;
- temps pour ouvrir l’inspection d’un combattant ;
- temps pour comprendre une nouvelle blessure/affliction.

---

## 4. Bloc A — Orientation, safe area et confort physique

| Critère | Note 0–4 | Mesure / observation |
|---|---:|---|
| Le jeu démarre dans l’orientation attendue |  |  |
| Aucun contrôle sous encoche/Dynamic Island |  |  |
| Aucun contrôle sous l’indicateur Home |  |  |
| Aucun texte coupé sur les bords |  |  |
| Les pouces n’occultent pas durablement l’information critique |  |  |
| Le jeu reste confortable après 10 min |  |  |
| Le jeu reste confortable après 30 min |  |  |
| Rotation/verrouillage écran ne casse pas le layout |  |  |

**NO-GO immédiat** si une action tactique devient inaccessible à cause du ratio, de la safe area ou de l’orientation.

---

## 5. Bloc B — Comprendre le tour

Tâche découverte : lancer un combat sans expliquer le HUD.

| Critère | Note 0–4 | Temps / observation |
|---|---:|---|
| Identifie qui doit agir |  |  |
| Identifie le round actuel |  |  |
| Distingue alliés et ennemis |  |  |
| Comprend qu’une case peut être sélectionnée |  |  |
| Comprend quelles cases sont occupées/libres |  |  |
| Repère rapidement la cible actuellement choisie |  |  |

### Seuil cible

- personnage actif identifié en **≤2 s** après stabilisation de l’écran ;
- cible sélectionnée identifiable en **≤1 s** sans lire une phrase complète.

---

## 6. Bloc C — Sélection de cible

Faire sélectionner successivement 20 cibles/cases dans plusieurs configurations.

| Mesure | Résultat |
|---|---:|
| Taps demandés | 20 |
| Sélections correctes au premier tap |  |
| Mauvaises cibles |  |
| Taps non reconnus |  |
| Corrections nécessaires |  |

### Seuil cible

- **≥95 %** de sélections correctes au premier tap ;
- aucune confusion entre deux ennemis visuellement différents ;
- 0 action exécutée sur une cible non intentionnelle sans possibilité de prévention.

Score qualitatif 0–4 : **__**

---

## 7. Bloc D — Ciblage anatomique

Tâches : sélectionner tête, torse, bras G/D et jambes G/D ; changer rapidement de zone ; expliquer pourquoi modifier la zone.

| Critère | Note 0–4 | Observation |
|---|---:|---|
| Trouve les six zones |  |  |
| Voit quelle zone est sélectionnée |  |  |
| Distingue gauche/droite sans erreur |  |  |
| Comprend que la précision change selon la zone |  |  |
| Comprend l’intérêt fonctionnel bras/jambe |  |  |
| Comprend la différence tête/torse |  |  |
| Repère une zone déjà blessée |  |  |
| Comprend quand un démembrement est possible/impossible |  |  |

### Test de taps

20 changements de zone consécutifs :

- corrects au premier tap : **__/20** ;
- mauvaises zones : **__** ;
- délai moyen approximatif : **__ s**.

### Seuil cible

- **≥90 %** de zone correcte au premier tap au premier combat ;
- **≥95 %** après deux combats ;
- joueur capable d’expliquer au moins trois conséquences anatomiques sans aide après deux combats.

---

## 8. Bloc E — Compétences

Pour chaque compétence disponible :

| Critère | Note 0–4 | Observation |
|---|---:|---|
| Nom lisible |  |  |
| Bouton facilement touchable |  |  |
| Sait si la compétence est disponible |  |  |
| Sait quelle cible est valide |  |  |
| Comprend l’effet principal avant usage |  |  |
| Comprend coût/recharge si pertinent |  |  |
| Comprend le résultat après usage |  |  |

### Test d’erreur

Sur 20 actions :

- erreurs de compétence : **__** ;
- erreurs de cible : **__** ;
- actions lancées alors que le joueur voulait seulement consulter : **__**.

### Seuil cible

0 action catastrophique causée par ambiguïté entre « consulter/sélectionner » et « exécuter ».

---

## 9. Bloc F — Prévisualisation tactique

Avant une attaque importante, demander au joueur :

1. Qui vas-tu toucher ?
2. Quelle zone ?
3. Quelle est ta chance approximative de réussir ?
4. Quel est l’effet principal attendu ?

| Réponse lisible sans ouvrir un écran lourd | Oui/Non | Temps |
|---|---|---:|
| Cible |  |  |
| Zone |  |  |
| Chance/précision |  |  |
| Dégâts/effet principal |  |  |
| Statut éventuel |  |  |

Score 0–4 : **__**

Une action tactique complexe ne doit pas être un pari sur ce que fera le bouton.

---

## 10. Bloc G — États, blessures et conséquences corporelles

Provoquer ou charger un combat comportant : saignement, étourdissement/contrôle, blessure de membre, état critique et au moins un buff/debuff.

| Critère | Note 0–4 | Observation |
|---|---:|---|
| Repère qu’un personnage est affecté |  |  |
| Distingue blessure corporelle et statut temporaire |  |  |
| Comprend si le personnage peut agir |  |  |
| Identifie un danger vital |  |  |
| Trouve la liste complète des états |  |  |
| Comprend l’effet fonctionnel d’un membre blessé |  |  |
| Comprend qu’une blessure peut persister |  |  |
| Repère une conséquence de Rémanence |  |  |

### Seuil cible

Une conséquence qui change l’action disponible ou menace directement la survie doit être comprise en **≤3 s** sans tooltip PC.

---

## 11. Bloc H — Inspection

Tâche découverte : « Dis-moi tout ce que tu peux apprendre sur cet ennemi. »

Relever :

- méthode trouvée spontanément : **tap / tap long / autre / aucune** ;
- temps pour ouvrir : **__ s** ;
- erreurs : **__** ;
- fermeture trouvée sans aide : **oui/non**.

| Critère | Note 0–4 |
|---|---:|
| Inspection trouvable |  |
| Informations lisibles |  |
| Scroll naturel |  |
| Fermeture évidente |  |
| Retour au combat sans perte de contexte |  |
| Aucune donnée critique exclusivement liée au hover |  |

---

## 12. Bloc I — Soumission

Faire rencontrer un ennemi :

1. non éligible ;
2. proche du seuil ;
3. éligible ;
4. soumis avec succès.

| Critère | Note 0–4 | Observation |
|---|---:|---|
| Comprend pourquoi l’action est indisponible |  |  |
| Comprend ce qu’il doit faire pour la rendre disponible |  |  |
| Repère immédiatement quand la cible devient soumissible |  |  |
| Comprend que l’ennemi reste vivant |  |  |
| Comprend qu’une décision de recrutement viendra après victoire |  |  |

### Seuil cible

Le testeur doit pouvoir expliquer les conditions principales de soumission après les avoir vues une fois, sans qu’un développeur les lui lise.

---

## 13. Bloc J — Retraite

### Test sécurité tactile

Sans prévenir le joueur que Retraite est une zone sensible, faire réaliser 20 sélections de compétences proches de ce bouton.

- déclenchements accidentels de Retraite : **__** ;
- quasi-erreurs signalées par le joueur : **__**.

Puis demander volontairement une retraite :

| Critère | Note 0–4 |
|---|---:|
| Trouve l’action |  |
| Comprend qu’elle est irréversible pour le combat |  |
| Confirmation claire |  |
| Peut annuler facilement |  |

### Seuil obligatoire

**0 retraite accidentelle.** Toute retraite involontaire classe la protection de cette action en échec jusqu’à correction.

---

## 14. Bloc K — Boss et Némésis

### Boss

| Critère | Note 0–4 |
|---|---:|
| Boss immédiatement identifiable |  |
| Phase actuelle compréhensible |  |
| Transition de phase visible |  |
| Télégraphie comprise avant résolution |  |
| Boss non confondu avec une cible normale/soumissible |  |

### Némésis

| Critère | Note 0–4 |
|---|---:|
| Retour de la Némésis remarqué |  |
| Identité de l’adversaire reconnue |  |
| Différence avec un ennemi normal comprise |  |
| Rémanence perçue comme conséquence de l’historique |  |

---

## 15. Bloc L — Feedback d’action

Pour 10 actions différentes, demander immédiatement après animation : « Qu’est-ce qui vient de se passer ? »

| Type d’action | Compris sans texte externe ? | Note 0–4 |
|---|---|---:|
| Attaque réussie |  |  |
| Attaque ratée |  |  |
| Critique |  |  |
| Saignement |  |  |
| Fracture/blessure |  |  |
| Contrôle |  |  |
| Garde |  |  |
| Soin |  |  |
| Soumission |  |  |
| Transition boss |  |  |

Le feedback peut combiner animation, posture, son, texte et haptique ; il ne doit pas exiger de lire le journal pour comprendre l’action immédiate.

---

## 16. Bloc M — Accessibilité et échelles

Répéter un mini-combat avec :

- UI scale 0.8 ;
- UI scale 1.0 ;
- UI scale 1.4 ;
- text scale 1.5 ;
- contraste élevé ;
- une assistance couleur ;
- flashs réduits ;
- secousses désactivées.

Pour chaque profil :

| Profil | Chevauchement | Contrôle coupé | Texte illisible | Note 0–4 |
|---|---|---|---|---:|
| UI 0.8 |  |  |  |  |
| UI 1.0 |  |  |  |  |
| UI 1.4 |  |  |  |  |
| Texte 1.5 |  |  |  |  |
| Contraste |  |  |  |  |
| Assistance couleur |  |  |  |  |
| Flash réduit |  |  |  |  |
| Sans secousse |  |  |  |  |

---

## 17. Bloc N — Sauvegarde/reprise en plein combat

Sauvegarder avec :

- cible choisie ;
- zone anatomique choisie ;
- états actifs ;
- blessure ;
- boss en phase >1 si possible.

Après reprise :

| Critère | Note 0–4 |
|---|---:|
| État tactique correct |  |
| Cible/zone compréhensibles |  |
| États visibles |  |
| Phase boss correcte |  |
| Aucun contrôle tactile désynchronisé |  |

Toute divergence d’état interne/affiché est **NO-GO**.

---

## 18. Questionnaire post-session

Sans guider les réponses :

1. À quel moment as-tu été le plus perdu ?
2. Quelle information as-tu le plus souvent cherchée ?
3. As-tu déjà eu peur d’appuyer sur le mauvais bouton ?
4. Quelle action t’a semblé la moins claire ?
5. Peux-tu expliquer comment choisir une zone du corps ?
6. Peux-tu expliquer ce que change une blessure au bras ou à la jambe ?
7. Peux-tu expliquer quand on peut soumettre un ennemi ?
8. Comment sais-tu qu’un boss change de phase ?
9. Comment sais-tu qui joue maintenant ?
10. Quelle information supprimerais-tu de l’écran ?
11. Quelle information ajouterais-tu ?
12. Préférerais-tu jouer avec une ou deux mains ? Pourquoi ?
13. Après cette session, jouerais-tu volontairement un autre donjon ? Pourquoi ?

Noter les réponses verbatim autant que possible.

---

## 19. Score global

Calculer la moyenne de chaque bloc noté :

- A Orientation/safe area : __/4
- B Tour : __/4
- C Cible : __/4
- D Anatomie : __/4
- E Compétences : __/4
- F Prévisualisation : __/4
- G États/blessures : __/4
- H Inspection : __/4
- I Soumission : __/4
- J Retraite : __/4
- K Boss/Némésis : __/4
- L Feedback : __/4
- M Accessibilité : __/4
- N Sauvegarde/reprise : __/4

**Moyenne générale : __/4**

Ne pas utiliser la moyenne pour cacher un blocant : les règles NO-GO ci-dessous priment.

---

## 20. Règles GO / NO-GO

### GO pour poursuivre le tuning

Toutes les conditions suivantes :

- aucun blocant 0 sur orientation/safe area ;
- aucune action critique inaccessible ;
- 0 retraite accidentelle ;
- aucune perte d’état à la sauvegarde/reprise ;
- sélection de cible ≥95 % correcte au premier tap ;
- sélection anatomique ≥90 % au premier combat et en progression ;
- joueur identifie l’acteur actif en ≤2 s ;
- états critiques compris en ≤3 s ;
- soumission compréhensible sans hover ;
- moyenne ≥3.0/4 sur les blocs B à L ;
- aucun bloc critique sous 2/4.

### GO fort / UX prête à être polie

- moyenne ≥3.5/4 ;
- cible et zone ≥95 % ;
- aucune question répétitive sur acteur/cible ;
- aucune action exécutée par ambiguïté d’interface ;
- au moins 80 % des testeurs souhaitent volontairement continuer un donjon après la session, si l’échantillon devient suffisant pour interpréter ce chiffre.

### NO-GO

Un seul des points suivants suffit :

- orientation/layout rend un contrôle inaccessible ;
- soft-lock ou désynchronisation UI/runtime ;
- action irréversible déclenchée accidentellement ;
- information vitale uniquement accessible par hover ;
- cible affichée différente de la cible réellement résolue ;
- zone anatomique affichée différente de la zone réellement résolue ;
- statut critique invisible ou incompréhensible ;
- sauvegarde/reprise modifie l’état tactique ;
- boss/Némésis impossible à différencier d’un ennemi normal dans une situation où cette distinction compte.

---

## 21. Ordre recommandé de sessions

1. **Session 1 — novice, aucun tutoriel oral** : découverte pure, combat standard.
2. **Session 2 — anatomie/états** : blessures, saignement, contrôle.
3. **Session 3 — soumission/recrutement**.
4. **Session 4 — retraite/défaite/sauvegarde-reprise**.
5. **Session 5 — Némésis + boss trois phases**.
6. **Session 6 — réglages d’accessibilité et grandes échelles**.
7. **Session 7 — répétition après corrections**, en gardant exactement les mêmes tâches pour comparer les mesures.

Ne pas régler l’équilibrage des dégâts à partir d’un problème d’interface. Si le joueur perd parce qu’il ne savait pas qui/quoi il avait sélectionné, corriger l’UX avant de toucher aux statistiques.