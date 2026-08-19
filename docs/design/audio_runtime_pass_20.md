# Pass 20 — Audio runtime audible, emitters 2D/3D et crossfades

## Objectif

Le pass 19 avait posé le directeur audio, les bus, les états et les contrats de cues. Le pass 20 rend cette architecture immédiatement audible sans prétendre que les masters finaux sont déjà produits.

Le principe est double :

1. une petite banque PCM originale et procédurale fournit des prototypes locaux audibles ;
2. les bibliothèques de musique/SFX externes restent des catalogues de production tant que leurs fichiers exacts n'ont pas été téléchargés, vérifiés, archivés et ingérés.

Aucun téléchargement réseau n'est effectué pendant le jeu.

## Banque prototype locale

`PrototypeAudioBank` génère et met en cache des `AudioStreamWAV` mono 8-bit à 16 kHz pour le prototype technique. Cette qualité n'est pas la qualité cible du jeu : elle sert à valider le rythme, la spatialisation, le mixage, les transitions et les déclencheurs sur desktop et mobile sans gonfler le dépôt.

Les prototypes couvrent notamment :

- pas cendre et pierre ;
- confirmation UI et télégraphe de combat ;
- battement, respiration, acouphène et sting de Panique ;
- présence et changement de phase de boss ;
- vent des Terres de Cendre ;
- lits musicaux exploration, menace, combat, boss, victoire coûteuse et retraite.

Ils sont marqués `prototype_only`, ne contiennent aucun matériau tiers et sont conçus pour être remplacés sans changer les cue IDs.

## Source externe déjà vérifiée

Le catalogue conserve la source OpenGameArt **Footsteps** de GboxMikeFozzy, indiquée CC0 sur la page de l'asset et composée de six fichiers OGG nommés `01-footstep.ogg` à `06-footstep.ogg`.

Source : https://opengameart.org/content/footsteps-0

Le statut reste explicitement `license_verified_binary_not_vendored` : la licence et les noms de fichiers sont documentés, mais le dépôt ne prétend pas contenir les binaires tant qu'ils n'ont pas été ingérés avec leur preuve et leur hash.

## SfxRuntime

`SfxRuntime` résout une cue vers un stream local puis choisit un émetteur :

- `AudioStreamPlayer` pour UI, psychologie subjective et sons non positionnels ;
- `AudioStreamPlayer3D` lorsqu'une cue 3D reçoit `position_3d`.

Le bus est choisi par domaine et peut être explicitement défini par l'asset. Les émetteurs one-shot sont libérés à la fin du son et la polyphonie globale est bornée.

Les loops contextuelles sont gérées séparément afin qu'une ambiance comme `wind_ashlands` reste active pendant l'exploration sans être relancée à chaque événement.

## Pas d'exploration

`ExplorationPartyController` émet désormais des pas réels pendant le déplacement :

- fréquence différente marche/course ;
- position 3D transmise au runtime ;
- pierre dans les lieux construits/cryptes/archives ;
- cendre ailleurs dans le blockout des Terres de Cendre.

Ce routage reste un prototype : les futures surfaces physiques devront remplacer la déduction par nom de zone.

## Crossfades musicaux

`AudioDirector` maintient deux `AudioStreamPlayer` musicaux A/B. Lorsqu'une nouvelle cue possède un stream local :

- le nouveau player démarre silencieux ;
- l'ancien descend ;
- le nouveau monte en parallèle ;
- l'ancien est arrêté et vidé en fin de transition.

La durée est actuellement de `1.15 s` dans `data/audio_director.json`.

Le directeur tente d'abord un `local_path` réellement présent dans `MusicLibrary`. Si aucun master vérifié n'est local, il peut utiliser le prototype généré correspondant. Le snapshot distingue `catalog_local`, `prototype_generated` et `none`.

## Peur et boss

Les profils de Peur ne changent pas : ils modifient toujours le mix. Le pass 20 ajoute maintenant des sons réellement jouables pour les battements, respirations, acouphènes et Panique.

Les boss possèdent également des sons locaux de présence et de changement de phase. Le télégraphe tactique reste prioritaire dans le mix.

## Ce qui reste volontairement à faire

- remplacer les lits procéduraux par les masters musicaux retenus ;
- ingérer les fichiers CC0/CC BY exacts avec preuve et hash ;
- produire les signatures finales LITD de boss et d'ultimes ;
- ajouter des surfaces physiques précises pour les pas ;
- ajouter occlusion/réverbération 3D par zones ;
- étendre AudioDirector aux dialogues, au Sanctuaire, à la météo et aux mises en scène narratives ;
- tester le mix final sur haut-parleur iPhone et casque.

## QA

Le pass possède :

- `tools/qa/audio_runtime_audit.py` ;
- `tests/test_audio_runtime.py` ;
- `scenes/tests/audio_runtime_smoke.tscn` ;
- un smoke Godot qui vérifie PCM réel, 2D, 3D, loops, crossfade, combat, boss et Peur.
