# Research Record — Vertical Slice 01 / Lumière / preuve actuelle

- ID: RR-0004
- Date: 2026-09-10
- Domaine: expedition / light / vertical-slice
- Question: Le calibrage récent de Vertical Slice 01 et les seuils de Lumière sont-ils aujourd'hui prouvés dans le dépôt `main` par des données, tests ou runtime actuels ?
- Niveau: R0
- Statut: revalidate
- Confiance: medium_high

## Qui ? Quoi ? Où ? Pourquoi ? Comment ?

- Qui : système LITD Development Intelligence / équipe LITD.
- Quoi : boucle d'expédition, calibrage du Vertical Slice 01 et états de Lumière.
- Où : dépôt `hodaesu/litd`, branche `main`, documentation, données, runtime et tests.
- Pourquoi : distinguer un calibrage produit validé d'une implémentation technique réellement synchronisée avec le dépôt actuel.
- Comment : contrôle du catalogue vivant, recherche ciblée dans le code et comparaison avec la connaissance déjà classée ADR-0007 `revalidate`.

## Hypothèses de départ

Le calibrage produit récent comprend une expédition standard de 35–45 min, 18–24 salles générées dont 12–17 normalement visitées, 4–6 combats ordinaires, 0–1 difficile, 3–5 événements, 2–4 découvertes, 3–5 loots significatifs, 2–4 embranchements majeurs, 2–3 fenêtres naturelles d'extraction et un boss non systématique. La Lumière part d'une base abstraite 100 avec états 76–100 clair, 51–75 faible, 26–50 sombre, 1–25 critique. Ces valeurs ne doivent toutefois pas être présentées comme runtime actuel sans preuve de dépôt.

## Sources

- `docs/knowledge/CATALOG.md` sur `main` : ADR-0007 « Boucle d'expédition et Lumière » classée `revalidate`, preuve historique PR #70 fusionnée, runtime actuel à reconfirmer.
- Le même catalogue distingue explicitement le calibrage récent de Vertical Slice 01 de l'ancien ADR-0007 et exige une preuve Git actuelle avant promotion.
- Recherche de code ciblée pendant la passe : aucune preuve actuelle suffisamment explicite n'a été retrouvée pour rattacher toutes les valeurs de calibrage au runtime `main`.

## Résultats concordants

Il existe une preuve historique qu'un système d'expédition/Lumière a été implémenté, mais pas de preuve suffisante dans cette passe que le calibrage récent complet et ses seuils sont ceux effectivement exécutés aujourd'hui sur `main`.

## Contradictions / limites

- Une PR fusionnée ancienne prouve l'existence passée du système, pas la conformité actuelle après évolutions ultérieures.
- Un document de conception peut être canonique produit sans être implémenté.
- Les valeurs peuvent être réparties dans plusieurs fichiers, calculées dynamiquement ou porter d'autres noms.

## Recherche opposée

Tentative de réfutation : rechercher sur `main` un ensemble cohérent de constantes/données/tests couvrant durée, volumes d'expédition, extraction et seuils de Lumière. Aucun ensemble complet et suffisamment net n'a été identifié pendant cette passe.

## Ce qui est vérifié dans LITD

Le sujet existe déjà dans la bibliothèque sous ADR-0007 avec statut `revalidate`. Le catalogue interdit explicitement de confondre preuve historique et état runtime actuel.

## Ce qui reste inconnu

- source unique de vérité runtime des seuils de Lumière ;
- générateur de salles et plages effectivement appliquées ;
- règles d'extraction et boss non systématique réellement actives ;
- instrumentation permettant de mesurer les 35–45 min ;
- tests ou simulations de distribution vérifiant les volumes cibles.

## Conditions de promotion

Promouvoir le calibrage récent lorsque `main` fournit des données/configurations ou constantes traçables et des tests/simulations qui démontrent les seuils de Lumière et au moins les principaux contrats structurels de l'expédition. La durée 35–45 min doit idéalement être reliée à une mesure de playtest ou télémétrie plutôt qu'à une constante arbitraire.

## Décisions influencées

Maintenir ADR-0007 en `revalidate`; traiter le calibrage récent comme canon produit à implémenter/reconfirmer, et non comme preuve runtime acquise.

## Date ou condition de revalidation

Revalider lors de la fusion d'une implémentation/configuration Vertical Slice 01 explicitement alignée sur ce calibrage, puis après première mesure de playtest exploitable.

## Relations Knowledge Graph

- source_for: vertical-slice-01-runtime-validation
- contradicts: vertical-slice-calibration-assumed-runtime
- validated_by: future-expedition-light-contract-tests
- influences: expedition-guardian-policy, player-pacing-validation
