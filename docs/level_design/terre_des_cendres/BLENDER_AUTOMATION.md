# Génération automatisée des scènes Blender

`tools/blender/build_ashlands_scene.py` constitue le premier exécuteur du pipeline 3D automatisé. Il consomme directement `ashlands_blender_jobs.json`.

## Prévisualiser un plan sans Blender

```bash
python tools/blender/build_ashlands_scene.py zone_01_faubourg_cendreux --plan-only
```

## Construire une scène dans Blender

```bash
blender --background --python tools/blender/build_ashlands_scene.py -- \
  zone_01_faubourg_cendreux \
  --output builds/blender/zone_01_faubourg_cendreux.blend \
  --export-glb builds/glb/zone_01_faubourg_cendreux.glb
```

L'exécuteur configure automatiquement :

- unités métriques à l'échelle 1:1 ;
- collections environnement, collisions, sockets, éclairage et caméra ;
- volumes modulaires nommés selon le contrat ;
- collisions associées ;
- sockets des rencontres, ressources, cendres, raccourcis, feux et boss ;
- caméra isométrique et lumière de prévisualisation ;
- métadonnées du job et de la zone ;
- sauvegarde `.blend` et export GLB optionnel.

Les volumes produits restent des placeholders. Le logiciel d'automatisation pourra ensuite remplacer leur construction par des générateurs de géométrie, matériaux et textures sans changer le format des jobs.
