# Sonothèque source LITD

## Objectif

Construire une bibliothèque de **1 000 à 3 000 sons sources**, avec une cible initiale de **1 800**, utilisée comme matière première pour le sound design. Un son source n'est pas un bruitage final : il peut être nettoyé, découpé, pitché, étiré, superposé et réverbéré avant de devenir un asset du jeu.

## Ce qui va dans GitHub

Le dépôt conserve :

- les contrats de catégories et quotas ;
- la provenance et la licence de chaque source ;
- les hashes SHA-256 ;
- les recettes de transformation ;
- la lignée source → dérivé → cue final ;
- les tests d'audit.

Les fichiers bruts, bibliothèques privées, reçus et copies de licences restent dans `local/audio_library/`, qui est ignoré par Git.

## Structure locale

```text
local/audio_library/
  01_SOURCE/      # originaux immuables
  02_WORKING/     # copies de travail
  03_RENDERED/    # rendus LITD en revue
  04_LICENSES/    # preuves de licence / reçus / captures
```

Les fichiers finals audités peuvent ensuite être exportés vers `assets/audio/sfx/`.

## Politique de licence

Accepté comme base :

- `OWN_RECORDING`
- `CC0`
- `CC-BY` avec attribution conservée
- `ROYALTY_FREE_NO_REDISTRIBUTION` uniquement dans la bibliothèque privée locale

Bloqué :

- non-commercial ;
- `CC-BY-NC` ;
- editorial-only ;
- licence inconnue ou non vérifiée.

Une source externe doit avoir une URL, un auteur, une preuve de licence, l'autorisation commerciale et le droit de créer des dérivés.

## Initialiser la bibliothèque

```bash
python tools/audio/source_sfx_library.py init
```

## Ajouter un enregistrement personnel

```bash
python tools/audio/source_sfx_library.py ingest mon_son.wav \
  --category impacts \
  --license OWN_RECORDING \
  --tags metal,heavy,door
```

L'outil :

1. calcule le SHA-256 ;
2. refuse un doublon ;
3. copie l'original dans `01_SOURCE` ;
4. crée son identifiant stable ;
5. ajoute sa fiche dans `data/audio/source_sfx_registry.json`.

## Ajouter une source externe

```bash
python tools/audio/source_sfx_library.py ingest source.ogg \
  --category footsteps \
  --license CC0 \
  --provider "Provider" \
  --author "Auteur" \
  --source-url "https://..." \
  --license-evidence local/licence.txt \
  --tags stone,footstep
```

L'import échoue si la licence est bloquée ou si les métadonnées légales nécessaires manquent.

## Voir ce qui manque

```bash
python tools/audio/source_sfx_library.py plan
```

La commande affiche les déficits pour atteindre les 1 800 sources prévues.

## Audit

```bash
python tools/audio/source_sfx_library.py audit
```

L'audit vérifie les catégories, licences, doublons de hash, provenance, droits commerciaux et droits de transformation.

## Crédits CC-BY

```bash
python tools/audio/source_sfx_library.py credits
```

Les attributions sont générées automatiquement depuis le registre au lieu d'être maintenues à la main.

## Transformer un son

Chaque dérivé doit garder ses sources et sa recette. Exemple :

```bash
python tools/audio/source_sfx_library.py derivative \
  --id SFX_SWORD_HEAVY_01 \
  --source-ids SRC_IMPACTS_000120,SRC_WEAPONS_000031 \
  --cue-id sword_heavy_hit \
  --variant 1 \
  --recipe '[{"op":"pitch","semitones":-4},{"op":"layer"},{"op":"compress"},{"op":"reverb","preset":"crypt_short"}]'
```

Les recettes de départ sont dans `data/audio/sfx_design_recipes.json`.

## Règle de production

- Original source : jamais modifié.
- Working copy : transformations libres selon la licence.
- Rendered : candidat au jeu, encore en revue.
- Game ready : uniquement après audit légal et sonore.
- Bruitages répétitifs : minimum 4 variantes.
- Pas principaux : cible de 8 à 10 variantes par matériau.
