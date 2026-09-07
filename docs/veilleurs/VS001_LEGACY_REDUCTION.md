# LITD : Les Veilleurs — réduction contrôlée du legacy VS001

## Statut

VS001 n'est plus une cible de production ni une version de référence. Il reste temporairement un **noyau de compatibilité actif** parce que le vertical slice jouable historique fournit encore une partie du runtime d'exploration, de la sauvegarde/reprise, de la persistance Rémanence et de l'interface de lancement.

Le contrat machine de cette dette est :

`data/veilleurs/legacy/vs001_dependency_contract.json`

## Pourquoi il n'est pas supprimé d'un bloc

Deux autoloads du projet utilisent encore le runtime VS001 et la sauvegarde sérialise encore son bridge. La scène jouable « Les Voix sous le Sanctuaire » référence également plusieurs scripts VS001. Une suppression directe casserait donc une fonctionnalité réellement exécutée et pourrait rendre des sauvegardes incompatibles.

La stratégie retenue est un **strangler migration** : enfermer d'abord le legacy derrière une frontière explicite, faire dépendre tout nouveau code de noms/contrats canoniques, migrer progressivement les consommateurs existants, puis supprimer les anciennes implémentations seulement lorsque leur compteur de dépendances atteint zéro.

## Frontière active

Les chemins VS001 existants restent autorisés uniquement dans les namespaces legacy déclarés par le contrat. Les consommateurs extérieurs actuels sont limités et explicitement listés, notamment le bootstrap Godot, la sauvegarde et la CI de compatibilité.

`tests/test_veilleurs_vs001_legacy_boundary.py` échoue si un nouveau fichier opérationnel commence à dépendre de VS001 en dehors de cette frontière.

## Ordre de migration

1. Introduire une façade runtime canonique Les Veilleurs.
2. Écrire les nouvelles sauvegardes sous une clé neutre `veilleurs`, tout en continuant à lire `veilleurs_vs001` pour les anciennes sauvegardes.
3. Remplacer les autoloads VS001 par des singletons canoniques.
4. Rebrancher la scène jouable, l'UI et les bridges sur les noms canoniques.
5. Remplacer les smokes VS001 par une couverture de régression canonique équivalente.
6. Supprimer les aliases et fichiers legacy seulement après validation Godot 4.7 sur PC du lancement, de l'exploration, du combat, de l'extraction et de la sauvegarde/reprise.

## Ce qui a déjà changé dans cette phase

- inventaire machine des dépendances VS001 ;
- règle de non-prolifération du legacy ;
- test automatique de frontière ;
- télémétrie CI présentée comme compatibilité du vertical slice historique au lieu d'une version de production actuelle.

## Ce qui ne doit pas être fait

- supprimer un fichier uniquement parce que son nom contient `vs001` ;
- casser la lecture des sauvegardes existantes ;
- dupliquer les systèmes globaux de blessures, Rémanence, capture ou combat pour remplacer VS001 ;
- faire migrer le gameplay vers une nouvelle règle simplement pour faciliter le renommage technique.

La réduction est terminée seulement lorsque VS001 n'est plus nécessaire au runtime, à la sauvegarde, aux scènes de production ni aux tests canoniques. Git conservera alors l'historique sans que ces fichiers restent dans la branche active.
