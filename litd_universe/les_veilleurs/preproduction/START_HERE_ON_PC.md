# START HERE — Première session PC / Godot

Cette branche contient le gel de préproduction. Ne copier aucun squelette dans le runtime principal avant lecture et validation : les fichiers `gd_skeletons` n'ont pas encore été compilés.

## 1. Avant de coder

- Checkout `les-veilleurs-prepc-freeze-2026-09-03`.
- Lire `PRE_PC_FREEZE.md`, `TECHNICAL_CONTRACTS.md`, `CONTENT_CONTRACTS.md`, `PRODUCTION_ORDER_AND_GATES.md`.
- Vérifier que les IDs V01-V04 et B01-B03 ne collisionnent avec aucun ID existant.
- Réconcilier uniquement les libellés ultimes d'Aïsha ; ne pas changer les IDs.
- Localiser le dernier corpus détaillé des 315 compétences. Importer le dernier état validé, jamais une ancienne variante par défaut.

## 2. Premier objectif technique : Gate G0

Créer l'importeur/loader et porter le `content_validator.gd` dans le code réel. Avant tout combat, obtenir un rapport qui garantit : 21 arbres, 315 compétences, 21 ultimes, 25 archétypes, 75 orientations, IDs uniques, références résolues et 15 slots uniques par arbre.

Le prototype peut commencer avec un sous-ensemble de compétences, mais le registre complet doit accepter explicitement un mode `prototype_subset` ; il ne faut jamais faire passer silencieusement 30 compétences pour un corpus complet.

## 3. Deuxième objectif : noyau déterministe

Implémenter EventBus, flux RNG séparés, SaveGame versionné et tests de round-trip. Aucun gameplay complexe avant qu'une entité sauvegardée/rechargée conserve exactement son unique_id, sa seed et son état.

## 4. Combat vertical minimal

Implémenter ActionIntent -> TargetValidation -> Preparation -> Contact -> Armor -> Tissue/Lesions -> FunctionalConsequences -> Dismemberment -> Incapacity/Death -> Recovery -> Events.

Commencer avec une anatomie humanoïde et quelques impacts représentatifs. Une perte de fonction doit immédiatement désactiver une action incompatible.

## 5. SPE + IA

Créer un seul ennemi capable d'entendre sans voir. Test attendu : il enquête sur une position estimée, peut être trompé, perd de la certitude et ne connaît jamais les coordonnées réelles sans perception valide.

## 6. Rémanence minimale

Créer un ennemi survivant, une blessure persistante, un cadavre, une cicatrice de salle et une mémoire. Sauvegarder, quitter, recharger, revenir. Tous doivent conserver la même identité.

## 7. Ralliement minimal

Un ennemi ralliable doit passer ennemi -> neutralisé/capturé ou volontaire -> recrue sans reset anatomique. Son unique_id, ses blessures et sa mémoire restent identiques.

## 8. Refuge I

Quatre places, un résident, une affectation, un besoin, un événement relationnel, une demande de départ. Le choix doit produire mémoire et conséquence politique.

## 9. Vertical slice

Assembler une courte expédition avec un représentant de chaque famille, au moins trois formes de ralliement, un boss technique non ralliable, extraction et retour au Refuge. Ne pas viser le contenu complet avant PASS des gates.

## 10. Profilage mobile

Exporter très tôt vers un iPhone/iPad cible. Mesurer et tester : temps de chargement, mémoire, CPU, taille tactile, lisibilité anatomique, densité UI, sauvegardes interrompues, reprise après suspension iOS.

## Décisions à prendre uniquement après prototype

Dégâts/PV, probabilités, cooldowns, usages exacts des ultimes, vitesse XP, coûts, densité d'ennemis, fréquence d'événements, durées d'animation, haptique, limite numérique de mémoire IA et difficulté.

## Définition du premier succès

Le projet est prêt à étendre son contenu uniquement lorsqu'un run complet prouve : combat corporel lisible ; IA perceptive honnête ; ralliement influencé par l'état du corps ; mort/cadavre persistants ; mémoire/relation cohérentes ; Refuge fonctionnel ; save transactionnelle robuste ; UI mobile jouable.
