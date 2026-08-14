# Import dans Working Copy sur iPhone

Cette archive contient les fichiers du projet, mais volontairement **pas de dossier `.git`**. Working Copy doit créer ce dossier lui-même.

## Procédure correcte

1. Dans Working Copy, revenez à la liste des dépôts.
2. Touchez **+** puis **Create Repository** / **New Repository**.
3. Nommez-le `Light-in-the-Dark`.
4. Ouvrez ce nouveau dépôt.
5. Touchez **+** ou le menu **…**, puis **Import Files**.
6. Dans l’app Fichiers, décompressez cette archive.
7. Ouvrez le dossier décompressé et sélectionnez **tout son contenu** (`.github`, `assets`, `data`, `docs`, etc.), pas le dossier parent.
8. Importez les fichiers dans le dépôt créé par Working Copy.
9. Dans Working Copy, ouvrez **Changes**, ajoutez un message comme `Import Sprint 1`, puis faites **Commit**.
10. Ajoutez ensuite le dépôt GitHub comme remote et faites **Push**.

## Important

- Ne choisissez pas directement le dossier décompressé comme dépôt : il n’a pas de `.git`.
- Ne supprimez pas le dossier caché `.github` : il contient les automatisations GitHub Actions.
- Le fichier `project.godot` doit se trouver directement à la racine du dépôt.
