# Continuité du lore — LITD Universe

Ce dossier est la source de vérité partagée par tous les jeux de l'univers.

- `canon_registry.json` contient les faits protégés, les mystères ouverts et les ancres temporelles.
- `timeline_master.json` matérialise la chronologie maîtresse, les niveaux de certitude, les liens de Rémanence et les fenêtres temporelles des personnages.
- `projects.json` enregistre chaque jeu consommateur ou contributeur.
- `contributions/` déclare ce que chaque jeu affirme, révèle ou ajoute.

Un jeu ne modifie jamais silencieusement un fait commun. Toute contribution doit porter un identifiant stable, viser la même version du canon et citer ses sources. L'audit refuse les contradictions, les références inconnues, les doublons et les chronologies impossibles.

## Chronologie maîtresse

La Chute est l'**an 0**. Une date n'est pas inventée lorsqu'elle n'est pas établie : `timeline_master.json` accepte explicitement les positions relatives et les inconnues.

Chaque événement maître déclare au minimum :

- `id`, `label`, `era` et `timeline_anchor` ;
- `relative_year` (nombre ou `null`) et `relative_label` ;
- `certainty` : `locked`, `approximate`, `relative_only` ou `unknown` ;
- `sources`, `game`, `characters` et `remanence_links` ;
- `canon_status` : `canon`, `working_canon`, `branched` ou `deprecated`.

Les fenêtres `earliest_anchor` des personnages servent de garde-fou contre les apparitions trop anciennes. Ainsi, un personnage de la fin de la Concorde ne peut pas être placé dans Les Veilleurs, situé aux premiers temps de la Concorde, sans que l'audit le signale comme contradiction. Les bornes tardives restent pour l'instant des avertissements tant que les décès et durées d'activité ne sont pas tous verrouillés.

## Ajouter un jeu ou du lore

1. Vérifier d'abord les bibliothèques, documents et données canoniques existants.
2. Faire passer l'idée par les piliers LITD Universe qui lui correspondent.
3. Enregistrer le jeu dans `projects.json` si nécessaire.
4. Ajouter son manifeste dans `contributions/<projet>_<sujet>.json`.
5. Pour un fait existant, ajouter une `claim` avec `affirm`, `theory` ou `partial_evidence`.
6. Pour un nouveau fait partagé, l'ajouter d'abord au registre central après validation narrative.
7. Si l'ajout possède une implication temporelle, l'inscrire dans `timeline_master.json` avec son niveau de certitude réel.
8. Citer tous les documents ou fichiers de données qui matérialisent cet ajout.
9. Exécuter `python tools/qa/lore_universe_audit.py` puis `pytest -q tests/python`.

Les faits `fixed` ne peuvent être qu'affirmés avec leur valeur canonique. Les faits `open` autorisent les théories ou indices partiels déclarés, sans transformer un mystère en vérité définitive.

Un projet au statut `active` doit avoir au moins un manifeste. Un projet `planned` peut préparer son manifeste avant la production ; dès qu'il contribue au canon partagé, il doit respecter le même contrat.

Le document humain de référence pour la chronologie est `docs/LITD_UNIVERSE_CHRONOLOGIE_MAITRESSE.md`. Le fichier JSON est sa représentation contrôlable automatiquement.