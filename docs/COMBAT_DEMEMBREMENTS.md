# Combat — démembrements tactiques

Le démembrement dans **Light in the Dark** n'est pas seulement un effet visuel. Il fait partie du système de combat tactique v4 et doit modifier les décisions du joueur.

## Principe

Chaque ennemi corporel possède une jauge cachée/affichable de **trauma de démembrement**.

Le trauma augmente notamment avec :
- les coups lourds ;
- une cible déjà brisée ;
- une cible étourdie ;
- une cible très affaiblie ;
- **Brise-garde** de Malvor ;
- la puissance réelle du coup.

Le seuil de base est de **100** pour une cible ordinaire et **135** pour un boss.

Quand le seuil est franchi, la prochaine partie corporelle fonctionnelle de son profil peut être perdue. Le trauma restant est conservé après le déclenchement.

## Conséquences fonctionnelles

Le système utilise plusieurs profils corporels : humanoïde, bête, arachnide, aberration et boss.

Exemples :
- perte d'un **bras d'attaque** : dégâts fortement réduits ;
- perte d'une **jambe d'appui** : dégâts réduits et perte possible du prochain tour ;
- perte d'une **mâchoire** : dégâts et pression de Peur réduits ;
- perte d'un **appendice venimeux** : dégâts et Peur réduits ;
- perte d'un **ancrage corporel de boss** : pression de Peur réduite ;
- perte d'un **membre de soutien de boss** : ouverture tactique et étourdissement possible.

Les boss exposent également le flag `boss_dismemberment_changed` et un flag par partie perdue (`dismemberment_<part_id>`) afin que leurs runtimes spécifiques puissent ensuite réagir avec des changements de phase ou de pattern uniques.

## Boss

Un démembrement de boss **ne provoque jamais une mort instantanée**. La règle de Light in the Dark reste : un boss se vainc en comprenant sa mécanique.

Le démembrement devient donc une autre manière de comprendre et transformer cette mécanique : détruire le membre qui porte une attaque, un ancrage, une posture ou une source de Peur peut rendre une phase différente ou créer une fenêtre de contre-jeu.

## Coups de grâce

Les parties marquées `finisher_only`, comme la tête du profil humanoïde générique, ne peuvent être détachées que lorsque la cible est déjà vaincue. Elles sont donc une conséquence visuelle du coup de grâce et jamais une mécanique d'exécution gratuite sur une cible vivante.

## Recrutement NG+

Les blessures de combat ne doivent pas transformer un boss recruté en compagnon définitivement mutilé ou inutilisable. Le recrutement NG+ utilise sa version alliée normalisée ; les états `dismemberment_*` appartiennent à la rencontre ennemie.

## Présentation et accessibilité

La mécanique est indépendante du niveau de gore affiché. Trois modes sont prévus :
- **full** : animation et séparation visuelle complètes ;
- **reduced** : animation lisible mais présentation atténuée ;
- **off** : aucun gore explicite, tout en conservant les conséquences tactiques et l'information UI.

Ainsi, désactiver la représentation graphique ne change jamais l'équilibrage.

## Intégration actuelle

- données : `data/combat_dismemberment.json`
- runtime : `scripts/core/dismemberment_runtime.gd`
- combat : `scripts/ui/main_v4.gd`
- audit : `tools/qa/dismemberment_audit.py`
- tests : `tests/python/test_dismemberment.py`

Le combat v4 hérite du v3 (rangs, déplacements, synergies), lui-même du v2 (quatre héros par round).
