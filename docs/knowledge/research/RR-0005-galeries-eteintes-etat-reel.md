# Research Record — Galeries Éteintes / état réel

- ID: RR-0005
- Date: 2026-09-10
- Domaine: vertical-slice / world / persistence
- Question: Galeries Éteintes peut-elle être considérée comme une implémentation canonique actuelle ?
- Niveau: R0
- Statut: revalidate
- Confiance: high

## Qui ? Quoi ? Où ? Pourquoi ? Comment ?

- Qui : LITD Development Intelligence / équipe LITD.
- Quoi : prototype runtime `VS01_GALERIES_ETEINTES`.
- Où : PR #245, branche `feature/galeries-eteintes-vs01`.
- Pourquoi : distinguer une implémentation riche mais encore ouverte d'une référence fusionnée et canonique.
- Comment : contrôle de l'état de la PR, de ses données et recherche de contradictions avec le canon actuel.

## Sources

- PR #245 : ouverte, non fusionnée ; annonce graphe de salles data-driven, Lumière, fuite, persistance candidate, refuge, extraction, sérialisation et smokes.
- `data/dungeons/galeries_eteintes_map.json` sur la branche #245 : graphe GE01 avec entrée, combats, refuge, extraction et chambre secrète.
- Diff de #245 : contient encore des remplacements vers Nayra/Tarek/Aïsha/Idris dans plusieurs données alors que le quatuor canonique actuel est Mathilde/Marec/Anouk/Aurélien.

## Résultats concordants

La branche contient une véritable implémentation de prototype et des contrats de smoke, mais elle n'est pas encore une source canonique fusionnée.

## Contradictions / limites

La contradiction de roster est bloquante pour une promotion en `active` : une branche de Vertical Slice ne peut pas être déclarée conforme au canon actuel tant qu'elle réintroduit l'ancien quatuor dans des données pertinentes.

## Recherche opposée

Tentative de promotion : la présence du graphe GE01 et de nombreux smokes pourrait justifier un statut techniquement avancé. Contre-preuve : PR toujours ouverte, non fusionnée, et dérive canonique explicite dans le diff.

## Ce qui est vérifié dans LITD

- prototype GE01 réel sur la branche ;
- graphe de salles explicite ;
- intention de tester navigation, Lumière, fuite, persistance, refuge, extraction et sauvegarde/restauration.

## Ce qui reste inconnu

- conformité de la branche avec le quatuor actuel après rebase/correction ;
- état complet des CI actuelles ;
- intégration propre sur `main` ;
- conformité au calibrage récent VS01.

## Conditions de promotion

Promouvoir seulement après : correction de toutes les références au roster obsolète, rebase/alignement sur `main`, CI et smokes verts, absence de contradiction canonique, puis fusion de la PR ou d'une version équivalente validée.

## Relations Knowledge Graph

- source_for: galeries-eteintes-runtime
- contradicts: obsolete-starting-quartet
- validated_by: future-ge01-green-merge
- influences: vertical-slice-01, remanence-runtime-validation
