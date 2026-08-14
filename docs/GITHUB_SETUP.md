# Mise en ligne sur GitHub

## Méthode simple

1. Crée un dépôt GitHub vide nommé `light-in-the-dark`.
2. Décompresse l’archive à la racine du dépôt.
3. Envoie tous les fichiers, y compris le dossier caché `.github`.
4. Ouvre l’onglet **Actions** : le workflow **CI — Validation et tests** démarre après le premier push.

## Commandes Git

```bash
git init
git add .
git commit -m "Initialise Light in the Dark Studio Foundation 0.12.0"
git branch -M main
git remote add origin ADRESSE_DU_DEPOT
git push -u origin main
```

## Produire une version

```bash
git tag v0.12.0
git push origin v0.12.0
```

Le tag déclenche les builds et crée une publication GitHub. Android est séparé dans un workflow manuel, car la configuration du SDK ou de la signature peut nécessiter des ajustements du dépôt.
