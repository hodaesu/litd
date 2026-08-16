# Porte de validation Blender → Godot

La production 3D dispose d'une validation globale avant import dans Godot 4.3.

## Registre d'import

`data/blender/godot_import_registry.json` relie les 75 GLB attendus à une destination unique sous `res://assets/3d/` :

- 15 environnements ;
- 52 personnages ;
- 8 équipements et props.

Le registre conserve le placeholder et sa collision tant que l'asset n'a pas franchi les validations artistiques et techniques.

```bash
python tools/blender/generate_godot_import_registry.py
python tools/blender/generate_godot_import_registry.py --check
```

## Validation de production

```bash
python tools/blender/validate_production_readiness.py \
  --report reports/blender_production_readiness.json
```

Chaque livrable reçoit un état :

- `missing` : Blender ne l'a pas encore produit ;
- `blocked` : GLB invalide ou budget mobile dépassé ;
- `ready` : validation technique et budget réussis.

Les budgets contrôlent taille du GLB, nombre de nœuds, meshes, matériaux et animations selon la catégorie. Les contrôles existants de nommage, LOD, collisions, rigs, skins et animations restent obligatoires.

Avant la production Blender, le contrat seul peut être vérifié sans exiger les fichiers :

```bash
python tools/blender/validate_production_readiness.py --check-contract
```

Godot peut ensuite obtenir le chemin d'un job avec `AshlandsAssetRegistry.get_job_import_path(job_id)` et ne charger le GLB que s'il existe réellement.
