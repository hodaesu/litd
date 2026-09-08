# Audit UX/tactile du combat — LITD : Les Veilleurs

Base auditée : `main` au commit `cad1c5d158acb4e8291dd01c72e0dd8777cd4150`.

## Objet

Évaluer statiquement la lisibilité et l’utilisabilité mobile du combat avant le premier playtest humain sur iPhone, sans modifier l’équilibrage ni le cœur tactique.

Périmètre :

- HUD de combat ;
- sélection du Veilleur actif et de la cible ;
- ciblage anatomique ;
- compétences et actions ;
- états, blessures et informations contextuelles ;
- soumission/recrutement ;
- inspection des combattants ;
- accessibilité ;
- orientation, adaptation de l’interface et zones tactiles ;
- garde-fous contre les erreurs tactiles irréversibles.

## Résumé exécutif

La base tactile est meilleure que ce que laisse penser son apparence de prototype : les cases de grille font 56×56, les zones anatomiques 72×48 et les compétences 112×56. Un contrat interne vérifie également que les cases restent au-dessus de 44×44.

En revanche, l’UX ne doit pas encore être considérée comme validée sur téléphone. Un blocant de configuration et plusieurs problèmes de communication tactique sont présents :

1. **P0 — orientation mobile incohérente avec l’interface** : `project.godot` configure `display/window/handheld/orientation=1`, soit portrait dans Godot 4.7, alors que la résolution de référence est 1280×720 et que le combat est construit horizontalement.
2. **P1 — sélection trop peu matérialisée** : la case/cible, le Veilleur et la zone anatomique sélectionnés sont surtout reflétés par une ligne de statut ; les boutons ne possèdent pas de véritable état visuel sélectionné persistant.
3. **P1 — ennemis peu différenciables sur la grille** : les ennemis ordinaires sont affichés par `E`, les boss tombent sur `?`, ce qui devient ambigu dès qu’il y a plusieurs adversaires.
4. **P1 — informations importantes encore dépendantes des tooltips** : posture, identité complète de case et surtout raison d’indisponibilité de la soumission reposent sur `tooltip_text`, peu adapté à un usage tactile pur.
5. **P1 — retraite immédiatement exécutable** : le bouton Retraite est placé dans la même rangée que les quatre compétences et déclenche directement la résolution en retraite, sans confirmation.
6. **P1 — aperçu tactique existant mais non exploité par la tranche v0.9** : `CombatPreviewDirector` sait produire dégâts, précision, critique, résistance, statut, coût et recharge, mais la boucle de sélection v0.9 ne l’expose pas avant l’action.
7. **P1/P2 — panneaux d’inspection et certaines bannières à géométrie fixe** : ils sont dimensionnés pour le canevas 1280×720 et devront être vérifiés avec safe areas, ratios iPhone et échelle UI.
8. **P2 — accessibilité partiellement câblée** : `ui_scale`, contraste, filtres de couleur, flashs et secousses sont pris en charge, mais le chemin audité de l’`AccessibilityDirector` n’applique pas directement `text_scale`.

Conclusion statique : **NO-GO iPhone tant que P0 n’est pas corrigé ; GO conditionnel pour un premier playtest après traitement des P1 essentiels.**

---

## 1. Orientation et canevas

### État observé

- viewport : 1280×720 ;
- stretch : `canvas_items` ;
- aspect : `keep` ;
- orientation handheld : `1` ;
- l’interface tactique est organisée en rangées horizontales : grille 6×5, six zones anatomiques, quatre compétences + retraite.

### Risque

Godot 4.7 définit `SCREEN_PORTRAIT = 1`. Le projet annonce donc portrait alors que sa composition est manifestement dessinée pour un écran horizontal. Godot ne permute pas automatiquement largeur et hauteur de la résolution lorsque portrait est choisi.

### Décision

**P0 — à corriger avant tout jugement UX sur téléphone.**

La cible recommandée pour le premier playtest est le paysage verrouillé (`SCREEN_LANDSCAPE`) ou, si la rotation doit être autorisée, un contrat explicite `SCREEN_SENSOR_LANDSCAPE`. Ne pas tester le combat en portrait tant qu’un véritable layout portrait n’existe pas.

### Validation appareil

- lancement directement en paysage ;
- aucun retournement inattendu ;
- aucun letterboxing problématique ;
- aucune zone interactive sous l’encoche/Dynamic Island ou l’indicateur Home ;
- rendu identique après verrouillage/déverrouillage de l’iPhone.

---

## 2. Contrat tactile des contrôles

### Points solides

`VeilleursTacticalUI` définit :

- grille : 30 boutons de 56×56 ;
- zones anatomiques : six boutons de 72×48 ;
- compétences : quatre boutons de 112×56 ;
- retraite : 112×56 ;
- vérification interne : toute case sous 44×44 invalide le contrat tactile.

Ces dimensions constituent une base raisonnable et ne doivent pas être réduites pour « faire rentrer » davantage d’éléments.

### À vérifier sur appareil

La taille logique ne suffit pas : il faut mesurer les erreurs réelles de tap, notamment avec les pouces et avec `ui_scale` à 1.0, 1.2 et 1.4.

**Critère recommandé :**

- 0 erreur de tap sur 20 sélections de compétence consécutives ;
- ≤1 erreur sur 20 sélections de case ;
- ≤1 erreur sur 20 sélections de zone anatomique ;
- aucune action irréversible déclenchée par une erreur de tap.

---

## 3. Sélection du Veilleur et de la cible

### État observé

Un tap sur une case occupée par un Veilleur change `selected_watcher`. Un tap sur un ennemi/boss change `selected_target`. Le statut parent affiche ensuite le Veilleur, la cible et la zone.

La grille elle-même ne configure pas d’état de sélection persistant sur le bouton : pas de `toggle_mode`, pas de groupe de boutons, pas de style explicite selected/targeted.

### Risque

Le joueur doit relire une phrase plutôt que reconnaître immédiatement l’état tactique dans l’espace de jeu. Sur mobile, le doigt masque brièvement la case au moment du tap, ce qui augmente la nécessité d’un feedback persistant après relâchement.

### Correction UX recommandée

Créer trois signaux visuels distincts et cumulables :

- **Veilleur actif** : contour/halo + marqueur de tour ;
- **cible choisie** : contour hostile + marqueur de cible ;
- **case de déplacement envisagée** : surbrillance spécifique, jamais confondue avec une cible.

Le feedback ne doit jamais reposer uniquement sur la couleur : ajouter forme, contour ou pictogramme.

### GO

En moins d’une seconde, sans lire de texte, un testeur doit pouvoir désigner :

1. qui agit ;
2. qui est ciblé ;
3. quelle zone corporelle est sélectionnée.

---

## 4. Identité des combattants sur la grille

### État observé

`_short_name()` affiche :

- Veilleur : deux premières lettres de l’identifiant après `ENT_WATCHER_` ;
- ennemi : `E` ;
- tout autre identifiant, donc notamment un boss : `?`.

Le nom complet existe en tooltip de case.

### Risque

Dès que deux ennemis sont présents, le joueur ne peut plus différencier visuellement les cibles à partir du bouton seul. Le problème devient critique avec une Némésis, un adversaire soumis, un boss ou plusieurs créatures de rôles différents.

### Correction UX recommandée

Chaque occupant doit avoir au minimum :

- silhouette/portrait/icône unique par archetype ;
- état actif/mort/soumis perceptible ;
- nom court ou symbole différenciant ;
- indicateur spécial boss/Némésis ;
- inspection par tap long ou bouton d’inspection, sans dépendre d’un survol.

Le texte `E` peut subsister comme fallback de debug, pas comme présentation finale.

---

## 5. Ciblage anatomique

### État observé

Six zones sont disponibles : tête, torse, bras G/D, jambe G/D. Les boutons sont assez grands (72×48) mais leur état de sélection n’est pas graphiquement matérialisé dans le composant tactique ; le parent affiche `zone <id>` dans sa ligne de statut.

### Risques

- `left_arm`, `right_leg`, etc. peuvent apparaître sous forme d’identifiants techniques dans le statut ;
- le joueur ne voit pas immédiatement pourquoi choisir une zone plutôt qu’une autre ;
- aucune prévisualisation locale du compromis précision/effet anatomique n’est affichée par cette UI ;
- les six boutons en ligne augmentent la charge de lecture et les changements de cible rapides.

### Correction UX recommandée

Au premier tap sur une zone :

- état visuel sélectionné persistant ;
- nom localisé ;
- chance de toucher estimée ;
- conséquence anatomique pertinente : intégrité/trauma actuel, risque fonctionnel, saignement/fracture/démembrement si applicable ;
- indication claire quand une compétence ne peut pas affecter cette zone.

Ne pas afficher toute la simulation interne en permanence. Présenter d’abord : **chance de toucher + conséquence principale + état de la zone**. Les détails restent accessibles à l’inspection.

### Mesure playtest

Le testeur doit réussir à expliquer, après deux combats maximum, la différence stratégique entre : tête, torse, bras et jambes sans avoir besoin d’une explication externe.

---

## 6. Compétences et aperçu de résolution

### État observé

Quatre compétences maximum sont chargées dans les quatre boutons. Une compétence valide appelle directement `resolve_skill(...)` avec la cible et la zone choisies.

Un `CombatPreviewDirector` existe déjà et sait calculer/présenter notamment :

- plage de dégâts ;
- précision ;
- critique ;
- résistance ;
- statut et chance ;
- mouvement ;
- coût ;
- recharge.

La tranche tactique v0.9 auditée ne branche pas cet aperçu dans le parcours de sélection.

### Risque

Sur tactile, un tap est plus susceptible d’être interprété comme une intention d’exécuter immédiatement. Sans prévisualisation compacte ou confirmation contextuelle, le joueur peut découvrir après coup qu’il a choisi une mauvaise cible/zone ou une compétence peu adaptée.

### Recommandation

Conserver le tap unique pour la vitesse, mais faire apparaître avant exécution une **prévisualisation liée à la cible** lorsqu’une compétence est sélectionnée, avec un second tap de validation sur la cible ou un bouton d’action contextuel.

Alternative pour les actions triviales : tap compétence → cibles valides illuminées → tap cible = exécution. La zone anatomique doit rester visible dans ce flux.

### Critère

Avant de confirmer une attaque importante, le joueur doit pouvoir connaître sans ouvrir une fenêtre :

- cible ;
- zone ;
- chance approximative de réussite ;
- effet principal attendu.

---

## 7. Soumission

### État observé

Le bouton `Soumettre cible` mesure 180×48 et se trouve en bas à droite. Quand les conditions ne sont pas réunies, il est désactivé et la raison détaillée est stockée dans `tooltip_text` : PV actuels, Résolution et seuils.

### Risque tactile

Un bouton désactivé ne donne pas naturellement un feedback au tap ; sur iPhone il n’existe pas de survol pour afficher le tooltip. Le joueur peut donc voir une action grisée sans comprendre comment la débloquer.

### Correction recommandée

Quand une cible est sélectionnée, afficher à proximité :

- `Soumission : indisponible` + condition manquante la plus proche ; ou
- une jauge compacte `PV 48 % / 35 %` et `Résolution 31 / 20` ;
- état `PRÊT À SOUMETTRE` clairement visible quand les conditions passent au vert.

Le bouton peut rester désactivé, mais sa raison ne doit jamais être tooltip-only.

---

## 8. Retraite et actions irréversibles

### État observé

Le bouton Retraite est de même taille que les compétences et se trouve dans la même rangée. Son `pressed` émet directement `retreat_pressed`, puis la tranche v0.9 clôt le combat avec `retreat`.

### Risque

Erreur de tap catastrophique et difficile à distinguer d’une compétence adjacente.

### Correction recommandée

**P1 avant playtest sérieux :**

- séparer spatialement Retraite des compétences ;
- utiliser une apparence et une icône distinctes ;
- exiger une confirmation courte : `Retraiter ?` / `Annuler` ;
- ne jamais demander deux confirmations pour des actions réversibles ordinaires.

La confirmation doit être testée avec le pouce, sans boîte modale minuscule.

---

## 9. États, blessures et Rémanence

### Points positifs

`CombatBodyPresentation` traduit les états psychologiques et physiques et modifie posture, inclinaison, respiration et modulation. Le HUD dispose également d’une hiérarchie de priorité et limite le bruit visuel.

`HUDDirector` ne présente que deux icônes de statut avant un overflow `+N`, ce qui évite la saturation.

### Risques

- posture détaillée stockée dans `tooltip_text` ;
- couleur/modulation seule insuffisante pour certaines déficiences visuelles ;
- `+N` n’est utile que si l’inspection tactile des statuts est immédiatement accessible ;
- blessures anatomiques majeures doivent être visibles sans ouvrir un long écran d’inspection.

### Hiérarchie recommandée

Toujours visible en combat :

1. vivant / mort / soumis ;
2. PV et danger vital ;
3. blessure fonctionnelle majeure ;
4. contrôle empêchant d’agir ;
5. 1–2 états tactiques prioritaires.

Sur tap/inspection :

- totalité des buffs/debuffs ;
- blessures persistantes ;
- états corporels par zone ;
- détails numériques.

---

## 10. Inspection des combattants

### État observé

Le système d’inspection est bien conçu sur le principe :

- survol/focus → aperçu ;
- `pressed` sur un `BaseButton` → détail complet ;
- panneau détaillé scrollable ;
- bouton Fermer de 140×42.

Cependant :

- le preview est placé à `(420,72)` avec une largeur minimale 440 ;
- le détail est placé à `(210,70)` et mesure 860×580 ;
- plusieurs informations de preview sont en taille 12–13 ;
- certains visuels de combattants utilisent un tooltip de posture indépendamment de l’écran d’inspection.

### Recommandation

Sur téléphone :

- considérer le survol uniquement comme bonus PC ;
- garantir `tap → inspection` ou `tap long → inspection` partout où le combattant est représenté ;
- ancrer le panneau à la safe area plutôt qu’à des coordonnées absolues ;
- utiliser une largeur relative avec scroll vertical ;
- bouton de fermeture ≥44 px de hauteur ;
- aucune information indispensable dans un tooltip.

---

## 11. Accessibilité

### Déjà présent

- échelle UI 0.8–1.4 ;
- échelle texte 0.9–1.5 dans les réglages ;
- contraste élevé ;
- assistance de couleur ;
- réduction des flashs ;
- désactivation des secousses ;
- sous-titres ;
- sortie mono ;
- plage dynamique audio ;
- vitesse d’animation réglable.

### Point à corriger/vérifier

Dans le chemin audité, `AccessibilityDirector.apply_settings()` affecte `content_scale_factor` à partir de `ui_scale`, mais n’applique pas directement `text_scale`. Il faut confirmer que `text_scale` est réellement consommé ailleurs ; sinon le réglage est présent sans effet visuel.

### Tests obligatoires

- UI scale 0.8 / 1.0 / 1.2 / 1.4 ;
- text scale 0.9 / 1.0 / 1.25 / 1.5 ;
- contraste élevé ;
- trois assistances couleur ;
- flashs réduits ;
- secousses désactivées.

Aucun réglage d’accessibilité ne doit créer de chevauchement ou rendre une action inaccessible.

---

## 12. Safe area iPhone

Le premier test appareil doit explicitement contrôler :

- Dynamic Island / encoche ;
- coins arrondis ;
- indicateur Home ;
- marges gauche/droite en paysage ;
- iPhone avec ratio plus étroit et plus large que 16:9.

Tout contrôle tactique critique doit rester à l’intérieur de la safe area, particulièrement `Soumettre cible`, Retraite et les compétences.

---

## 13. Priorités de correction

### P0 — avant tout playtest iPhone

- Corriger/valider l’orientation mobile par rapport à la cible paysage 1280×720.

### P1 — avant d’interpréter sérieusement les résultats d’un playtest

- matérialiser Veilleur actif, cible et zone anatomique ;
- remplacer `E`/`?` par des identités visuelles différenciables ;
- rendre les conditions de soumission visibles sans tooltip ;
- protéger Retraite par séparation + confirmation ;
- fournir l’aperçu tactique essentiel avant résolution ;
- garantir une inspection accessible par touch ;
- adapter inspection/bannières aux safe areas.

### P2 — polish mesuré après premier test

- hiérarchie typographique ;
- densité des statuts ;
- durées des messages contextuels ;
- haptique légère de sélection/validation si retenue ;
- optimisation du layout à grande échelle UI ;
- validation de `text_scale` ;
- réglage des modes contraste/couleur sur appareil réel.

---

## 14. Règles à ne pas casser pendant les corrections UX

- conserver la logique tactique et les formules existantes ;
- conserver les six zones anatomiques ;
- ne pas réduire les zones tactiles sous le contrat actuel ;
- ne pas masquer les blessures/Rémanence pour gagner de la place ;
- ne pas ajouter des confirmations à chaque action ;
- ne pas rendre la grille dépendante d’un hover ;
- ne pas faire de la couleur l’unique porteur d’information ;
- ne pas simplifier l’UX en supprimant les décisions tactiques : simplifier leur lecture.

---

## 15. Verdict statique

### PC souris/clavier

**GO technique sous réserve des tests existants.** Les tooltips et le hover peuvent fonctionner comme prévu.

### Mobile tactile avant correction P0

**NO-GO d’évaluation UX** : l’orientation configurée est incohérente avec le layout horizontal.

### Mobile tactile après P0 et P1 essentiels

**GO pour playtest humain contrôlé.** Le playtest doit alors décider du tuning réel : densité, rythme, compréhension et confort à une main/deux mains.

Le document `mobile_combat_playtest_scorecard.md` définit la grille de notation à remplir pendant ces sessions.