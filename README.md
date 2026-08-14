# Light in the Dark — Studio Sprint 1

Fondation professionnelle du prototype Godot de **Light in the Dark**.

## Vérifier le projet

```bash
python -m pip install .
python -m pytest
python -m tools.qa.audit
```

Ou sous macOS/Linux :

```bash
./tools/build/run_ci.sh
```

Le rapport est écrit dans `reports/qa-report.html`.

## GitHub Actions

- **CI** : tests Python, audit et smoke test Godot.
- **Builds** : exports Web, Windows et Linux.
- **Nightly QA** : régression quotidienne.
- **Release** : création d’une release lors d’un tag `v*`.

## Premier envoi sur GitHub

Décompressez l’archive, envoyez tout son contenu à la racine d’un dépôt vide, y compris le dossier `.github`. Consultez `docs/GITHUB_SETUP.md`.

## Limites du Sprint 1

La CI est prête, mais sa première exécution réelle dépend de l’envoi sur GitHub. Les exports Android/iOS nécessitent des SDK et signatures et sont prévus dans un sprint ultérieur.
