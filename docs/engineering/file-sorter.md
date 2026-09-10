# Trieur canonique des fichiers LITD

Le trieur `tools/maintenance/litd_file_sorter.py` inventorie les fichiers suivis par Git, détecte les signaux d'obsolescence et protège le canon avant toute suppression.

## États

- `canonical` : fichier explicitement canonique.
- `protected` : fichier protégé par politique ou lien symbolique ; suppression interdite.
- `active` : fichier suivi sans signal suffisant de péremption.
- `generated` : sortie générée connue ; suivie séparément du code source.
- `review` : candidat à examiner. Les heuristiques ne peuvent produire que cet état, jamais `obsolete`.
- `obsolete` : état réservé à une décision structurée dans `obsolete_records`.

## Ce que le trieur vérifie

Le rapport contient pour chaque fichier :

- SHA-256 et taille ;
- références entrantes détectées dans les fichiers texte du dépôt ;
- doublons exacts par hash ;
- motifs `legacy`, `old`, `backup`, fichiers versionnés, etc. ;
- statut, raisons et score de confiance ;
- remplacement déclaré et éléments de preuve lorsqu'une obsolescence est décidée ;
- décision `deletable` uniquement si tous les garde-fous passent.

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
```

Deux fichiers sont produits :

- `artifacts/file-sorter-report.json` : inventaire complet ;
- `artifacts/file-sorter-delete-plan.json` : plan de suppression vide ou limité aux fichiers ayant franchi tous les garde-fous.

## Suppression

Une suppression n'est possible que si toutes ces conditions sont réunies :

1. décision structurée dans `obsolete_records` ;
2. raison + preuve présentes ;
3. remplacement valide ou retrait explicite sans remplacement ;
4. confiance au moins égale à `minimum_delete_confidence` ;
5. fichier non canonique et non protégé ;
6. zéro référence entrante détectée ;
7. arbre de travail Git suivi propre avant suppression ;
8. hash SHA-256 du fichier identique au hash du plan fraîchement généré ;
9. chemin résolu à l'intérieur du dépôt et non symbolique ;
10. lancement manuel avec les deux verrous `--apply --allow-delete`.

```bash
python tools/maintenance/litd_file_sorter.py --apply --allow-delete
```

La CI est strictement en lecture/audit et ne lance jamais la suppression.

## Procédure LITD recommandée

1. exécuter l'audit ;
2. examiner les fichiers `review` et les groupes de doublons ;
3. utiliser Qui / Quoi / Où / Pourquoi / Comment pour chaque candidat important ;
4. vérifier dépendances, workflows, scènes, ressources, runtime et tests ;
5. promouvoir vers `canonical_paths` les sources faisant autorité ;
6. laisser `active` les fichiers nécessaires mais non canoniques ;
7. créer une entrée `obsolete_records` uniquement avec preuve et remplacement/retrait explicite ;
8. relancer l'audit et les tests ;
9. effectuer toute suppression dans une PR dédiée ;
10. exécuter CI, tests Godot et smoke concernés avant fusion.

Git reste le mécanisme de rollback. Le trieur privilégie volontairement les faux positifs de prudence aux faux feux verts destructifs.
