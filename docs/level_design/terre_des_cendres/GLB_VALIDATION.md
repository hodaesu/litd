# Validation des exports GLB

Tout export Blender destiné aux Terres des Cendres doit passer par `tools/blender/validate_glb.py` avant son import dans Godot.

```bash
python tools/blender/validate_glb.py asset.glb --require-lods 3 --require-collision
```

Le validateur contrôle notamment :

- conteneur GLB et glTF 2.0 ;
- présence d'au moins un mesh ;
- noms `SM_`, `COL_`, `SOCKET_` et `M_` ;
- rejet des noms Blender génériques ;
- trois matériaux maximum par mesh modulaire ;
- niveaux LOD exigés ;
- collision dédiée lorsqu'elle est demandée ;
- rapport JSON optionnel avec `--json` pour l'automatisation.

Les sockets absents produisent un avertissement. Les erreurs de format, de nommage, de LOD, de collision ou de matériaux bloquent l'asset.
