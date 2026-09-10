# Research Record — Exclusivité d'arbre / preuve technique

- ID: RR-0003
- Date: 2026-09-10
- Domaine: progression / skill trees
- Question: Le verrouillage des deux autres arbres après choix d'un arbre est-il aujourd'hui prouvé par un test actuel sur `main` ?
- Niveau: R0
- Statut: revalidate
- Confiance: medium_high

## Qui ? Quoi ? Où ? Pourquoi ? Comment ?

- Qui : système LITD Development Intelligence / équipe LITD.
- Quoi : invariant d'exclusivité des arbres de compétences.
- Où : dépôt `hodaesu/litd`, branche `main`, Guardian, données Veilleurs et tests.
- Pourquoi : la règle conditionne toute la progression et doit être distinguée d'une simple intention de design.
- Comment : contrôle du Guardian actuel et recherche d'un test ou contrat vérifiant réellement le verrouillage.

## Hypothèses de départ

L'exclusivité est une règle canonique de design, mais son application technique courante doit être démontrée indépendamment du fait que les Veilleurs possèdent bien 3 arbres × 15 compétences.

## Sources

- `docs/knowledge/guardian-rules.yml` sur `main` : règle `tree-exclusivity`, sévérité red, validation `automated_candidate`.
- `docs/knowledge/CATALOG.md` sur `main` : exige de rattacher cette règle à un test fiable avant validation technique.
- ADR-0005 : prouve la structure 3 × 15 pour les Veilleurs, mais ne constitue pas à lui seul une preuve d'exclusivité runtime.

## Résultats concordants

La règle existe comme invariant suivi, mais le niveau `automated_candidate` indique qu'aucune preuve automatisée suffisamment explicite n'est encore reliée au Guardian.

## Contradictions / limites

- Trois arbres présents dans les données ne prouvent pas que deux deviennent inaccessibles après choix.
- Une restriction UI seule ne prouve pas que la logique métier interdit les dépenses dans les autres arbres.
- Un test doit viser la couche de logique/progression, pas seulement l'affichage.

## Recherche opposée

Tentative de réfutation : rechercher une preuve actuelle permettant de déclarer l'exclusivité techniquement validée. Aucun test explicite vérifiant choix d'un arbre → refus de dépense dans les deux autres n'a été identifié pendant cette passe.

## Ce qui est vérifié dans LITD

La structure 3 arbres × 15 pour les quatre Veilleurs est documentée séparément et active. L'exclusivité reste un invariant suivi mais non promu techniquement.

## Ce qui reste inconnu

- service ou état propriétaire du choix d'arbre ;
- moment exact où le choix devient irréversible ;
- comportement des sauvegardes ;
- éventuelles règles de respec ;
- test direct de refus de dépense dans un arbre non choisi.

## Conditions de promotion

Promouvoir en `active` / techniquement validé lorsqu'un test automatisé prouve au minimum : choix de l'arbre A → dépenses possibles dans A → dépenses refusées dans B et C → état préservé après save/load si la progression est persistée.

## Décisions influencées

Conserver `tree-exclusivity` en `automated_candidate` tant que ce contrat n'est pas couvert.

## Date ou condition de revalidation

Revalider dès qu'un test de progression/exclusivité est fusionné sur `main`.

## Relations Knowledge Graph

- source_for: tree-exclusivity-validation
- contradicts: tree-exclusivity-assumed-implemented
- validated_by: future-tree-exclusivity-test
- influences: guardian-tree-exclusivity
