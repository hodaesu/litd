# Light in the Dark — Studio Sprint 1

Fondation professionnelle du prototype Godot de **Light in the Dark**.

## Documentation

- [Bible du lore — Trois Éveils](docs/LORE_BIBLE.md)
- [Monde extérieur, Voile et Chute](docs/LORE_MONDE_VOILE_ET_CHUTE.md)
- [Civilisations étrangères — peuples, puissances et après-Chute](docs/CIVILISATIONS_ETRANGERES_APRES_CHUTE.md)
- [Civilisations antérieures et Premier Voile](docs/CIVILISATIONS_ANTERIEURES_ET_PREMIER_VOILE.md)
- [Civilisations antérieures des mondes extérieurs](docs/CIVILISATIONS_ANTERIEURES_MONDES_EXTERIEURS.md)
- [Campagne principale — 10 chapitres, boss, révélations et fins](docs/CAMPAGNE_PRINCIPALE.md)
- [Chapitre I — verticale jouable des Terres de Cendre](docs/CHAPITRE_01_VERTICAL_SLICE.md)
- [Chapitre II — enquête jouable et Route des Bornes](docs/CHAPITRE_02_VERTICAL_SLICE.md)
- [Chapitre III — Projet Seuil, responsabilités et Écho](docs/CHAPITRE_03_PROJET_SEUIL.md)
- [Chapitre IV — Première Rupture et Ashaï de Nhal](docs/CHAPITRE_04_PREMIERE_RUPTURE.md)
- [Chapitre V — Or-Silex et la Grande Fermeture](docs/CHAPITRE_05_GRANDE_FERMETURE.md)
- [Chapitre VI — Les Absents](docs/CHAPITRE_06_LES_ABSENTS.md)
- [Chapitre VII — Les responsables vivants](docs/CHAPITRE_07_RESPONSABLES_VIVANTS.md)
- [Chapitre VIII — Le monde extérieur](docs/CHAPITRE_08_MONDE_EXTERIEUR.md)
- [Chapitre IX — Ce qu'est réellement le Voile](docs/CHAPITRE_09_NATURE_DU_VOILE.md)
- [Chapitre X — La lumière mérite d'être défendue](docs/CHAPITRE_10_LA_LUMIERE_MERITE_ETRE_DEFENDUE.md)
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