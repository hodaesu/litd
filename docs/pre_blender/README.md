# Light in the Dark — Préproduction avant Blender

Ce dossier définit tout ce qui doit être verrouillé avant la production 3D.

## Objectif

Faire de Blender une étape de fabrication, et non une étape de conception. Les règles de gameplay, données, conventions d'assets, dimensions, pivots, rigs, animations attendues, matériaux, LOD et intégration Godot doivent être spécifiés ici avant la création des modèles définitifs.

## État actuel constaté

Le dépôt contient déjà une base Godot, des données JSON, des scripts core/UI, une scène principale, des assets 2D de héros/ennemis/environnements, des tests Python et une CI GitHub.

## Lots à préparer avant Blender

1. `asset_pipeline.md` — conventions d'import/export et nomenclature.
2. `character_3d_spec.md` — standard commun héros/ennemis, incluant squelettes masculin et féminin.
3. `environment_3d_spec.md` — modules du Sanctuaire des Cendres et de la Terre des Cendres.
4. `animation_manifest.md` — liste des animations nécessaires au gameplay.
5. `blender_handoff_checklist.md` — définition de « prêt pour Blender ».
6. `content_registry.json` — registre machine-readable des assets 3D à produire.

## Principe d'organisation

Les noms de fichiers et dossiers destinés à Godot utilisent `snake_case`. Les contenus 3D seront regroupés par fonctionnalité/personnage/environnement afin que scènes, scripts et ressources associées restent faciles à maintenir.
