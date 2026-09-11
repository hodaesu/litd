# Recherche — Trieur canonique de fichiers LITD

Date : 2026-09-10

## Objectif

Documenter les pratiques externes utilisées pour concevoir et faire évoluer le trieur LITD. Cette recherche est une source d'exigences, jamais une autorisation automatique de suppression.

## Sources officielles consultées

### Git — `git rm`

Source : https://git-scm.com/docs/git-rm

Enseignements retenus :

- `git rm` ne supprime que des chemins connus de Git ;
- `git rm --dry-run` permet de simuler la suppression ;
- sans `--force`, Git conserve ses contrôles de cohérence avec l'index/tip ;
- `--` doit séparer les options des chemins.

Décision LITD : le chemin de suppression recommandé passe par `litd_safe_delete.py`, qui exécute d'abord `git rm --dry-run`, puis `git rm -- ...` sans `--force` après validation explicite.

### Godot — ResourceUID et `uid://`

Sources :

- https://docs.godotengine.org/fr/4.x/classes/class_resourceuid.html
- https://docs.godotengine.org/fr/4.x/engine_details/file_formats/tscn.html

Enseignements retenus :

- Godot 4 utilise des UID persistants `uid://` pour garder les références intactes lors des déplacements/renommages ;
- une recherche basée uniquement sur `res://` ou le nom de fichier est insuffisante ;
- les scènes et ressources peuvent exposer leur UID dans leurs données sérialisées.

Décision LITD : l'intelligence du dépôt et le gate final analysent aussi les UID. Une référence UID entrante bloque la suppression.

### GitHub Actions — moindre privilège

Sources :

- https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
- https://docs.github.com/en/actions/reference/security/secure-use

Enseignements retenus :

- accorder uniquement les permissions nécessaires au `GITHUB_TOKEN` ;
- préférer l'accès en lecture seule au contenu quand aucune écriture n'est requise.

Décision LITD : `file-sorter-audit.yml` conserve `contents: read` et ne contient aucun chemin d'exécution destructive.

## Principes techniques retenus

### Doublons

Pipeline retenu :

1. grouper par taille ;
2. calculer une empreinte partielle pour les groupes de même taille ;
3. calculer le SHA-256 complet uniquement pour les candidats restants ;
4. considérer deux fichiers identiques uniquement après égalité du hash complet.

Cette optimisation réduit les lectures inutiles sans réduire la certitude finale.

### Godot companions

Les fichiers `.uid`, `.import` et `.remap` sont traités comme compagnons structurels. Ils ne sont pas supprimés isolément de leur propriétaire lorsque celui-ci reste suivi, et un propriétaire ne peut pas être supprimé silencieusement en laissant un compagnon suivi incohérent.

### Historique Git

L'ancienneté et le nombre de commits d'un fichier servent uniquement de signaux d'enquête. Un fichier ancien peut rester canonique ; un fichier récent peut déjà être obsolète. Aucun signal Git temporel n'autorise seul une suppression.

## Règle permanente du trieur

Avant d'ajouter une nouvelle règle de suppression ou de classement significative :

1. définir Qui / Quoi / Où / Pourquoi / Comment ;
2. rechercher la documentation officielle et les pratiques existantes pertinentes ;
3. enregistrer les enseignements dans ce document ou une recherche liée ;
4. transformer chaque enseignement retenu en garde-fou ou test vérifiable ;
5. chercher un contre-exemple et le couvrir par un test ;
6. garder toute heuristique non prouvée en mode `review` uniquement ;
7. ne jamais laisser une heuristique seule produire une suppression.

## Architecture de confiance

Ordre de confiance croissant :

`heuristique -> review -> analyse structurelle -> preuve d'obsolescence -> manifeste -> plan hashé -> gate UID/compagnons -> git rm --dry-run -> git rm sans --force -> CI/tests -> revue PR`

Aucune étape amont ne peut court-circuiter une étape aval.
