# Épilogues, postgame et Nouveau Cycle+

## Principe

La campagne principale s'arrête au Chapitre X. Le contenu qui suit n'est pas un Chapitre XI : il montre ce que devient le monde après la décision finale et permet ensuite de recommencer la campagne avec une mémoire persistante.

Le postgame suit trois règles :

1. une fin ne devient jamais parfaite après le générique ;
2. les conséquences politiques, sociales et métaphysiques restent visibles ;
3. le Nouveau Cycle+ conserve la mémoire d'une partie, pas sa puissance brute.

## Épilogues

`data/world/endgame_epilogues.json` contient un épilogue complet pour chacune des six orientations réussies et chacun des trois états d'échec.

Chaque épilogue possède quatre temps : ouverture, conséquences quotidiennes, évolution politique et conclusion. Des vignettes conditionnelles complètent le texte selon les décisions de campagne : Saen, sort d'Edras, coexistence avec les créatures, Cercle de Justice et Maison des Délégations.

Le joueur peut ainsi obtenir la même grande orientation finale avec des destins secondaires différents.

## Monde d'après

Après `campaign_complete`, un accès **MONDE D'APRÈS** apparaît au Sanctuaire.

Le joueur y trouve :

- son épilogue ;
- les destins conditionnels ;
- la Chronique des cycles ;
- huit opérations de reconstruction ;
- les règles du Nouveau Cycle+.

Les huit opérations sont :

- rouvrir les routes sûres ;
- poursuivre les audiences ;
- maintenir la Chambre d'Écoute ;
- étendre les habitats libres ;
- entretenir les ancrages ;
- réunir les délégations ;
- écrire la Chronique des pertes ;
- former la prochaine veille.

Les opérations techniques ou matérielles peuvent consommer de l'Or, de l'Essence ou des Vivres. Trois opérations civiques — routes, audiences et Chronique des pertes — restent toujours réalisables même avec des réserves épuisées, afin que le Nouveau Cycle+ ne puisse pas être bloqué par l'économie de fin de partie.

## Déblocage du Nouveau Cycle+

Le Nouveau Cycle+ devient disponible après trois opérations postgame accomplies.

Il conserve :

- l'historique des fins ;
- les points d'héritage non dépensés ;
- l'historique des héritages choisis ;
- les épilogues archivés.

Il remet à zéro :

- la progression de campagne ;
- les décisions politiques ;
- les niveaux et compétences des héros ;
- l'inventaire ;
- les créatures recrutées ;
- les ressources du Sanctuaire ;
- les choix des chapitres.

Cette règle empêche le NG+ de devenir une simple partie avec des personnages surpuissants qui annuleraient les systèmes de survie et de choix.

## Héritages

Un seul héritage peut être choisi au début d'un cycle :

- **Mémoire des archives** : faible avance de connaissance du Voile ;
- **Réflexes de Concorde** : confiance et Cité légèrement renforcées ;
- **Écouter avant de nommer** : petit capital initial envers créatures et Absents ;
- **Réserves cachées** : ressources de départ supplémentaires.

Les héritages coûtent des points gagnés par les opérations postgame.

## Difficulté NG+

Pour chaque cycle supplémentaire :

- PV ennemis : +18 % ;
- dégâts ennemis : +12 % ;
- Peur infligée : +8 %.

Le multiplicateur s'applique aux ennemis ordinaires, mini-boss, boss de chapitre et boss des Vestiges profonds.

## Sauvegarde

Le schéma de sauvegarde passe en **0.31** et ajoute `endgame`.

Cet état contient les opérations terminées, points d'héritage, numéro de cycle, héritage courant, historique des fins et archives d'épilogues.

## Fichiers principaux

- `data/world/endgame_epilogues.json`
- `data/world/postgame_operations.json`
- `data/world/new_game_plus.json`
- `scripts/core/endgame_state.gd`
- `scripts/ui/endgame_ui.gd`
- `scripts/world/ashlands_combat_bridge.gd`
- `scripts/core/save_manager.gd`
- `tests/python/test_endgame_postgame_ngplus.py`
