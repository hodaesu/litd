# LITD — Blender Master Models v51

Ce dossier est le point d'entrée PC pour les **7 maîtres mutualisés**. Les cinq boss utilisent leurs dossiers `art/blender/bosses/<id>/` définis par v48/v51.

## Ordre obligatoire de production

1. `humanoid_standard.blend`
2. `construct_biped.blend`
3. `humanoid_massive.blend`
4. `quadruped.blend`
5. `insectoid.blend`
6. `serpentine.blend`
7. `amorphous.blend`
8. `bosses/ishar_gardien_du_passage/ishar_gardien_du_passage_animation_master.blend`
9. `bosses/orateur_sans_voix/orateur_sans_voix_animation_master.blend`
10. `bosses/mere_des_veines/mere_des_veines_animation_master.blend`
11. `bosses/porte_cendres_blanc/porte_cendres_blanc_animation_master.blend`
12. `bosses/le_copiste/le_copiste_animation_master.blend`

Les dossiers techniques correspondants sont dans `data/blender/master_models_v51/` et doivent être traités un par un dans le même ordre.

## Pour chaque maître

1. Créer/importer la géométrie de base puis la transformer jusqu'à obtenir la direction LITD. Ne pas considérer une base tierce comme le modèle final.
2. Construire le rig indiqué par le dossier v51 et conserver les unités Blender/Godot cohérentes.
3. Séparer les parties nécessaires en `BODY_<part>` et préparer les variantes `STUMP_<part>`.
4. Préparer les aides `POSE_F3_<part>` et les objets `EQUIP_<slot>`.
5. Ajouter les sockets d'armes uniquement lorsque la morphologie en possède.
6. Créer les Actions P0 demandées par v47/v48. Une Action doit contenir de vraies clés artistiques; un placeholder vide n'est pas accepté.
7. Tester au minimum F0, un F3 et un F4 pertinent avant export.
8. Lancer le préflight v50, puis l'export v48 et la validation Godot v49.

## Commandes PC

```bash
python -m tools.pipeline.run_p0_animation_pipeline_v50 --dry-run
python -m tools.pipeline.run_p0_animation_pipeline_v50 --preflight
python -m tools.pipeline.run_p0_animation_pipeline_v50 --execute
```

`--execute` doit rester bloqué tant que Blender, Godot ou l'un des douze vrais fichiers `.blend` manque.

## Règle de vérité

Les fichiers JSON v51 sont des **dossiers de fabrication**, pas des modèles 3D. Un maître devient terminé uniquement quand sa géométrie, son rig, ses états corporels et ses Actions sont réellement présents dans Blender, puis exportés et validés dans Godot.
