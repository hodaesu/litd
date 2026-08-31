# Épilogues, postgame et Nouveau Cycle+

## Principe

La campagne principale s'arrête au Chapitre X. Le contenu qui suit n'est pas un Chapitre XI : il montre ce que devient le monde après la décision finale et permet ensuite de recommencer la campagne avec une mémoire persistante.

Le postgame suit quatre règles :

1. une fin ne devient jamais parfaite après le générique ;
2. les conséquences politiques, sociales et métaphysiques restent visibles ;
3. le Nouveau Cycle+ conserve la mémoire d'une partie, pas sa puissance brute ;
4. le Nouveau Cycle+ approfondit les règles identitaires du jeu au lieu de les supprimer.

## Épilogues

`data/world/endgame_epilogues.json` contient un épilogue complet pour chacune des orientations réussies et chacun des états d'échec.

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

Le Nouveau Cycle+ devient disponible dès que la campagne est terminée. Les opérations postgame restent recommandées pour préparer des héritages, mais ne constituent pas une porte obligatoire.

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

## Les trois arbres restent exclusifs

L'exclusivité des trois arbres est une règle identitaire de LITD 1 et **ne disparaît jamais en Nouveau Cycle+**.

Chaque héros, ennemi et créature recrutée possède trois arbres de quinze compétences. Lorsqu'un personnage choisit son arbre, les deux autres restent verrouillés pour ce personnage, quel que soit le numéro du cycle.

Le NG+ peut proposer :

- davantage de situations où chaque spécialisation révèle une solution différente ;
- des variations d'ennemis exploitant mieux leur propre arbre ;
- de nouveaux Serments, contraintes ou héritages ;
- des variantes d'équipement et de rencontres ;
- des informations narratives liées aux cycles précédents.

Il ne transforme jamais les personnages en builds capables de cumuler les trois spécialisations. Une mémoire de cycle enrichit la compréhension du joueur, pas l'ensemble des capacités du personnage.

## Recrutement et statut des boss

Le Nouveau Cycle+ **ne rend pas tous les boss et mini-boss capturables**.

Le recrutement par capture appartient au système des créatures ordinaires explicitement éligibles. Les catégories suivantes restent distinctes :

- créature capturable ;
- adversaire épargné ;
- personne arrêtée ;
- suspect ou accusé soumis à la justice ;
- personnage coopérant volontairement ;
- boss ou entité narrative non recrutables.

L'action générique **CAPTURER** ne peut donc jamais remplacer une arrestation, un procès, une alliance consentie ou une décision sur le statut d'une personne.

### Exclusions absolues actuelles

- **l'Ange**, boss explicitement non capturable ;
- les boss et mini-boss, sauf future décision canonique individuelle et explicite ;
- les humains et autres personnes conscientes traitées comme responsables moraux ou sujets de justice ;
- Edras Nhal et les autres responsables vivants ;
- les fondateurs et figures historiques ;
- toute entité dont le recrutement effacerait une conséquence canonique.

`data/world/ngplus_boss_recruits.json` est donc désactivé par l'audit de cohérence. Toute exception future devra définir le type de relation approprié à l'entité au lieu d'hériter automatiquement du verbe de capture.

## Héritages

Un seul héritage peut être choisi au début d'un cycle :

- **Mémoire des archives** : faible avance de connaissance du Voile ;
- **Réflexes de Concorde** : confiance et Cité légèrement renforcées ;
- **Écouter avant de nommer** : petit capital initial envers créatures et Absents ;
- **Réserves cachées** : ressources de départ supplémentaires.

Les héritages coûtent des points gagnés par les opérations postgame.

Ils représentent des traces transmises ou des préparations héritées, jamais une preuve que le même personnage se souvient littéralement d'une chronologie réinitialisée. Le NG+ reste une structure de jeu et de mémoire méta ; il ne crée pas de boucle temporelle canonique dans le monde.

## Difficulté NG+

Pour chaque cycle supplémentaire :

- PV ennemis : +18 % ;
- dégâts ennemis : +12 % ;
- Peur infligée : +8 %.

Le multiplicateur s'applique aux ennemis ordinaires, mini-boss, boss de chapitre et boss des Vestiges profonds sans modifier leur statut narratif.

## Sauvegarde

L'état `endgame` conserve les opérations terminées, points d'héritage, numéro de cycle, héritage courant, historique des fins et archives d'épilogues.

Les anciens champs de sauvegarde liés au multi-arbre ou au recrutement généralisé des boss doivent être ignorés ou migrés sans réactiver ces règles obsolètes.

## Fichiers principaux

- `data/world/endgame_epilogues.json`
- `data/world/postgame_operations.json`
- `data/world/new_game_plus.json`
- `data/world/ngplus_boss_recruits.json` — catalogue désactivé
- `scripts/core/endgame_state.gd`
- `scripts/core/hero_skill_manager.gd`
- `scripts/core/creature_manager.gd`
- `scripts/ui/endgame_ui.gd`
- `scripts/world/ashlands_combat_bridge.gd`
- `scripts/core/save_manager.gd`

## Règle de cohérence

Le NG+ ne possède aucune autorité pour contourner les règles du canon principal. S'il propose une variation qui contredit le statut d'une personne, l'exclusivité d'un arbre, une conséquence narrative ou une limite du Voile, c'est la variation NG+ qui doit être corrigée.
