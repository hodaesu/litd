# LITD : Les Veilleurs — handoff des assets finaux

Ce document définit ce qui doit être **spécifié avant PC** et ce qui doit être **produit/validé sur poste ou appareil réel**.

## Source unique

Le contrat machine est `data/veilleurs/final_asset_handoff_contract.json`. Il référence les sources canoniques des 4 Veilleurs, 24 ennemis, 5 boss, 6 donjons, 12 ultimes, chorégraphies et règles de polish.

Le gameplay reste autoritaire. Une animation, caméra, VFX, piste audio ou vibration ne peut jamais modifier une règle pour faciliter la présentation.

## Groupes de production

Le handoff couvre :

- 4 Veilleurs ;
- 24 ennemis ;
- 5 boss ;
- 6 donjons ;
- Refuge des Cendres ;
- UI 2D ;
- blessures, amputations, sang et cadavres persistants ;
- 12 packages d’ultimes signatures.

Chaque groupe possède un `output_root`, des slots obligatoires et l’état `spec_ready_pc_production_pending` tant que les fichiers finaux n’ont pas été produits et validés.

## Packages des 12 ultimes

Chaque ultime exige six familles d’assets : `animation`, `camera`, `vfx`, `audio`, `haptic`, `ui`.

Les variantes accessibilité restent obligatoires : mouvement réduit, absence de secousse écran, gore réduit, flashes réduits, haptique désactivée et mode ultime court. Ces variantes ne modifient jamais les mécaniques.

Les noms de packages sont déterministes à partir de l’ID canonique de l’ultime. Le resolver signature reste celui du registre `data/veilleurs/v08/canonical_watcher_ultimates_12.json` et la mise en scène reste liée à `data/veilleurs/ultimate_choreography_contract.json`.

## Sur le PC

Initialiser le suivi :

```bat
tools\workstation\LITD_VEILLEURS_ASSET_HANDOFF.cmd init
```

Lister tous les jobs :

```bat
tools\workstation\LITD_VEILLEURS_ASSET_HANDOFF.cmd jobs
```

Enregistrer un slot terminé avec sa preuve :

```bat
tools\workstation\LITD_VEILLEURS_ASSET_HANDOFF.cmd record --item ULT_WATCHER_NAYRA_BASTION --slot animation --status done --evidence "chemin ou rapport de validation"
```

Un slot marqué `done` sans preuve est refusé. L’état global est consultable avec :

```bat
tools\workstation\LITD_VEILLEURS_ASSET_HANDOFF.cmd status
```

La production n’est considérée complète que lorsque tous les slots requis disposent d’une preuve. La lisibilité, l’audio, l’haptique et les performances finales restent ensuite soumis aux huit gates matériels de l’issue #187.

## Règles techniques

- Godot 4.3 reste propriétaire de l’import/runtime.
- Les assets 3D de combat doivent prévoir LOD et collision proxy séparée du mesh visuel.
- La baisse de LOD visuel des cadavres ne supprime jamais leur Rémanence logique.
- Les états de blessures et amputations doivent rester cohérents avec l’anatomie runtime.
- Aucun texte localisé ne doit être peint directement dans un atlas UI.
- La cible est mobile-first ; les assets doivent ensuite rester lisibles tablette et desktop.

## Audit avant PC

`tools/qa/veilleurs_final_asset_handoff_audit.py` vérifie les comptes canoniques, les 12 packages, les resolvers, les chorégraphies, les conventions de nommage, les groupes de production et les contraintes d’accessibilité.

Un audit vert signifie uniquement : **les spécifications sont prêtes pour la production sur PC**. Il ne prétend pas que les assets finaux existent ou qu’ils ont déjà passé la validation matérielle.
