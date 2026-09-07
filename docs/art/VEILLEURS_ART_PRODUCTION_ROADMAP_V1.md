# LITD : Les Veilleurs — roadmap de production artistique v1

## Objectif

Transformer l'Art Bible et le catalogue d'assets en ordre de production réaliste, sans perturber le playtest PC de la PR #173 ni la PR #180 figée.

Cette roadmap distingue ce qui peut être préparé maintenant de ce qui doit attendre l'observation du jeu.

## Phase A — préproduction sans PC

### A1 — verrouillage des silhouettes

Produire d'abord des fiches conceptuelles, pas des modèles finaux :

- 4 Veilleurs : silhouettes, rapports de taille, équipements, postures ;
- 8 ennemis Acte I : silhouette + anatomie + posture d'intention ;
- 5 boss : silhouette noire + progression des phases ;
- 1 planche de Rémanence Normal→Némésis ;
- 1 planche corps intact→lost commune à toutes les espèces compatibles.

Critère : chaque unité doit rester reconnaissable sur une vignette équivalente à sa taille réelle en combat mobile.

### A2 — langage de matières

Créer une bibliothèque de matériaux conceptuels :

- fer/bronze réparé ;
- cuir huilé/usé ;
- toile rapiécée ;
- pierre sèche/humide/fendue ;
- bois brûlé ;
- parchemin/encre ;
- cendre sèche/cendre collée ;
- tissus médicaux ;
- ivoire/os ;
- surfaces organiques réseau/veines.

Chaque matériau doit avoir une version “vue mobile” : grandes masses, contraste suffisant, détail secondaire facultatif.

### A3 — UI skin conceptuelle

À partir de la planche canonique du 7 septembre 2026 :

- 9-slices de cadres ;
- états normal/pressé/focus/désactivé/danger ;
- panneaux métal/parchemin ;
- grille typographique ;
- pictogrammes anatomiques ;
- pictogrammes connaissance ;
- exemple combat, Refuge et Archives dans les quatre profils : téléphone, tablette, PC, manette.

Ne pas modifier les dimensions finales des télégraphes avant le playtest.

## Phase B — immédiatement après le premier playtest PC

Cette phase doit partir des observations, pas des préférences visuelles.

### B1 — correctifs P0

Si le playtest montre :

- intentions difficiles à lire → revoir contraste, silhouettes et temporalité avant d'ajouter des VFX ;
- zones anatomiques confuses → simplifier formes/couleurs et réduire décor sous les cibles ;
- surcharge de sang/VFX → réduire densité et durée, pas l'information mécanique ;
- personnages trop similaires → corriger silhouettes et gestes signatures ;
- extraction difficile à trouver → renforcer composition et hiérarchie, pas ajouter un tracker permanent.

### B2 — capture de référence

Avant de produire des assets lourds, obtenir pour un combat représentatif :

- capture téléphone ;
- capture tablette ;
- capture PC ;
- capture manette/focus ;
- capture gore full/reduced/off ;
- capture reduced motion.

Ces captures deviennent la référence de lisibilité du pipeline.

## Phase C — vertical slice Acte I

Ordre recommandé :

1. UI combat P0 ;
2. Nayra/Tarek/Aïsha/Idris ;
3. anatomie et blessures du quatuor ;
4. Délié Affamé comme ennemi étalon ;
5. une famille ennemie complète ;
6. kit environnement seuil/pierre ;
7. Refuge des Cendres ;
8. Ishar ;
9. Rémanence Mémoriel/Vétéran ;
10. cadavres/traces persistantes ;
11. VFX et polish ;
12. ensuite seulement les 7 autres espèces Acte I.

Pourquoi : le Délié Affamé et le quatuor suffisent pour tester presque tout le langage visuel systémique avant de multiplier la production.

## Phase D — industrialisation Acts II–V

Une fois Acte I validé, produire par “paquet d'acte” :

- 1 keyframe d'ambiance ;
- 1 keyframe combat ;
- 4 espèces ordinaires ;
- 1 boss et ses phases ;
- kit architecture ;
- kit props ;
- kit VFX ;
- motifs UI/Archives spécifiques sans changer le skin maître ;
- 2 captures mobile + 1 capture PC de validation.

### Acte II — Silencieux
Priorité : télégraphes corporels qui fonctionnent même sans son.

### Acte III — Veines
Priorité : anatomie réseau lisible, sans amas organique confus.

### Acte IV — Porte-Cendres
Priorité : thème de l'effacement sans effacer les silhouettes cliquables.

### Acte V — Gardiens de Version
Priorité : copie/palimpseste lisibles comme phénomènes physiques, jamais comme glitch numérique.

## Phase E — contenu futur

À préparer seulement en concept tant que le jeu de base n'est pas éprouvé :

- variantes visuelles liées aux 64 rencontres ;
- traces d'histoire pour Rémanence ;
- états dynamiques du Refuge ;
- accessoires individuels des auxiliaires ;
- illustrations Archives ;
- keyframes de moments narratifs ;
- variantes de victoire/défaite/extraction ;
- contenus promotionnels et captures store.

## Budgets artistiques — principes, pas chiffres figés

Les chiffres précis de triangles, textures et draw calls doivent être mesurés sur l'appareil cible réel. En attendant :

- matériaux partagés ;
- atlas UI ;
- decals réutilisables ;
- VFX courts ;
- LOD pour environnement et ennemis ;
- silhouettes conservées au LOD bas ;
- pas de transparence plein écran durable ;
- pas de détail qui existe uniquement en 4K PC.

## Matrice d'acceptation d'un asset

Un asset n'est “fini” que s'il passe :

- cohérence canonique ;
- silhouette ;
- anatomie si applicable ;
- lecture intention ;
- lecture blessure ;
- contraste UI/cible ;
- reduced gore ;
- reduced motion si animé ;
- téléphone ;
- tablette ;
- PC ;
- manette/focus lorsque pertinent.

## Stop conditions

Interrompre la production et revenir au concept si :

- le joueur ne comprend pas l'action préparée ;
- l'asset masque une zone anatomique ;
- une variante de Rémanence semble être une nouvelle espèce ;
- une créature recrutée perd visuellement sa continuité d'identité ;
- un boss change de phase seulement par couleur/VFX ;
- une option PC donne un avantage informationnel sur mobile ;
- le style devient plus important que la fonction de jeu.
