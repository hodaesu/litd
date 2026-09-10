# Trieur canonique des fichiers LITD

Le trieur `tools/maintenance/litd_file_sorter.py` sert à inventorier les fichiers suivis par Git et à les classer sans supprimer à l’aveugle.

## États

- `canonical` : chemin explicitement canonique dans le manifeste.
- `protected` : fichier protégé par règle ; il ne peut pas être supprimé.
- `active` : fichier suivi sans signal de péremption.
- `review` : candidat à révision détecté par motif de nommage (`legacy`, `old`, suffixes versionnés, backups, etc.). Un fichier `review` n’est jamais supprimé automatiquement.
- `obsolete` : chemin explicitement déclaré dans `obsolete_paths`.

Le manifeste de décision est `data/maintenance/canonical_files.json`.

## Audit normal

```bash
python tools/maintenance/litd_file_sorter.py
```

Le rapport JSON est écrit dans `artifacts/file-sorter-report.json` et indique notamment les références entrantes détectées.

## Suppression

Une suppression n’est possible que si toutes les conditions suivantes sont réunies :

1. le chemin exact est présent dans `obsolete_paths` ;
2. il n’est pas protégé ;
3. il n’est pas canonique ;
4. aucune référence entrante n’est détectée dans les fichiers texte du dépôt ;
5. la commande est lancée manuellement avec les deux verrous :

```bash
python tools/maintenance/litd_file_sorter.py --apply --allow-delete
```

La CI n’utilise jamais ces options et ne peut donc pas supprimer de fichiers.

## Procédure recommandée

1. lancer l’audit ;
2. examiner les fichiers classés `review` ;
3. vérifier leur rôle, leurs références, leurs workflows et leurs dépendances ;
4. promouvoir les fichiers utiles vers `canonical_paths` ou les laisser `active` ;
5. ajouter uniquement les chemins réellement obsolètes à `obsolete_paths` ;
6. relancer l’audit ;
7. n’exécuter la suppression que lorsque le rapport confirme `deletable: true`.

Cette procédure suit le principe LITD : changement minimal, preuve avant suppression et possibilité d’inspection avant intégration.
