# Architecture du projet

- `scenes/` : scènes Godot et composition visuelle.
- `scripts/core/` : état global, données et sauvegardes.
- `scripts/ui/` : interfaces et boucle verticale jouable.
- `data/` : contenu JSON, séparé du moteur.
- `assets/` : illustrations importées.
- `tests/python/` : contrats de données et validations statiques.
- `tools/qa/` : audit du dépôt et rapports.
- `.github/workflows/` : CI, builds, nightly et release.

La règle principale est de garder les données de gameplay hors du code dès que possible.
