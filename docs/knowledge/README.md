# LITD Development Intelligence System

Ce dossier constitue le noyau de connaissance et de gouvernance de LITD.

## Objectif

Transformer chaque décision, recherche, incident, test et apprentissage en connaissance réutilisable et reliée.

## Boucle de travail

1. Observer le problème ou le besoin.
2. Appliquer **Qui ? Quoi ? Où ? Pourquoi ? Comment ?**
3. Charger le savoir existant et les dépendances proches.
4. Évaluer l'incertitude et le risque.
5. Rechercher si nécessaire, avec un niveau de profondeur adapté.
6. Chercher au moins une source ou hypothèse contradictoire pour les décisions importantes.
7. Formuler plusieurs hypothèses.
8. Vérifier dépendances, risques et invariants.
9. Implémenter le plus petit changement utile.
10. Tester, mesurer et observer le retour joueur.
11. Enregistrer décision, preuves, conséquences et apprentissages.
12. Revalider les connaissances devenues fragiles ou obsolètes.

## États de connaissance

- `active`: connaissance actuellement utilisée.
- `experimental`: hypothèse ou solution en cours de validation.
- `revalidate`: doit être vérifiée à nouveau.
- `superseded`: remplacée par une décision plus récente.
- `obsolete`: n'est plus applicable.
- `rejected`: évaluée puis volontairement écartée.

## Niveaux de confiance

- `low`: source unique, hypothèse ou preuve faible.
- `medium`: plusieurs indices concordants mais validation incomplète.
- `high`: sources fiables et validation LITD.
- `very_high`: sources solides + tests/mesures reproductibles dans LITD.

## Types de relations

Les entrées doivent pouvoir être reliées par :

- `depends_on`
- `influences`
- `contradicts`
- `supersedes`
- `validated_by`
- `tested_by`
- `measured_by`
- `risk_for`
- `source_for`
- `player_impact`

## Guardian

Le Guardian classe les changements :

- `green`: faible risque, validation ciblée suffisante.
- `yellow`: incertitude ou dette acceptable, surveillance requise.
- `orange`: risque significatif, preuves ou expérience supplémentaires nécessaires.
- `red`: invariant, canon ou règle critique violé ; le changement doit être bloqué.

Les règles automatisables vivent dans `guardian-rules.yml` et sont vérifiées par `tools/quality/validate_knowledge.py`.

## Recherche

Profondeur recommandée :

- `R0`: pas de recherche externe.
- `R1`: vérification officielle rapide.
- `R2`: comparaison de plusieurs sources fiables.
- `R3`: recherche approfondie docs + GitHub + publications + retours techniques.
- `R4`: état de l'art quasi systématique.

Le niveau dépend de : **impact × risque × incertitude × coût d'une erreur**.

## Trieur canonique relié au Core

Le trieur de fichiers est un capteur du système vivant, pas une autorité indépendante. Il observe l'état Git/Godot réel et remonte au Core les références, UID, doublons, familles de versions, collisions, compagnons, historique et contradictions. Le Core confronte ces observations à la Bibliothèque et au Knowledge Graph ; le Guardian autorise ou bloque ; Git exécute ; la CI apporte les preuves ; les résultats retournent ensuite dans la Bibliothèque.

Le contrat détaillé est défini dans `file-sorter-core-contract.md`.

Boucle : **Bibliothèque ⇄ Core ⇄ Trieur ⇄ Réalité Git/Godot ⇄ CI/tests/mesures ⇄ Core ⇄ Bibliothèque**.

Aucune observation du trieur n'est considérée définitivement vraie : elle doit être rattachée au head Git audité et revalidée lorsque le dépôt, le canon ou les dépendances évoluent.

## Principe d'optimisation

Minimum de complexité nécessaire, maximum de preuve utile, zéro duplication inutile.

Une connaissance nouvelle doit au moins : modifier une décision, confirmer une décision, réduire une incertitude ou créer une nouvelle question utile.
