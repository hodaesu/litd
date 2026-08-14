# Guide développeur

## Contrôle local

```bash
./tools/build/run_ci.sh
```

## Ajouter une classe

1. Ajouter l’entrée dans `data/classes.json`.
2. Ajouter l’image référencée dans `assets/heroes/`.
3. Exécuter les tests.
4. Ajouter une entrée au `CHANGELOG.md`.

## Ajouter un ennemi

Même procédure avec `data/enemies.json` et `assets/enemies/`. Les identifiants doivent rester uniques.
