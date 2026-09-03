# LITD : Les Veilleurs — Validation statique du pack canonique

Date : 2026-09-03
Résultat final : **PASS — 0 erreur après prise en compte de la clé composite source connue.**

Cette validation porte sur les JSON extraits du classeur canonique. Elle ne remplace pas la compilation Godot ni les 48 tests runtime.

## Comptages validés

- 180 compétences normales Veilleurs.
- 12 ultimes Veilleurs.
- 12 arbres Veilleurs.
- 15 compétences normales par arbre Veilleur.
- paliers Veilleurs : 1/4/7/10/13/16/19/22/25/28/31/35/39/44/49.
- progression : 50 niveaux exactement, N1 à N50.
- charges d'ultime : N16=1, N32=2, N48=3.
- `Bestiaire_confirmé` : 39 descripteurs d'arbres = 13 entités × 3 arbres.
- `Comp_bestiaire_585` : 585 compétences = 39 arbres × 15.
- `Ult_bestiaire_39` : 39 ultimes.
- `Actes_II_V_bestiaire` : 48 descripteurs = 16 ennemis × 3 arbres.
- `Comp_II_V_720` : 720 compétences = 48 arbres × 15.
- `Ult_II_V_48` : 48 ultimes.
- 24 ennemis ordinaires + 5 boss = 29 entités.
- ennemis/boss : 1 305 compétences normales + 87 ultimes.
- total : 99 arbres / 1 485 compétences normales / 99 ultimes.
- 64 rencontres.
- distribution rencontres : Acte I=16 ; Actes II, III, IV, V=12 chacun.
- 16 phases boss, distribution 3/3/3/3/4.
- 12 dangers de combat.
- 48 cas de test.
- 30 entrées Rémanence blessures.
- 60 lignes Traces psychologiques.
- 29 lignes bestiaire narratif.
- 64 rencontres narratives.
- 68 barks Veilleurs.
- 30 lignes dialogue boss.
- 15 événements narratifs.
- 667 clés de localisation FR.
- colonne `Essence cible` présente dans le référentiel de récompenses.

## Particularité source découverte — IDs Acte I

`Comp_bestiaire_585` contient **15 IDs bruts réutilisés deux fois**. Exemple : `DÉL-CHA-01` désigne une compétence de Délié Affamé et une compétence de Délié Boursouflé.

Ce n'est pas une collision si la clé source est définie comme :

`(Entité, ID)`

La validation confirme que cette clé composite est unique pour les 585 lignes.

Conséquence d'architecture :

- conserver `source_id` tel quel pour la traçabilité ;
- ne jamais l'utiliser seul comme clé globale ;
- produire un `runtime_id` ASCII stable à partir de `entity_id + source_id` ou d'un mapping versionné équivalent ;
- sauvegarder le mapping, ne jamais le recalculer de façon susceptible de changer entre versions.

Les 720 compétences des actes II–V ont, elles, des IDs bruts globalement uniques dans le fichier actuel.

## Première anomalie de contrôle corrigée

Le premier script de contrôle attendait par erreur 174 lignes dans `Bestiaire_narratif_29`. La source contient bien 29 lignes, chaque ligne regroupant plusieurs champs narratifs. C'était une erreur du validateur, pas du référentiel.

## Test reproductible

Utiliser :

`tools/validate_canonical_pack.py`

sur le dossier extrait contenant `current/`, `legacy/` et `MANIFEST.json`.

## Ce que cette validation ne prouve pas

- compilation GDScript ;
- compatibilité exacte avec le projet Godot existant ;
- résultat du CombatResolver ;
- fonctionnement de l'IA ;
- comportement réel des 64 rencontres ;
- transitions boss runtime ;
- intégrité des sauvegardes en interruption réelle ;
- performances iPhone/iPad ;
- ergonomie tactile ;
- équilibre réel.

Ces points constituent désormais la frontière PC/Godot.
