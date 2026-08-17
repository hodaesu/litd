# Revue visuelle automatisée des assets Blender

La file `data/blender/visual_review_queue.json` couvre les 87 GLB attendus par Godot.

## Rendus de contrôle

- environnements : quatre vues isométriques en 1024 × 1024 ;
- personnages : turntable de huit angles en 512 × 512 ;
- équipements et props : turntable de huit angles en 512 × 512 ;
- fond transparent et noms de fichiers déterministes.

Prévisualiser le plan sans Blender :

```bash
python tools/blender/render_asset_preview.py character_aurelien --plan-only
```

Produire les images depuis Blender :

```bash
blender --background --python tools/blender/render_asset_preview.py -- character_aurelien
```

Les PNG sont rangés sous `reports/visual_reviews/{job_id}/`.

## Critères d'approbation

Les critères changent selon la catégorie. Ils couvrent notamment silhouette, échelle, lisibilité du cel shading, parcours critique, voie d'évitement des mini-boss, visibilité dans les cendres, déformations du rig, sockets, collisions et LOD.

Une décision est enregistrée avec un fichier JSON donnant exactement un booléen pour chaque critère :

```bash
python tools/blender/record_asset_review.py character_aurelien \
  --decision approved \
  --gates reports/aurelien_gates.json \
  --note "Silhouette et animations lisibles"
```

L'outil refuse une approbation si un seul critère échoue. Chaque nouvelle décision est ajoutée à l'historique et le résumé indique le nombre d'assets approuvés, à corriger ou encore en attente.

Les scripts automatisent les vues et la traçabilité ; l'appréciation artistique finale reste une décision humaine.
