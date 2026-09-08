# LITD Les Veilleurs — Safe Blender Scaffolds v53

Cette couche prépare le poste de travail Blender pour les 12 maîtres sans fabriquer de modèle, de matériau, de rig osseux ou d'animation de remplacement.

## Ce que crée le scaffolder

Pour chaque maître, le script crée un `.blend` de préparation distinct dans `art/blender/scaffolds_v53/` avec :

- les collections `00_REFERENCE` à `90_EXPORT` du contrat v52 ;
- des `Empty` `TODO_BODY_*` qui indiquent chaque vraie géométrie `BODY_*` à produire ;
- des `Empty` `TODO_STUMP_*` pour les cassures/amputations prévues ;
- des repères `TODO_POSE_F3_*`, `TODO_EQUIP_*`, `TODO_SOCKET_*` ;
- un repère ordonné pour chaque étape de `rig_build_order` ;
- le plan v52 complet embarqué comme Text datablock ;
- des propriétés `litd_not_production_asset=true` empêchant toute ambiguïté de statut.

Il ne crée volontairement **aucun Mesh, Material, Armature, bone ni Action**. Les chemins canoniques `source_blend` ne sont jamais écrasés par cette automatisation.

## Préflight PC

```bash
python -m tools.blender.run_master_scaffolds_v53 --preflight
```

Si Blender n'est pas trouvé, le code blocant est `BLENDER_EXECUTABLE_REQUIRED`.

## Voir tout ce qui sera exécuté

```bash
python -m tools.blender.run_master_scaffolds_v53 --dry-run
```

Un seul maître :

```bash
python -m tools.blender.run_master_scaffolds_v53 --dry-run --master humanoid_standard
```

## Créer les 12 scaffolds

```bash
python -m tools.blender.run_master_scaffolds_v53 --execute
```

Ou uniquement le premier :

```bash
python -m tools.blender.run_master_scaffolds_v53 --execute --master humanoid_standard
```

Le runner appelle Blender en `--background --factory-startup` et génère uniquement les fichiers de préparation `*_scaffold.blend`.

## Passage du scaffold au vrai maître

1. Ouvrir `humanoid_standard_scaffold.blend`.
2. Lire `LITD_SCAFFOLD_v53_README.txt` et `LITD_MODELING_PLAN_v52.json` dans Blender.
3. Commencer le blockout artistique dans `10_BLOCKOUT`.
4. Créer la vraie géométrie dans `20_BODY`; un `TODO_BODY_*` ne doit être remplacé/renommé en `BODY_*` que lorsque la vraie géométrie existe.
5. Produire les vraies cassures/STUMP, puis rig, skin, matériaux, LOD et Actions dans l'ordre v52.
6. Quand le premier maître est réellement validé, sauvegarder la version de production au chemin canonique v51/v52.
7. Exécuter les validations v48/v49/v50 et le contrôle visuel Godot.
8. Recommencer avec le maître 02, puis les suivants jusqu'au 12.

## Règle de vérité

Un scaffold v53 n'est pas un asset de jeu et ne doit jamais être exporté comme tel. Il ne devient pas un vrai maître par simple renommage : la géométrie, le rig, les matériaux, les LOD et les Actions doivent être réellement créés et validés.
