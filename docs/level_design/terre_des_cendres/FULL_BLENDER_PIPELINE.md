# Pipeline Blender complet

Le pré‑Blender dispose maintenant d'un orchestrateur unique couvrant 88 productions :

- 1 bibliothèque de matériaux ;
- 15 environnements de la Terre des Cendres ;
- 52 héros, ennemis, mini-boss et boss ;
- 8 équipements et props de gameplay.

## Objets couverts

Le catalogue des props est dérivé de `data/equipment.json` et complété par les objets nécessaires au blockout : feu de camp, cache de ressources, porte de raccourci, téléporteur ancestral et cadavre récoltable. Chaque job fixe dimensions, LOD, collision, matériau et socket d'interaction.

```bash
python tools/blender/generate_prop_jobs.py
python tools/blender/generate_prop_jobs.py --check
```

Un objet peut être prévisualisé sans Blender :

```bash
python tools/blender/build_prop_scene.py campfire --plan-only
```

## Orchestration complète

Actualiser ou contrôler le manifeste :

```bash
python tools/blender/run_full_pipeline.py
python tools/blender/run_full_pipeline.py --check
```

Lancer toute la production depuis une machine équipée de Blender :

```bash
python tools/blender/run_full_pipeline.py --execute --blender blender
```

Il est également possible de limiter l'exécution à `materials`, `environments`, `characters` ou `props` avec `--stage`.

Le manifeste conserve les dépendances et tous les chemins `.blend`/GLB attendus. La bibliothèque de matériaux est toujours produite avant les autres catégories.
