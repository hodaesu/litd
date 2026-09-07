# LITD : Les Veilleurs — réduction contrôlée du legacy VS001

## Statut

VS001 n'est plus une cible de production ni une version de référence. Il reste temporairement un **noyau de compatibilité actif** parce que le vertical slice jouable historique fournit encore une partie du runtime d'exploration, de la persistance Rémanence et de l'interface de lancement.

La sauvegarde n'est plus un consommateur direct de ses singletons : elle passe désormais par `VeilleursRuntimeFacade` et écrit la clé canonique `veilleurs`. La clé historique `veilleurs_vs001` subsiste uniquement comme entrée de migration pour les anciennes sauvegardes.

Le contrat machine de cette dette est :

`data/veilleurs/legacy/vs001_dependency_contract.json`

## Pourquoi il n'est pas supprimé d'un bloc

Deux autoloads du projet utilisent encore le runtime VS001 et la scène jouable « Les Voix sous le Sanctuaire » référence plusieurs scripts VS001. Les anciennes sauvegardes peuvent également contenir la clé historique `veilleurs_vs001` et doivent continuer à être migrées. Une suppression directe casserait donc une fonctionnalité réellement exécutée et pourrait rendre des sauvegardes incompatibles.

La stratégie retenue est un **strangler migration** : enfermer d'abord le legacy derrière une frontière explicite, faire dépendre tout nouveau code de noms/contrats canoniques, migrer progressivement les consommateurs existants, puis supprimer les anciennes implémentations seulement lorsque leur compteur de dépendances atteint zéro.

## Frontière active

Les chemins VS001 existants restent autorisés uniquement dans les namespaces legacy déclarés par le contrat. `scripts/core/veilleurs_runtime_facade.gd` est l'unique pont canonique autorisé vers les anciens singletons ; `SaveManager` n'est autorisé à contenir VS001 que pour la lecture/migration de l'ancienne clé de sauvegarde.

`tests/test_veilleurs_vs001_legacy_boundary.py` échoue si un nouveau fichier opérationnel commence à dépendre de VS001 en dehors de cette frontière. `tests/test_veilleurs_save_key_migration.py` verrouille la nouvelle clé de sauvegarde et la rétrocompatibilité.

## Ordre de migration

1. **Terminé** — introduire une façade runtime canonique Les Veilleurs.
2. **Terminé** — écrire les nouvelles sauvegardes sous une clé neutre `veilleurs`, tout en continuant à lire `veilleurs_vs001` pour les anciennes sauvegardes.
3. **À faire** — remplacer les autoloads VS001 par des singletons canoniques.
4. **À faire** — rebrancher la scène jouable, l'UI et les bridges sur les noms canoniques.
5. **À faire** — remplacer les smokes VS001 par une couverture de régression canonique équivalente.
6. **Après validation PC** — supprimer les aliases et fichiers legacy seulement après validation Godot 4.7 du lancement, de l'exploration, du combat, de l'extraction et de la sauvegarde/reprise.

## Ce qui a déjà changé

- inventaire machine des dépendances VS001 ;
- règle de non-prolifération du legacy ;
- test automatique de frontière ;
- télémétrie CI présentée comme compatibilité du vertical slice historique au lieu d'une version de production actuelle ;
- façade canonique `VeilleursRuntimeFacade` ;
- `SaveManager` découplé des singletons VS001 ;
- nouvelles sauvegardes sous `veilleurs` ;
- migration automatique de `veilleurs_vs001` vers `veilleurs` au chargement, sans augmenter `SAVE_VERSION` afin de conserver la compatibilité 0.31.

## Ce qui ne doit pas être fait

- supprimer un fichier uniquement parce que son nom contient `vs001` ;
- casser la lecture des sauvegardes existantes ;
- dupliquer les systèmes globaux de blessures, Rémanence, capture ou combat pour remplacer VS001 ;
- faire migrer le gameplay vers une nouvelle règle simplement pour faciliter le renommage technique.

La réduction est terminée seulement lorsque VS001 n'est plus nécessaire au runtime, aux scènes de production ni aux tests canoniques, et que les anciennes sauvegardes ont un chemin de migration vérifié. Git conservera alors l'historique sans que ces fichiers restent dans la branche active.
