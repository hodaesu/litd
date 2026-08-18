# Chapitre II — Les traces d'avant la Chute

## Objectif

Le Chapitre II transforme l'enquête en mécanique jouable. Une information n'est pas automatiquement une vérité : le joueur doit croiser des sources, identifier les faux indices et établir des hypothèses à partir de plusieurs preuves indépendantes.

## Parcours jouable

1. Salle des Archives du Sanctuaire — recouper les preuves du Chapitre I.
2. Route des Bornes Muettes — première exploration et premières inscriptions effacées.
3. Poste de Veille Abandonné — embuscade et témoignages antérieurs à la Chute.
4. Camp de la Carrière Blanche — feu de camp et confrontation d'interprétations.
5. Archive Ensevelie — mini-boss : Le Conservateur Brisé.
6. Archive Ensevelie — réunir au moins cinq indices provenant d'au moins deux familles de sources.
7. Station de Résonance — boss : Sahra Vel, La Veilleuse des Bornes.
8. Retour au Sanctuaire — décider comment publier les preuves.

## Enquête

`data/levels/chapter_02_world.json` contient 13 indices. Ils possèdent une provenance, un groupe de source, un niveau d'authenticité, les hypothèses qu'ils soutiennent et les propositions qu'ils contredisent.

Les faux indices ne contribuent jamais à confirmer une hypothèse. Les sources partielles peuvent éclairer l'enquête, mais la confirmation exige les seuils définis dans les données.

Hypothèses principales :

- les anomalies précèdent la Chute ;
- les incidents formaient un réseau cohérent ;
- certaines archives furent volontairement écartées ;
- des acteurs étrangers s'intéressaient aux anomalies avant la catastrophe.

## Le Conservateur Brisé

Ancien gardien d'archives transformé par une obsession de conservation. Il protège les documents contre les héros non parce qu'il sert le Voile, mais parce que sa fonction de protection est devenue absolue.

## Sahra Vel

Ancienne cartographe de la Concorde. Elle protégeait un protocole visant à empêcher la réactivation d'un réseau ancien de résonance.

Phases :

1. Cartographie impossible.
2. Routes superposées.
3. Le chemin interdit.

Signature : **La Carte qui se Souvient**.

À la fin, le joueur choisit de publier immédiatement les preuves, de les confier d'abord aux médiateurs ou de les retenir temporairement.

## Interface

Aucun HUD permanent n'est ajouté en exploration. Les découvertes produisent un retour bref dans le journal de partie. Le détail de l'enquête reste dans le Journal : indices, authenticité, sources indépendantes et hypothèses confirmées.

## Fichiers principaux

- `data/levels/chapter_02_vertical_slice.json`
- `data/levels/chapter_02_world.json`
- `scripts/world/chapter_02_runtime.gd`
- `scripts/world/chapter_02_blockout_builder.gd`
- `scripts/world/chapter_02_clue.gd`
- `scripts/world/chapter_02_boss_runtime.gd`
- `scenes/world/chapter_02/*.tscn`

La fin du chapitre utilise les trois quêtes canoniques de `main_campaign.json` et ouvre `chapter_03_threshold`.
