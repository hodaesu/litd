# START HERE — Première session PC / Godot

Cette branche contient le gel de préproduction corrigé après récupération du référentiel combat maître narratif.

## 0. Récupérer la source canonique

Dans la bibliothèque ChatGPT, matérialiser :

`/LITD/Les_Veilleurs/PrePC_Canonical_2026-09-03/LITD_Les_Veilleurs_Canonical_PrePC_Pack_2026-09-03.zip`

Le pack contient les feuilles du classeur maître exportées sans ressaisie en JSON, avec `current/`, `legacy/` et `MANIFEST.json`.

Le fichier source original reste : `LITD_Les_Veilleurs_Referentiel_Combat_Maitre_Narratif.xlsx`.

## 1. Lire avant de coder

- `CANON_RECOVERY_2026-09-03.md`.
- `PRE_PC_FREEZE.md`.
- `TECHNICAL_CONTRACTS.md`.
- `CONTENT_CONTRACTS.md`.
- `PRODUCTION_ORDER_AND_GATES.md`.
- `schemas/CONTENT_SCHEMA_V1.json` — actuellement schema_version 2 malgré le nom historique du fichier.

Ne pas utiliser l'ancien contrat 315 comme validation active.

## 2. Gate G0 — Veilleurs

Porter le validateur dans le code réel et charger le registre complet de référence :

- 12 arbres Veilleurs.
- 180 compétences normales.
- 12 ultimes séparés.
- 15 compétences normales par arbre.
- IDs uniques.

Le prototype peut utiliser un sous-ensemble, mais doit le déclarer explicitement `prototype_subset`.

## 3. Gate G0B — ennemis/boss

Le corpus de référence actuel doit compter :

- 24 ennemis ordinaires.
- 5 boss.
- 29 entités.
- 87 arbres.
- 1 305 compétences normales.
- 87 ultimes.

Ne pas instancier les 1 305 compétences dès le début. Valider le corpus, puis n'importer que les entités de la verticale.

## 4. Ultimes Veilleurs actuels

Nayra : `La Ligne ne rompt pas`, `Le Poids du Mur`, `Pas un de plus`.

Tarek : `La Proie n’a plus d’ombre`, `Les Sept Ouvertures`, `Là où nul ne regarde`.

Aïsha : `Carte parfaite du vivant`, `Tout ce qui peut être sauvé`, `Le Dernier Battement`.

Idris : `Le Verdict tombe`, `Un seul mouvement`, `Que l’ordre se brise`.

Baseline du référentiel : N16=1 charge, N32=2, N48=3, avec une activation maximum du même ultime par rencontre. À mesurer en playtest, pas à réinventer avant prototype.

## 5. Noyau déterministe

Implémenter EventBus, flux RNG séparés, SaveGame versionné et tests de round-trip. Une entité sauvegardée/rechargée conserve exactement unique_id, seed, corps, équipement, mémoire et état.

## 6. Combat vertical minimal

ActionIntent -> TargetValidation -> Preparation -> Contact -> Armor -> Tissue/Lesions -> FunctionalConsequences -> Dismemberment -> Incapacity/Death -> Recovery -> Events.

Commencer avec une anatomie humanoïde et quelques compétences exactes de Nayra/Tarek tirées de `competences_180.json`.

## 7. SPE + IA

Créer un ennemi qui peut entendre sans voir. Il enquête sur une position estimée, peut être trompé, perd de la certitude et ne connaît jamais les coordonnées réelles sans perception valide.

## 8. Rémanence minimale

Importer les tables `remanence_blessures.json` et `traces_psychologiques.json`. Créer un survivant mémoriel, une blessure persistante, un cadavre, une cicatrice de salle et une mémoire. Save/load puis retour : identités inchangées.

## 9. Ralliement minimal

Utiliser une entité du roster actuel dont la fiche autorise un rôle auxiliaire/ralliement. Le passage hostile -> neutralisé/volontaire -> auxiliaire ne réinitialise ni anatomie, ni unique_id, ni mémoire.

## 10. Rencontres

Importer un sous-ensemble de `compositions_64.json`, `profondeur_spawn.json`, `synergies_ennemis.json`, `dangers_combat.json` et les données de l'Acte I.

Limite actuelle de référence : 4 acteurs ennemis simultanés maximum en combat standard mobile.

## 11. Boss vertical

Premier boss : **Ishar, Gardien du Passage**. Utiliser ses 3 phases issues du référentiel, puis valider transitions, mémoire/adaptation et contrôle du seuil.

## 12. Refuge I

Quatre places, un résident, une affectation, un besoin, un événement relationnel, une demande de départ. La décision produit mémoire et conséquence politique.

## 13. Tests

Importer `tests_48.json`. Automatiser d'abord les cas qui concernent la verticale, puis étendre jusqu'aux 48.

## 14. Vertical slice

Une expédition Acte I complète : exploration -> rencontre -> blessure/Trace -> ralliement ou extraction -> Ishar ou extraction -> Refuge -> nouvelle expédition avec Rémanence visible.

## 15. Profilage mobile

Exporter tôt sur iPhone/iPad cible : temps de chargement, mémoire, CPU, taille tactile, lisibilité anatomique, densité UI, suspension/reprise iOS et autosave interrompu.

## Ce qui exige réellement le PC

- Compiler les squelettes GDScript.
- Brancher le CombatResolver.
- Intégrer le générateur/IA/boss runtime.
- Exécuter les 48 tests.
- Mesurer l'équilibrage et le tactile.

La récupération du corpus éditorial n'est plus un blocage : le contenu exact a été retrouvé et emballé.
