# Matériaux, textures et animations pré-Blender

Ce lot verrouille la direction dark fantasy en cel shading lisible et prépare les contrôles automatiques avant production artistique définitive.

## Bibliothèque de matériaux

`data/blender/material_profiles.json` définit huit profils partagés couvrant peau, tissu, métal, pierre, bois, os, sol cendreux et braises. Chaque profil fournit :

- trois valeurs de lumière franches pour le cel shading ;
- couleurs sombres mais non bouchées ;
- rugosité, métal et émission ;
- palette procédurale embarquée ;
- nommage compatible GLB/Godot ;
- budget mobile de trois matériaux maximum par mesh.

Prévisualisation sans Blender :

```bash
python tools/blender/build_material_library.py --plan-only
```

Construction du fichier Blender :

```bash
blender --background --python tools/blender/build_material_library.py -- \
  --output builds/materials/litd_material_library.blend
```

## Validation des personnages animés

Le validateur refuse un GLB de personnage dépourvu de skin, de nœud `RIG_`, de mesh `SK_`, de canaux d'animation ou de l'une des six animations minimales : `idle`, `walk`, `run`, `attack`, `hit`, `death`.

```bash
python tools/blender/validate_character_glb.py builds/characters/hero/aurelien/aurelien.glb
```

Ces contrôles ne remplacent pas la validation artistique des déformations. Ils empêchent qu'un export techniquement incomplet entre dans Godot.
