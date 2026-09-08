# LITD Les Veilleurs — Blender Scene Validation Runbook v53

Ce runbook exécute le validateur `tools/blender/validate_master_model_scene_v53.py` sur les **vrais fichiers Blender**. Il ne crée aucun modèle et ne transforme jamais une absence d'asset en faux succès.

## Préparation de session PC

Depuis la racine du dépôt, générer d'abord le plan d'export v48 consommé par le validateur :

```bash
python -m tools.blender.generate_animation_export_plan_v48
```

Cette commande ne fabrique aucune animation ni aucun `.blend` : elle matérialise uniquement la liste canonique des 12 bundles et des 320 Actions P0 attendues. La relancer après toute modification des lots v47/v48.

## Stades de validation

- `blockout` : unités, collections et objets `BODY_*`.
- `damage` : ajoute les géométries `STUMP_*`/cassures et marqueurs `POSE_F3_*`.
- `rig` : ajoute armature, `ROOT`, sockets et limite de quatre influences par sommet.
- `lod` : ajoute les variantes LOD1/LOD2 de chaque frontière BODY.
- `animation` : ajoute les vraies Actions P0 exigées par v48 et refuse les Actions sans durée/keyframes réels.
- `final` : ajoute les contrôles spéciaux Ishar/Le Copiste et le contrôle budget; reste suivi d'une validation humaine et de v49/v50 dans Godot.

Utiliser `--strict-budget` uniquement lorsque le budget triangles doit devenir bloquant. Sans ce flag, un dépassement est rapporté comme avertissement pour permettre le profilage sur appareil réel.

## Ordre canonique — un maître terminé avant le suivant

```bash
blender --background art/blender/animation_masters/humanoid_standard.blend --python tools/blender/validate_master_model_scene_v53.py -- --master-id humanoid_standard --stage final --report build/blender_validation/01_humanoid_standard.json
blender --background art/blender/animation_masters/construct_biped.blend --python tools/blender/validate_master_model_scene_v53.py -- --master-id construct_biped --stage final --report build/blender_validation/02_construct_biped.json
blender --background art/blender/animation_masters/humanoid_massive.blend --python tools/blender/validate_master_model_scene_v53.py -- --master-id humanoid_massive --stage final --report build/blender_validation/03_humanoid_massive.json
blender --background art/blender/animation_masters/quadruped.blend --python tools/blender/validate_master_model_scene_v53.py -- --master-id quadruped --stage final --report build/blender_validation/04_quadruped.json
blender --background art/blender/animation_masters/insectoid.blend --python tools/blender/validate_master_model_scene_v53.py -- --master-id insectoid --stage final --report build/blender_validation/05_insectoid.json
blender --background art/blender/animation_masters/serpentine.blend --python tools/blender/validate_master_model_scene_v53.py -- --master-id serpentine --stage final --report build/blender_validation/06_serpentine.json
blender --background art/blender/animation_masters/amorphous.blend --python tools/blender/validate_master_model_scene_v53.py -- --master-id amorphous --stage final --report build/blender_validation/07_amorphous.json
blender --background art/blender/bosses/ishar_gardien_du_passage/ishar_gardien_du_passage_animation_master.blend --python tools/blender/validate_master_model_scene_v53.py -- --master-id boss_ishar --stage final --report build/blender_validation/08_boss_ishar.json
blender --background art/blender/bosses/orateur_sans_voix/orateur_sans_voix_animation_master.blend --python tools/blender/validate_master_model_scene_v53.py -- --master-id boss_orateur_sans_voix --stage final --report build/blender_validation/09_boss_orateur_sans_voix.json
blender --background art/blender/bosses/mere_des_veines/mere_des_veines_animation_master.blend --python tools/blender/validate_master_model_scene_v53.py -- --master-id boss_mere_des_veines --stage final --report build/blender_validation/10_boss_mere_des_veines.json
blender --background art/blender/bosses/porte_cendres_blanc/porte_cendres_blanc_animation_master.blend --python tools/blender/validate_master_model_scene_v53.py -- --master-id boss_porte_cendres_blanc --stage final --report build/blender_validation/11_boss_porte_cendres_blanc.json
blender --background art/blender/bosses/le_copiste/le_copiste_animation_master.blend --python tools/blender/validate_master_model_scene_v53.py -- --master-id boss_le_copiste --stage final --report build/blender_validation/12_boss_le_copiste.json
```

Pendant la production, remplacer `--stage final` par le stade courant permet de valider tôt sans exiger prématurément LOD ou Actions.

## Règles spéciales

**Ishar** : le validateur recherche des noms de datablocks évoquant câbles, pistons, armes à feu, exosquelette, néon ou servo et bloque ces signaux. Le contrôle humain reste obligatoire pour confirmer basalte/obsidienne, fer forgé, bronze terni, silhouette de sentinelle antique et noyau mémoire en reliquaire sacré.

**Le Copiste** : le validateur recherche les mots interdits dans les datablocks et analyse les couleurs numériques de matériaux/lumières/World pour détecter les teintes violet/pourpre/magenta/lilas. Ce scan complète mais ne remplace pas l'examen humain des textures et VFX. La `COPY_MATRIX` doit rester un reliquaire manuscrit/sceau d'encre ancien, et aucune Action copiée ne peut inventer un membre F4.

## Après un PASS `final`

Un `PASS` v53 signifie seulement que la scène Blender ouverte satisfait les contrôles automatisables du stade demandé. Pour déclarer un maître terminé : contrôle visuel humain Blender → export GLB → import forcé Godot → validateur v49 → pipeline v50 → contrôle visuel humain dans le cadrage mobile réel. Ensuite seulement on passe au maître suivant.
