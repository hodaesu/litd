# Épilogues, postgame et Nouveau Cycle+

## Principe

La campagne principale s'arrête au Chapitre X. Le contenu qui suit n'est pas un Chapitre XI : il montre ce que devient le monde après la décision finale et permet ensuite de recommencer la campagne avec une couche de rejouabilité volontairement plus libre.

Le NG+ est **un dispositif de gameplay et de lecture méta**, pas une boucle temporelle canonique. Le cycle initial reste l'histoire de référence. Une variation NG+ ne peut donc pas réécrire un fait établi, ressusciter rétroactivement un mort du cycle initial ou modifier les limites du Voile.

En revanche, le NG+ a le droit d'accorder au joueur des privilèges de gameplay impossibles pendant le premier cycle. Deux d'entre eux sont désormais explicitement verrouillés :

1. **multi-arbres à partir du Premier retour** ;
2. **recrutement des boss et mini-boss explicitement listés dans le catalogue NG+**.

Ces deux systèmes sont des récompenses de rejouabilité et ne doivent plus être requalifiés comme incohérences narratives.

## Épilogues et Monde d'après

Après `campaign_complete`, le Sanctuaire donne accès au **MONDE D'APRÈS** : épilogue, vignettes conditionnelles, Chronique des cycles, opérations de reconstruction et accès au Nouveau Cycle+.

Le joueur peut continuer le postgame aussi longtemps qu'il le souhaite ou commencer immédiatement un NG+. Les opérations postgame préparent des héritages mais ne constituent jamais une porte obligatoire.

Le NG+ conserve :

- historique des fins ;
- points d'héritage non dépensés ;
- historique des héritages choisis ;
- épilogues archivés.

Il remet à zéro la campagne, les décisions politiques, la progression des personnages, l'inventaire, les créatures du cycle, les ressources courantes et les choix de chapitre.

## Cycle initial : spécialisation exclusive

Pendant la première campagne, chaque héros, ennemi ou créature concernée possède trois arbres de quinze compétences, mais le premier arbre choisi fixe sa spécialisation et verrouille les deux autres.

Cette contrainte donne une identité claire au personnage pendant la découverte initiale du jeu.

## NG+ : les trois arbres s'ouvrent

À partir du **Premier retour**, choisir une compétence dans un arbre ne verrouille plus les deux autres. Le joueur peut investir dans les trois arbres d'un même personnage.

Les arbres ne sont cependant pas fusionnés :

- les coûts de points restent actifs ;
- les niveaux requis restent actifs ;
- les prérequis internes de chaque branche restent actifs ;
- le joueur doit toujours construire sa progression au lieu de tout obtenir automatiquement.

L'effet recherché est volontairement spectaculaire : après avoir appris à vivre avec une spécialisation forte pendant le premier cycle, le joueur découvre que le NG+ lui permet enfin de créer des combinaisons auparavant impossibles.

## NG+ : recrutement des boss et mini-boss

À partir du Premier retour, les boss, mini-boss, boss profonds et mini-boss profonds **présents dans `data/world/ngplus_boss_recruits.json`** peuvent devenir des compagnons via le système NG+.

Leur version alliée :

- conserve son identité, sa signature et son archétype ;
- possède sa propre progression de compagnon ;
- suit le niveau moyen du groupe lorsqu'elle est définie comme adaptative ;
- n'hérite jamais directement des PV ou multiplicateurs de sa version boss ennemie ;
- possède des arbres de compétences adaptés au rôle de compagnon.

Cette mécanique n'affirme pas que l'histoire du cycle initial s'est déroulée autrement. **La version recrutée est un privilège de replay du NG+**.

Le catalogue est explicite : être un boss dans les données du jeu ne suffit pas, à lui seul, à créer automatiquement une version recrutable. Une nouvelle entrée doit être conçue et ajoutée au catalogue.

L'Ange n'est actuellement pas présent dans ce catalogue et reste donc hors de ce système tant qu'une décision explicite ne le modifie pas.

## Contrat « je veux recommencer »

Le Nouveau Cycle+ ne doit jamais se résumer à `+PV / +dégâts`.

La règle de production est : **le joueur doit percevoir une différence importante dans les quinze premières minutes d'un NG+**.

Chaque cycle doit modifier au minimum quatre couches :

1. **Monde** — routes, refuges, patrouilles, quartiers, traces ou zones accessibles changent ;
2. **Donjons** — nouvelles compositions de salles authored, secrets plus présents, dangers propres au cycle ;
3. **Ennemis** — nouveaux comportements et contre-mesures tactiques, pas seulement des statistiques ;
4. **Narration** — textes, observations et fragments secondaires donnent une nouvelle lecture sans changer les faits déjà établis.

Le système est défini dans `data/world/ngplus_cycle_variants.json` et exécuté par `NgPlusCycleDirector`.

## Premier retour — Le monde se décale

Le premier NG+ doit immédiatement produire l'effet : **« Je connais cet endroit… mais ce n'est plus la même partie. »**

Il introduit notamment routes secondaires, traces précédemment invisibles, variations de patrouilles, secrets supplémentaires, dangers de Cendre/Lumière et ennemis capables de punir la garde, devenir plus dangereux blessés ou répandre davantage de Peur.

Les nouveaux textes montrent des couches secondaires du monde. Ils ne remplacent jamais une révélation principale du premier cycle.

## Deuxième veille — Les ennemis apprennent

Le deuxième cycle insiste sur l'adaptation : territoires disputés, refuges fortifiés, routes de contournement, Vestiges rouverts et adversaires qui punissent davantage les habitudes répétées, l'accumulation d'Espoir ou la garde prévisible.

Le joueur ne doit plus pouvoir rejouer mécaniquement la campagne avec exactement les réflexes qui avaient fonctionné auparavant.

## Troisième mémoire — Les couches profondes

Le troisième cycle ouvre davantage de contenu périphérique : quartiers auparavant inaccessibles, archives privées, communautés secondaires et ruines sous les ruines.

Son objectif narratif n'est pas d'ajouter une « vérité secrète supérieure », mais de montrer que les civilisations, responsables et survivants avaient des vies qui débordaient largement leur fonction dans l'intrigue principale.

## Cycle profond — La Concorde des possibles

À partir du quatrième cycle, plusieurs contraintes sont recombinées : zones transformées, frontières instables, coalitions inhabituelles, routes interrompues, Vestiges profonds, dangers supplémentaires et ensemble élargi de mutations ennemies.

Le cycle profond n'a pas besoin d'inventer une nouvelle couche de canon à chaque répétition. Sa valeur vient de la recomposition systémique des règles déjà validées.

## Donjons

Le cycle initial conserve les premières visites mises en scène à la main.

En NG+, une première visite de campagne peut utiliser le générateur hybride : celui-ci ne crée jamais une géométrie arbitraire. Il choisit parmi des salles fabriquées et validées à la main, leurs variantes autorisées, leurs connexions et des dangers compatibles.

Le profil NG+ modifie la seed, augmente modérément la probabilité des branches optionnelles/secrètes et peut ajouter un danger de cycle à une salle non immuable.

Les arènes ou scènes marquées `immutable_staging` restent intactes.

## Ennemis

L'augmentation statistique reste présente (+18 % PV, +12 % dégâts, +8 % Peur par cycle), mais elle est secondaire.

Le NG+ peut aussi attribuer des comportements déterministes selon l'ennemi et le cycle :

- chasser un personnage en garde ;
- provoquer une Rupture de garde ;
- viser celui qui possède le plus d'Espoir ;
- accentuer la pression de Peur ;
- gagner en agressivité sous 50 % de PV ;
- punir les schémas tactiques répétitifs.

## Narration

Une nouvelle ligne NG+ ne doit jamais dire : « le passé a changé ».

Elle peut dire :

- « cette archive n'avait pas été trouvée » ;
- « cette route n'avait pas été empruntée » ;
- « ce groupe n'avait pas été rencontré » ;
- « ce détail donne un autre contexte à un fait connu ».

Ainsi, recommencer **approfondit** l'histoire au lieu de l'annuler.

## Héritages

Un héritage peut être choisi au début du cycle : Mémoire des archives, Réflexes de Concorde, Écouter avant de nommer ou Réserves cachées.

Ils représentent une couche de replay/transmission méta, jamais la preuve que le protagoniste voyage littéralement dans le temps.

## Fichiers principaux

- `data/world/endgame_epilogues.json`
- `data/world/postgame_operations.json`
- `data/world/new_game_plus.json`
- `data/world/ngplus_boss_recruits.json`
- `data/world/ngplus_cycle_variants.json`
- `scripts/core/endgame_state.gd`
- `scripts/core/ngplus_boss_recruitment.gd`
- `scripts/core/ngplus_cycle_director.gd`
- `scripts/core/hero_skill_manager.gd`
- `scripts/core/creature_manager.gd`
- `scripts/core/hybrid_dungeon_generator.gd`
- `scripts/core/enemy_combat_director.gd`

## Règle de cohérence

**Le cycle initial définit l'histoire de référence. Le NG+ peut transformer les possibilités de gameplay et la manière de revisiter cette histoire ; il ne peut pas réécrire rétroactivement ce qui s'est réellement produit dans le canon.**
