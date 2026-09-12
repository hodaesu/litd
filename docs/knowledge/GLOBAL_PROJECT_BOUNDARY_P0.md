# GLOBAL PROJECT BOUNDARY P0

Ce contrat formalise l'isolation inter-projets pour la gouvernance globale.

## Invariant

Tout artefact de gouvernance doit être lié explicitement à une identité de projet et à une route cible. Un artefact LITD ne doit jamais être accepté par un chemin entreprise, ni l'inverse.

## LITD

- `project_id = LITD`
- `target_route = LITD_LIBRARY`

Ces valeurs doivent être incluses dans les hashes canoniques, propagées dans les reçus et conservées dans le ledger de preuve.

## Règle fail-closed

Tout événement, reçu ou preuve dont le `project_id` ou la route ne correspondent pas au consommateur local est refusé avant routage, promotion, décision Guardian, implémentation ou application.

## Portée

Ce fichier ne prétend pas suffire à l'isolation complète. Il fixe le contrat P0 à propager de l'ingress jusqu'au checkpoint final et au futur registre Supabase multi-projets.
