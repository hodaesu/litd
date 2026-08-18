# Light in the Dark — Studio Sprint 1

Fondation professionnelle du prototype Godot de **Light in the Dark**.

## Documentation

- [Bible du lore — Trois Éveils](docs/LORE_BIBLE.md)
- [Monde extérieur, Voile et Chute](docs/LORE_MONDE_VOILE_ET_CHUTE.md)
- [Civilisations étrangères — peuples, puissances et après-Chute](docs/CIVILISATIONS_ETRANGERES_APRES_CHUTE.md)
- [Histoire fondatrice — Dernière Guerre et Trois Éveils](docs/HISTOIRE_TROIS_EVEILS.md)
- [La Concorde — droit et justice](docs/CONCORDE_DROIT_JUSTICE.md)
- [La Concorde avant la Chute — courants politiques](docs/CONCORDE_COURANTS_PRE_CHUTE.md)
- [La Concorde — cités, institutions, histoire et quêtes politiques](docs/CONCORDE_MONDE_POLITIQUE.md)
- [La Concorde après la Chute — courants et figures politiques](docs/CONCORDE_COURANTS_POST_CHUTE.md)

## Vérifier le projet

```bash
python -m pip install -r requirements-dev.txt
python -m pytest
python -m tools.qa.audit
```

Ou sous macOS/Linux :

```bash
bash ./tools/build/run_ci.sh
```

Le script exécute également le smoke test Godot si `godot` est disponible localement. Le rapport est écrit dans `reports/qa-report.html`.

## GitHub Actions

- **CI** : tests Python, audit et smoke test Godot.
- **Builds** : exports Web, Windows et Linux.
- **Nightly QA** : régression quotidienne.
- **Release** : création d’une release lors d’un tag `v*`.

## Premier envoi sur GitHub

Décompressez l’archive, envoyez tout son contenu à la racine d’un dépôt vide, y compris le dossier `.github`. Consultez `docs/GITHUB_SETUP.md`.

## Limites du Sprint 1

La CI est prête, mais sa première exécution réelle dépend de l’envoi sur GitHub. Les exports Android/iOS nécessitent des SDK et signatures et sont prévus dans un sprint ultérieur.
