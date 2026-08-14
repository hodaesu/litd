# Contribution

## Avant une modification

1. Crée une branche depuis `develop`.
2. Ne mélange pas plusieurs fonctionnalités sans rapport.
3. Mets les données de contenu dans `data/` plutôt que dans l’interface.

## Vérification locale

```bash
python3 tools/qa/validate_project.py
python3 -m unittest discover -s tests/python -p 'test_*.py' -v
tools/build/run_ci.sh
```

Une pull request ne doit pas être fusionnée tant que la CI est rouge.
