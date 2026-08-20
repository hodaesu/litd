# Flux de données du vertical slice

`data/visual_vertical_slice.json` est la source de vérité du pass 27. Les scripts Godot lisent ce contrat pour les chemins GLB, animations et valeurs de mini-combat. Les outils Python lisent le même contrat pour les budgets et revues. Les jobs Blender référencent les mêmes assets afin d'éviter des conventions divergentes entre production et runtime.
