# Terre des Cendres — statut blockout Pré-Blender

## Implémenté dans Godot
- manifeste de blockout pour les 15 zones ;
- scène dédiée pour chaque zone ;
- constructeur procédural de blockout à partir du manifeste ;
- sol et limites de collision ;
- points d'entrée et sorties inter-zones ;
- marqueurs de raccourcis persistants ;
- emplacements de rencontres ;
- emplacements de ressources ;
- volumes de cendres ;
- feux de camp ;
- emplacement du boss final ;
- règles runtime de découverte de zones et de raccourcis ;
- règles garantissant que les cendres ne cachent jamais boss ou mini-boss ;
- règle imposant un chemin alternatif si un mini-boss normal est présent ;
- support des deux zones secrètes et du téléporteur Abbaye ↔ Crypte ;
- autoload `AshlandsRuntime` enregistré dans `project.godot`.

## Ce que le blockout permet avant Blender
Le projet peut maintenant matérialiser chaque zone à son échelle cible avec primitives et collisions, puis positionner les futurs chemins, bâtiments temporaires, rencontres et ressources sans attendre les meshes définitifs.

## Reste à faire avant Blender
- enrichir progressivement la géométrie grise zone par zone ;
- navigation/pathfinding ;
- transition effective entre scènes ;
- déclencheurs de rencontre ;
- volumes de cendres avec rendu/visibilité temporaire ;
- objets interactifs et ressources temporaires ;
- logique de feu de camp et provisions ;
- rotation runtime des mini-boss ;
- branchement sauvegarde sur `AshlandsRuntime` ;
- tests de parcours et ajustements d'échelle.

Les modèles Blender viendront remplacer les volumes gris sans modifier la logique de niveau.

## Mise à jour
Les 15 zones disposent désormais d'un plan d'implantation authored dans `data/levels/ashlands_zone_blueprints.json`. Le constructeur utilise ces coordonnées pour les routes, rencontres, ressources, cendres, raccourcis, feux de camp et boss. Les anciens placements procéduraux ne servent plus que de repli de sécurité si une donnée manque.
