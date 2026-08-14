# Rapport de tests statiques — V0.11

Statut : **PASS**

- JSON analysés : 9
- Illustrations de héros : 20
- Illustrations d’ennemis : 39
- Décors : 5
- Références de scène vérifiées.
- Ordre des autoloads corrigé : DataLoader avant GameState.
- Division entière de la garde corrigée.
- Ciblage ennemi sécurisé.
- Soin sécurisé pour une compagnie réduite.

## Limite

Le binaire Godot n’a pas pu être téléchargé dans cet environnement à cause des restrictions réseau. Le test d’exécution headless reste donc à lancer avec :

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://scripts/core/smoke_test.gd
```

Aucune anomalie structurelle détectée.