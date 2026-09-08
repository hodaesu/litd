# Contribution

## Avant une modification

1. Crée une branche dédiée depuis la branche par défaut `main`.
2. Ne mélange pas plusieurs fonctionnalités sans rapport.
3. Mets les données de contenu dans `data/` plutôt que dans l’interface lorsque le contenu doit être data-driven.
4. Définis le résultat attendu, les critères d'acceptation et la méthode de test avant une modification importante.
5. Pour Les Veilleurs, applique le [Production Playbook](docs/veilleurs/PRODUCTION_PLAYBOOK.md) : une fonctionnalité majeure doit disposer de preuves de design, joueur, technique et production avant d'être considérée comme verrouillée.

## Vérification locale

```bash
python3 tools/qa/validate_project.py
python3 -m unittest discover -s tests/python -p 'test_*.py' -v
tools/build/run_ci.sh
```

Les contrôles Veilleurs complémentaires sont documentés dans :

- `docs/veilleurs/PRE_PC_LOCK.md` ;
- `docs/veilleurs/GODOT_PRODUCTION_AUTOMATION.md` ;
- `docs/veilleurs/PLAYTEST_PROTOCOL.md`.

Une pull request ne doit pas être fusionnée tant que la CI est rouge. Une CI verte ne remplace pas les validations visuelles, tactiles, audio ou de performance qui exigent un appareil réel.
