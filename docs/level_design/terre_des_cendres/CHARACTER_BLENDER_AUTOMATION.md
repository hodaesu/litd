# Automatisation Blender des personnages

Le catalogue `data/blender/character_jobs.json` transforme les données de jeu en 52 ordres de production Blender :

- 4 héros jouables ;
- 37 ennemis ordinaires ;
- 9 mini-boss uniques ;
- 2 boss.

Chaque ordre verrouille la catégorie, l'archétype, la taille métrique, l'image de référence, les niveaux de détail, la collision, les matériaux, les animations et les sockets d'équipement.

## Régénérer et contrôler le catalogue

```bash
python tools/blender/generate_character_jobs.py
python tools/blender/generate_character_jobs.py --check
```

## Inspecter un plan sans Blender

```bash
python tools/blender/build_character_scene.py aurelien --plan-only
```

## Construire un personnage dans Blender

```bash
blender --background --python tools/blender/build_character_scene.py -- \
  aurelien \
  --output builds/characters/hero/aurelien/aurelien.blend \
  --export-glb builds/characters/hero/aurelien/aurelien.glb
```

Le constructeur crée les collections `BODY`, `ARMATURE`, `EQUIPMENT`, `COLLISION`, `SOCKETS`, `LIGHTING` et `CAMERA`, un mannequin de proportion contrôlée, une armature suivant le contrat humanoïde, une capsule de collision, cinq sockets et une scène de présentation.

Les formes générées sont volontairement des placeholders. Elles servent à valider l'échelle, les silhouettes, les collisions, l'équipement et les animations attendues avant sculpture, retopologie, skinning et textures définitives.
