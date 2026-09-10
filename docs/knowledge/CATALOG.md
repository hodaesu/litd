# Catalogue vivant LITD — Lot 01

Ce catalogue est un point d'entrée humain vers la bibliothèque. Il ne remplace pas le Knowledge Graph ni les données du dépôt ; il indique ce qui a déjà une fiche de connaissance structurée et ce qui doit encore être importé ou revalidé.

## Canon / décisions actives

| ID | Sujet | Statut | Confiance | Preuves principales |
|---|---|---|---|---|
| ADR-0001 | Guardian progressif | active/accepté | high | Knowledge System + validator |
| ADR-0002 | Quatuor de départ Mathilde / Marec / Anouk / Aurélien | active | very_high | PR #246, #250, #259 |
| ADR-0003 | Doctrine UX/UI Monde → HUD → Contexte/Décision → Inspection | active | high | PR #255, Bible UX/UI |
| ADR-0004 | CI Godot par domaines + filet monolithique | active | very_high | PR #253, #257, #242 |

## Incidents capitalisés

- `incidents/2026-09-10-runtime-player-smoke-equipment.md` — migration du quatuor ayant révélé une couverture d'équipement de test incomplète ; cause corrigée sans fallback artificiel.

## Protocoles / gouvernance

- `README.md` — architecture du LITD Development Intelligence System.
- `LIVING_LIBRARY_PROTOCOL.md` — protocole systématique Source → Connaissance → Hypothèse → Décision → Core → Implémentation → Test → Mesure → Preuve → Réévaluation.
- `guardian-rules.yml` — premiers invariants et niveaux Guardian.
- `dependencies.yml` — dépendances structurées existantes.
- `templates/decision.md`, `templates/research.md`, `templates/incident.md` — formats normalisés.

## À importer ensuite — priorité élevée

Ces sujets ont déjà des preuves fortes dans Git ou des décisions explicites, mais n'ont pas encore tous une fiche dédiée dans la bibliothèque :

1. système de compétences Veilleurs : 3 arbres × 15 compétences par héros, exclusivité d'arbre et ultimes ;
2. règles de formation/rangs R1–R4 et distinction roster vs position tactique ;
3. boucle d'expédition et Vertical Slice 01 : durée cible, volumes, actes, Lumière et extraction ;
4. Rémanence et persistance des conséquences ;
5. règles de capture/recrutement et exceptions de boss ;
6. équipement/loot déterministe par seed et contrats de test ;
7. Galeries Éteintes et son état réel d'implémentation ;
8. méthode d'ingénierie LITD (PR #254 tant qu'elle n'est pas fusionnée : statut à revalider) ;
9. protocole de playtest PC / cinq testeurs naïfs (PR #243 draft : experimental) ;
10. trieur canonique relié au Core (PR #260 ouverte : experimental jusqu'à intégration).

## Règle d'admission

Un élément n'entre pas comme `active` uniquement parce qu'il apparaît dans une discussion, un ancien fichier ou une PR ouverte. Avant promotion :

- vérifier la source réelle et son état (fusionnée, ouverte, draft, remplacée) ;
- rechercher les décisions contradictoires ou plus récentes ;
- relier les tests/preuves disponibles ;
- attribuer statut et confiance ;
- noter les conditions de réexamen.

## Prochaine passe

Lot 02 : **Gameplay canonique et invariants joueur**. Priorité au système de compétences, aux rangs/formation, à la boucle d'expédition/Lumière et aux règles de capture, avec confrontation systématique aux données/tests du dépôt avant écriture.
