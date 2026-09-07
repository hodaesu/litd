# LITD : Les Veilleurs — automatisation d’intake de contenu

## But

Tout nouveau contenu commence par un **work-order réservé**, pas par une modification improvisée d’un fichier canonique. L’intake donne immédiatement un ID, les cibles d’intégration, les assets, les tests et les gates attendus.

La réservation n’est jamais une autorité de gameplay. Elle prépare le travail ; les données/runtime canoniques restent soumises à revue, tests Godot et CI.

## Types supportés

- `watcher` → `ENT_WATCHER_*`
- `enemy` → `ENT_ENEMY_*`
- `boss` → `ENT_BOSS_*`
- `dungeon` → `DUNGEON_*`
- `ui_screen` → `UI_*`
- `ultimate` → `ULT_*`
- `generic` → `CONTENT_*` ; proposition temporaire qui doit être reclassée avant canonicalisation.

Les préfixes à forte autorité reprennent les conventions déjà utilisées par Les Veilleurs. Les compétences individuelles ne sont volontairement pas inventées par ce générateur : leurs IDs suivent aujourd’hui la convention propre à chaque Veilleur/arbre (par exemple `NA-BAS-01`) et doivent rester sous le contrat de compétences existant.

## Preview

Sous Windows :

```bat
tools\workstation\LITD_VEILLEURS_CONTENT_INTAKE.cmd enemy "Goule des Braises"
```

Ou directement :

```bash
python tools/godot/veilleurs_content_intake.py enemy "Goule des Braises"
```

Le preview ne crée aucun fichier.

## Réserver

```bat
tools\workstation\LITD_VEILLEURS_CONTENT_INTAKE.cmd enemy "Goule des Braises" --reserve
```

Le work-order est créé sous :

`data/veilleurs/intake/work_orders/<canonical_id>.json`

Sa présence réserve l’ID. Une seconde réservation identique est refusée.

## ID explicite

```bash
python tools/godot/veilleurs_content_intake.py boss "Le Roi des Cendres" --id ENT_BOSS_ROI_CENDRES --reserve
```

L’ID doit respecter le préfixe du type et le format canonique. Un ID déjà présent dans le corpus ou déjà réservé est refusé.

## Ce que contient un work-order

Chaque work-order contient :

- type et ID canonique réservé ;
- nom français et slug déterministe ;
- sources canoniques à intégrer ;
- cibles data/runtime/scène/UI/save selon le type ;
- racine d’assets de production ;
- slots d’assets obligatoires ;
- tests attendus ;
- gates CI et hardware ;
- contraintes mobile-first et séparation gameplay/présentation ;
- état initial `intake_reserved`.

## Chaîne de production

1. **Intake / réservation** — l’ID et le périmètre sont verrouillés.
2. **Implémentation canonique** — données, runtime, scène et UI nécessaires.
3. **Tests** — audit Python + smoke Godot correspondant.
4. **Production d’assets** — selon les slots du work-order et le handoff final.
5. **PR** — pipeline Veilleurs en mode changed.
6. **CI** — import strict, smokes, Android debug si le changement touche la production.
7. **Fusion** — seulement après gates verts.
8. **Closeout matériel** — tactile, safe areas, haptique, performances, lisibilité, audio et builds signés sur appareils réels.

## Garde-fous

L’intake :

- ne modifie jamais automatiquement `watchers.json`, les ennemis, boss, donjons ou ultimes canoniques ;
- refuse les collisions avec les IDs déjà présents dans les données, scripts ou scènes ;
- refuse les doubles réservations ;
- interdit les IDs/path contenant une traversée de répertoire ;
- ne permet pas de canonicaliser directement un type `generic` ;
- ne change jamais une règle de gameplay pour faciliter la production artistique.

L’audit `tools/qa/veilleurs_content_intake_audit.py` teste ces garde-fous à chaque passage du pipeline.
