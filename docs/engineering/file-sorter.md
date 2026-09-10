# Trieur canonique des fichiers LITD

Le trieur `tools/maintenance/litd_file_sorter.py` inventorie les fichiers suivis par Git, détecte les signaux d'obsolescence et protège le canon avant toute suppression.

## Règle de conception

Toute évolution importante du trieur doit commencer par une recherche des pratiques et documentations pertinentes (Git, Godot, GitHub Actions, gestion de doublons et dépendances), puis traduire les résultats utiles en règles testables. Une heuristique issue de cette recherche peut proposer une enquête, mais ne peut jamais autoriser seule une suppression.

Référence de recherche : `docs/research/FILE_SORTER_RESEARCH.md`.

## États

- `canonical` : fichier explicitement canonique.
- `protected` : fichier protégé par politique ou lien symbolique ; suppression interdite.
- `active` : fichier suivi sans signal suffisant de péremption.
- `generated` : sortie générée connue ; suivie séparément du code source.
- `review` : candidat à examiner. Les heuristiques ne peuvent produire que cet état, jamais `obsolete`.
- `obsolete` : état réservé à une décision structurée dans `obsolete_records`.

## Ce que le trieur vérifie

Le rapport de sûreté contient notamment :

- SHA-256 et taille ;
- références entrantes détectées dans les fichiers texte du dépôt ;
- doublons exacts par hash ;
- motifs `legacy`, `old`, `backup`, fichiers versionnés, etc. ;
- statut, raisons et score de confiance ;
- remplacement déclaré et éléments de preuve lorsqu'une obsolescence est décidée ;
- décision `deletable` uniquement si tous les garde-fous passent.

Le rapport d'intelligence `file-intelligence-report.json` ajoute :

- collisions de casse susceptibles d'échouer sous Windows ;
- familles de versions et canon probable, uniquement à titre consultatif ;
- activité Git des variantes ;
- compagnons Godot `.uid`, `.import`, `.remap` et propriétaires orphelins ;
- références `uid://` Godot ;
- doublons exacts avec pipeline optimisé taille -> empreinte partielle -> SHA-256 complet.

## Registre d'obsolescence

Une suppression ne se décide jamais avec un simple nom de fichier. Chaque entrée doit être structurée :

```json
{
  "path": "scripts/example_v1.gd",
  "replacement": "scripts/example.gd",
  "reason": "Superseded by canonical implementation",
  "evidence": ["ADR-0123", "PR #456", "runtime smoke green"],
  "confidence": 1.0
}
```

Si aucun remplacement n'existe parce que la fonctionnalité a été volontairement retirée, utiliser `"retired_without_replacement": true` avec une preuve explicite.

Le manifeste refuse une entrée obsolète sans raison, sans preuve, avec confiance inférieure au seuil, avec remplacement absent ou contradictoire avec `canonical_paths`.

## Audit normal

```bash
python tools/maintenance/litd_file_sorter.py --fail-on-manifest-error
python tools/maintenance/litd_file_intelligence.py
python tools/maintenance/litd_safe_delete.py --plan artifacts/file-sorter-delete-plan.json
```

Le dernier appel est également non destructif : il valide le plan, les hashes, les références UID, les compagnons Godot et exécute `git rm --dry-run`.

## Suppression réelle

Le chemin recommandé n'utilise plus la suppression Python directe. Le plan doit passer par `litd_safe_delete.py`, qui conserve les contrôles natifs de Git.

Une suppression n'est possible que si toutes ces conditions sont réunies :

1. décision structurée dans `obsolete_records` ;
2. raison + preuve présentes ;
3. remplacement valide ou retrait explicite sans remplacement ;
4. confiance au moins égale à `minimum_delete_confidence` ;
5. fichier non canonique et non protégé ;
6. zéro référence entrante par chemin détectée ;
7. zéro référence Godot `uid://` entrante détectée ;
8. les compagnons `.uid/.import/.remap` sont cohérents avec leur propriétaire ;
9. arbre Git suivi propre ;
10. hash SHA-256 identique au plan fraîchement généré ;
11. chemin à l'intérieur du dépôt, fichier régulier, non symbolique ;
12. `git rm --dry-run` accepte tous les chemins ;
13. lancement manuel avec les deux verrous `--execute --allow-delete` ;
14. `git rm` est exécuté sans `--force`, afin de conserver les protections Git natives.

```bash
python tools/maintenance/litd_safe_delete.py \
  --plan artifacts/file-sorter-delete-plan.json \
  --execute --allow-delete
```

La CI est strictement en lecture/audit et n'appelle jamais `--execute` ni l'ancien `--apply`.

## Procédure LITD recommandée

1. rechercher les pratiques pertinentes si le type de fichier ou la règle est nouveau ;
2. exécuter l'audit ;
3. examiner les fichiers `review`, familles de versions et doublons ;
4. utiliser Qui / Quoi / Où / Pourquoi / Comment pour chaque candidat important ;
5. vérifier dépendances par chemin et UID, workflows, scènes, ressources, runtime et tests ;
6. vérifier l'historique Git et les changements récents ;
7. promouvoir vers `canonical_paths` les sources faisant autorité ;
8. laisser `active` les fichiers nécessaires mais non canoniques ;
9. créer une entrée `obsolete_records` uniquement avec preuve et remplacement/retrait explicite ;
10. relancer l'audit et le gate `litd_safe_delete.py` sans exécution ;
11. effectuer toute suppression dans une PR dédiée ;
12. exécuter CI, import Godot strict, tests et smokes concernés avant fusion.

Git reste le mécanisme de rollback. Le trieur privilégie volontairement les faux positifs de prudence aux faux feux verts destructifs.
