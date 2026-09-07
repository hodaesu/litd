# LITD : Les Veilleurs — politique de nettoyage des fichiers obsolètes

État : actif depuis le 8 septembre 2026.

## Principe

Le dépôt actif ne doit pas conserver un fichier uniquement parce qu’il documente une ancienne étape de production. Git conserve déjà l’historique. Un fichier est supprimé lorsqu’il est clairement supersédé, non référencé et qu’il ne participe plus au runtime, aux sauvegardes, aux tests, aux audits ou à une migration encore active.

Un fichier `legacy` n’est pas automatiquement obsolète. Tant qu’un composant actif en dépend, il reste dans le dépôt et sa suppression passe par une migration dédiée.

## Fichiers retirés lors du nettoyage v1

| Fichier | Motif | Source actuelle de vérité |
| --- | --- | --- |
| `00_LIRE_AVANT_IMPORT_WORKING_COPY.md` | bootstrap Working Copy iPhone terminé | dépôt GitHub actuel |
| `WORKING_COPY_IMPORT_READY.txt` | marqueur d’import Working Copy terminé | dépôt GitHub actuel |
| `docs/SPRINT_1_ACCEPTANCE.md` | critères du premier sprint supersédés | CI active et gates pré-PC |
| `docs/TEST_REPORT.md` | rapport statique V0.11 figé | GitHub Actions + audit d’intégrité |
| `docs/MIGRATION_STATUS.md` | ancien état de migration ne décrivant plus Les Veilleurs | `data/veilleurs/pre_pc_gate.json` et `docs/veilleurs/PRE_PC_LOCK.md` |
| `docs/GITHUB_SETUP.md` | procédure de création initiale du dépôt déjà accomplie | dépôt et workflows actuels |
| `docs/FILE_MANIFEST.json` | manifeste Sprint 1 figé (`0.13.0-sprint1`) devenu faux | Git + audit d’intégrité du dépôt |

## Éléments volontairement conservés

- La couche VS001 reste conservée tant que le runtime, la sauvegarde ou l’UI en dépendent. Sa consolidation est un travail de migration distinct.
- Les simulateurs QA `balance_matrix_sim`, `balance_matrix_sim_v2` et `balance_matrix_sim_v3` restent conservés : les versions récentes importent volontairement les couches précédentes.
- Les couches Veilleurs v0.6 à v0.9 restent conservées lorsqu’elles servent au runtime, aux régressions, aux contrats ou aux smokes.
- Les références aux anciens Veilleurs utilisées exclusivement comme listes interdites dans les tests de canon restent conservées.

## Règle pour les prochains nettoyages

Avant toute suppression : vérifier les imports, `res://`, autoloads, scènes, contrats, tests, workflows, sauvegardes et références documentaires. Si la dépendance est active, migrer d’abord puis supprimer. Si le fichier est purement historique et supersédé, le supprimer plutôt que créer un dossier d’archives dans le runtime actif.
