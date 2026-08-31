# Continuité du lore — LITD Universe

Ce dossier est la source de vérité partagée par tous les jeux de l'univers.

- `canon_registry.json` contient les faits protégés, les mystères ouverts et les ancres temporelles.
- `projects.json` enregistre chaque jeu consommateur ou contributeur.
- `contributions/` déclare ce que chaque jeu affirme, révèle ou ajoute.

Un jeu ne modifie jamais silencieusement un fait commun. Toute contribution doit porter un identifiant stable, viser la même version du canon et citer ses sources. L'audit refuse les contradictions, les références inconnues, les doublons et les chronologies cycliques.

## Ajouter un jeu ou du lore

1. Enregistrer le jeu dans `projects.json`.
2. Ajouter son manifeste dans `contributions/<projet>_<sujet>.json`.
3. Pour un fait existant, ajouter une `claim` avec `affirm`, `theory` ou `partial_evidence`.
4. Pour un nouveau fait partagé, l'ajouter d'abord au registre central après validation narrative.
5. Citer tous les documents ou fichiers de données qui matérialisent cet ajout.
6. Exécuter `python -m tools.qa.lore_universe_audit`.

Les faits `fixed` ne peuvent être qu'affirmés avec leur valeur canonique. Les faits `open` autorisent les théories ou indices partiels déclarés, sans transformer un mystère en vérité définitive.

Un projet au statut `active` doit avoir au moins un manifeste. Un projet `planned` peut rester vide jusqu'au début de sa production, mais devra adopter ce contrat avant son premier ajout narratif.
