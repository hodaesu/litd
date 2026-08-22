# Direction corporelle et animations d'état

Le gameplay reste autoritaire dans Godot. Blender produit les clips, poses additives, rigs et marqueurs demandés par `data/body_state_animation_contract.json`.

## Couches

1. action principale ;
2. psychologie ;
3. état physique ;
4. réaction ;
5. signature corporelle du personnage ;
6. intention relationnelle.

Une couche psychologique ne change jamais silencieusement les dégâts, la portée ou le moment logique d'un impact. Elle peut modifier la silhouette, l'amplitude, le regard, la respiration et la récupération visuelle.

## États à produire

- Peur : tendu, terrifié, panique ;
- Folie : fracturé ;
- afflictions : colère et désespoir ;
- Espoir : posture redressée ;
- blessures : protection de plaie, critique et boiterie ;
- relations : protéger, rassurer, éviter et menacer.

## Combat

Chaque action doit exporter ses marqueurs obligatoires. L'impact Godot doit correspondre au marqueur visuel. Les déplacements de rang peuvent utiliser un root motion autorisé ; les autres attaques reviennent à leur ancre tactique.

## Première passe Blender

1. Darius : neutre, peur tendue/terrifiée, blessure, boiterie, attaque légère/lourde et garde.
2. Goule affamée : locomotion basse, peur/retraite, bond, griffes, stagger et mort.
3. Vérifier les marqueurs et la silhouette dans Godot.
4. Corriger le contrat commun avant de produire les autres héros.
