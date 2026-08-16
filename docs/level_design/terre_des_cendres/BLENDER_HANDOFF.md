# Terre des Cendres — contrat Blender → Godot

Ce document verrouille le remplacement progressif du blockout par les assets 3D. Le fichier de référence machine est `data/levels/ashlands_blender_handoff.json`.

## Scène Blender

- Unité : mètre, échelle 1:1.
- Axe vertical : +Y dans Godot ; exporter en GLB avec les transformations appliquées.
- Origine de chaque asset au centre de son contact au sol.
- Aucun objet, matériau ou socket ne conserve un nom Blender générique (`Cube`, `Material.001`, etc.).
- Les dimensions du blockout restent la source de vérité jusqu'à validation du playtest.

## Nommage et export

- Mesh : `SM_{kit}_{asset}_{variant}`.
- Collisions dédiées : `COL_{asset}`.
- Points d'ancrage : `SOCKET_{purpose}`.
- Matériaux : `M_{family}_{surface}`.
- LOD : suffixes `LOD0`, `LOD1`, `LOD2`.
- Format d'échange : `.glb`, compatible Godot 4.3.

## Règles de remplacement

1. Importer le GLB sans supprimer le volume de collision du blockout.
2. Aligner le mesh sur le nœud portant `blender_asset_slot`.
3. Vérifier silhouette, largeur des passages et routes de contournement.
4. Tester l'occultation isométrique.
5. Refaire le bake NavigationMesh.
6. Mesurer FPS, draw calls et mémoire sur appareil mobile.
7. Supprimer la collision de blockout uniquement après approbation de la collision finale.

## Limites de gameplay verrouillées

- Personnage de référence : 1,80 m.
- Porte : 1,40 m × 2,40 m minimum.
- Couloir : 2,20 m minimum.
- Escalier : 1,80 m minimum.
- Marche franchissable : 0,45 m maximum.
- Trois matériaux maximum par module architectural.
- Boss et mini-boss doivent rester lisibles dans la brume de cendres.

## Critères d'acceptation

Un asset n'est accepté que si sa silhouette respecte le blockout, si les deux itinéraires restent praticables, si la caméra ne masque pas durablement le groupe, si la navigation est rebakée et si le budget mobile reste conforme.
