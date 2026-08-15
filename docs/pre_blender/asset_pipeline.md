# Pipeline 3D → Godot

## Conventions

- Dossiers et fichiers : `snake_case`.
- Unités : métriques ; 1 unité Godot = 1 mètre.
- Origine personnage : au sol, centrée entre les pieds.
- Axe vertical : Y dans Godot.
- Format d'échange principal : glTF 2.0 (`.glb`).
- Textures : noms explicites par matériau et usage.
- Ne jamais écraser un asset source validé sans incrément/version de travail.

## Arborescence cible

```text
assets/
  characters/
    heroes/
    enemies/
    shared/
      rigs/
      materials/
  environments/
    hub/
    ashlands/
    shared/
  props/
  vfx/
  ui/
  audio/
```

Les modèles définitifs `.glb` seront placés près de leur domaine fonctionnel. Les fichiers Blender de travail ne sont pas requis par le runtime Godot et pourront être conservés dans une zone source dédiée si nous décidons de les versionner.

## Contrat d'import

Chaque asset 3D doit posséder : identifiant stable, catégorie, échelle, pivot, matériaux, rig éventuel, animations attendues, collision attendue, statut de validation et chemin Godot cible.

## Qualité

Avant intégration : silhouette lisible, proportions conformes à la planche de référence, matériaux cohérents avec la direction artistique, absence de géométrie inutile, UV exploitables, normales correctes, transformations propres et noms stables.
