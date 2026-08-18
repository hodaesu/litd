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

## Répartition libre entre les trois arbres

À partir du **Premier retour** (`active_cycle >= 1`), le verrou de spécialisation disparaît pour les héros et tous les compagnons.

Le joueur peut donc répartir ses points librement entre :

- **Offensif** ;
- **Défensif** ;
- **Spécial**.

Cette liberté s'applique aux héros, aux créatures ordinaires recrutées et aux mini-boss/boss recrutés en NG+.

Le NG+ ne donne cependant aucune compétence gratuitement. Restent obligatoires :

- le coût en points de compétence ;
- le niveau requis de chaque nœud ;
- les prérequis internes de l'arbre : pour acheter un nœud avancé, il faut toujours avoir acquis les nœuds précédents de cette même branche.

Le cycle initial conserve le fonctionnement original : la première branche investie devient la spécialisation du personnage ou compagnon et les deux autres arbres sont verrouillés.

Dans les écrans de talents du NG+, les trois branches sont signalées **OUVERT NG+** afin de rendre cette règle immédiatement visible.

## Recrutement des mini-boss et boss

À partir du **Premier retour** (`active_cycle >= 1`), tous les mini-boss et boss de la campagne ainsi que ceux des Vestiges profonds peuvent être recrutés avec l'action de combat **CAPTURER**.

Ils sont identifiés par leur `encounter_id`, et non par les IDs ennemis génériques `30` et `38`. Cela garantit que chaque boss conserve exactement son nom, sa signature et son archétype.

Le recrutement reste exigeant :

- un mini-boss doit être descendu sous environ 18 % de ses PV ;
- un boss de chapitre sous environ 12 % ;
- un mini-boss de Vestige sous environ 15 % ;
- un boss de Vestige sous environ 10 %.

Ils demandent également davantage d'Essence et possèdent une résistance supérieure au lien.

Leur version alliée **ne conserve jamais les PV ou multiplicateurs de leur version ennemie**. À la place :

- son niveau est synchronisé avec le **niveau moyen actuel des héros de la compagnie** ;
- si le groupe progresse, le boss recruté se synchronise automatiquement ;
- son expérience personnelle ne peut pas le faire dépasser artificiellement le groupe ;
- ses dégâts utilisent une plage de compagnon propre à son rang puis le scaling normal des créatures ;
- il conserve sa signature et reçoit trois branches de compétences : offensive, défensive et spéciale ;
- les nœuds de signature sont générés selon son archétype : gardien, tacticien, soutien, frappeur ou contrôle.

Le cycle initial conserve l'ancienne règle : **aucun boss ou mini-boss n'y est recrutable**.

Les définitions sont centralisées dans `data/world/ngplus_boss_recruits.json` et le runtime dans `scripts/core/ngplus_boss_recruitment.gd`.

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

Le schéma de sauvegarde reste en **0.31** : la liberté multi-arbre dépend directement du numéro de cycle déjà stocké dans `endgame`, et les informations des boss recrutés sont stockées dans les dictionnaires de créatures existants.

L'état `endgame` conserve les opérations terminées, points d'héritage, numéro de cycle, héritage courant, historique des fins et archives d'épilogues.

## Fichiers principaux

- `data/world/endgame_epilogues.json`
- `data/world/postgame_operations.json`
- `data/world/new_game_plus.json`
- `data/world/ngplus_boss_recruits.json`
- `scripts/core/endgame_state.gd`
- `scripts/core/ngplus_boss_recruitment.gd`
- `scripts/core/hero_skill_manager.gd`
- `scripts/core/creature_manager.gd`
- `scripts/ui/ngplus_skill_tree_ui.gd`
- `scripts/ui/endgame_ui.gd`
- `scripts/world/ashlands_combat_bridge.gd`
- `scripts/core/save_manager.gd`
- `tests/python/test_endgame_postgame_ngplus.py`
- `tests/python/test_ngplus_boss_recruitment.py`
- `tests/python/test_ngplus_multitree_skills.py`
