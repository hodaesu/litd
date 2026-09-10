# Catalogue vivant LITD — Lots 01–02

Ce catalogue est un point d'entrée humain vers la bibliothèque. Il ne remplace pas le Knowledge Graph ni les données du dépôt ; il indique ce qui a déjà une fiche de connaissance structurée, son niveau de preuve et ce qui doit encore être importé ou revalidé.

## Canon / décisions actives

| ID | Sujet | Statut | Confiance | Preuves principales |
|---|---|---|---|---|
| ADR-0001 | Guardian progressif | active/accepté | high | Knowledge System + validator |
| ADR-0002 | Quatuor de départ Mathilde / Marec / Anouk / Aurélien | active | very_high | PR #246, #250, #259 |
| ADR-0003 | Doctrine UX/UI Monde → HUD → Contexte/Décision → Inspection | active | high | PR #255, Bible UX/UI |
| ADR-0004 | CI Godot par domaines + filet monolithique | active | very_high | PR #253, #257, #242 |
| ADR-0005 | Compétences des Veilleurs : 3 arbres × 15 | active | high | données `data/veilleurs/skills/*.json` |
| ADR-0006 | Convention de rangs R1–R4 / formation | active pour la convention, formation exacte évolutive | high | données/tests de formation |

## Connaissances à revalider

| ID | Sujet | Statut | Confiance | Preuves principales |
|---|---|---|---|---|
| ADR-0007 | Boucle d'expédition et Lumière | revalidate | medium_high | PR #70 fusionnée ; runtime actuel à reconfirmer |
| ADR-0008 | Capture/recrutement | active pour Ange non capturable ; revalidate pour les règles secondaires | high / medium_high | `guardian-rules.yml` + PR #70 fusionnée |

La distinction ci-dessus est volontaire : une preuve historique fusionnée confirme qu'un système a existé et a été validé à un instant donné, mais ne suffit pas à certifier son état runtime actuel après de nombreuses évolutions.

## Incidents capitalisés

- `incidents/2026-09-10-runtime-player-smoke-equipment.md` — migration du quatuor ayant révélé une couverture d'équipement de test incomplète ; cause corrigée sans fallback artificiel.

## Protocoles / gouvernance

- `README.md` — architecture du LITD Development Intelligence System.
- `LIVING_LIBRARY_PROTOCOL.md` — protocole systématique Source → Connaissance → Hypothèse → Décision → Core → Implémentation → Test → Mesure → Preuve → Réévaluation.
- `guardian-rules.yml` — premiers invariants et niveaux Guardian.
- `dependencies.yml` — dépendances structurées existantes.
- `templates/decision.md`, `templates/research.md`, `templates/incident.md` — formats normalisés.

## À importer / vérifier ensuite — priorité élevée

1. calibrage Vertical Slice 01 : durée cible, volumes de salles, actes, fenêtres d'extraction et seuils de Lumière — ne pas confondre avec ADR-0007 tant que le calibrage récent n'est pas prouvé dans Git ;
2. Rémanence et persistance des conséquences — aucune preuve actuelle suffisamment nette retrouvée lors de la passe du 2026-09-10 : statut `to_verify` ;
3. équipement/loot déterministe par seed — le Guardian contient un invariant `deterministic-loot`, mais sa validation est encore `automated_candidate` : statut `to_verify` avant promotion ;
4. exclusivité d'arbre — règle Guardian présente avec validation `automated_candidate` : rattacher à un test fiable avant de la déclarer techniquement validée ;
5. Galeries Éteintes et son état réel d'implémentation ;
6. méthode d'ingénierie LITD (PR #254 tant qu'elle n'est pas fusionnée : `revalidate`) ;
7. protocole de playtest PC / cinq testeurs naïfs (PR #243 draft : `experimental`) ;
8. trieur canonique relié au Core (PR #260 ouverte : `experimental` jusqu'à intégration).

## Règle d'admission

Un élément n'entre pas comme `active` uniquement parce qu'il apparaît dans une discussion, un ancien fichier ou une PR ouverte. Avant promotion :

- vérifier la source réelle et son état (fusionnée, ouverte, draft, remplacée) ;
- rechercher les décisions contradictoires ou plus récentes ;
- relier les tests/preuves disponibles ;
- attribuer statut et confiance ;
- noter les conditions de réexamen.

Une règle déclarée dans le Guardian avec `automated_candidate` constitue un objectif/invariant suivi, pas encore une preuve d'implémentation complète.

## Prochaine passe

Finir le Lot 02 par la recherche ciblée des preuves actuelles de Rémanence, loot déterministe, exclusivité d'arbre et calibrage Vertical Slice 01. Si les preuves restent absentes, créer des fiches `to_verify` avec conditions explicites de promotion plutôt que de produire un faux canon technique.