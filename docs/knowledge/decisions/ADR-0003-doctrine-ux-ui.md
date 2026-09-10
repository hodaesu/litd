# ADR-0003 — Doctrine UX/UI canonique de LITD

- Statut : active
- Confiance : high
- Domaine : UX / UI / combat / accessibilité
- Date : 2026-09-10
- Niveau de recherche : R3

## Qui ?
Le joueur, les systèmes UI/HUD, combat, inventaire, compétences, exploration, hub, dialogues et accessibilité.

## Quoi ?
La doctrine de divulgation suit quatre couches : **Monde → HUD → Contexte/Décision → Inspection**. Le HUD permanent doit rester minimal ; les informations détaillées apparaissent à la demande, notamment via inspection contextuelle des héros et ennemis.

## Où ?
Référence principale : `docs/BIBLE_UX_UI_LITD.md`, fusionnée via la PR #255. L'implémentation concerne notamment les HUD, menus contextuels, inspection, ciblage, inventaire, compétences, carte, hub et inputs.

## Pourquoi ?
Réduire la surcharge visuelle tout en conservant l'accès aux informations tactiques importantes. Cette doctrine répond directement aux observations de playtest, notamment la présence d'un panneau de statistiques permanent trop envahissant.

## Comment ?
- informations critiques immédiatement visibles ;
- détails tactiques accessibles par focus/clic/tap ;
- inspection complète à la demande ;
- ciblage et preview expliquent une décision avant confirmation ;
- navigation clavier/manette/tactile cohérente ;
- accessibilité intégrée au système plutôt qu'ajoutée après coup.

## Alternatives considérées
- HUD exhaustif permanent : rejeté pour surcharge et mauvaise hiérarchisation.
- UI presque entièrement cachée : rejetée car elle nuit à la compréhension tactique.
- divulgation progressive contextuelle : retenue.

## Éléments de preuve
- PR #255 fusionnée, Bible UX/UI LITD.
- Références croisées utilisées lors de la recherche : documentation Godot, Xbox Accessibility Guidelines, travaux GDC et études de cas de jeux à forte densité tactique/interface.
- PR #251 fusionnée : ciblage manuel multiple/zone déterministe.
- PR #256 poursuit l'implémentation P0 mais reste distincte de la doctrine elle-même tant qu'elle n'est pas fusionnée.

## Contre-preuves / tentative de réfutation
Un HUD trop minimal peut cacher une information nécessaire au bon moment. La doctrine n'impose donc pas de masquer systématiquement : elle impose de choisir la bonne couche selon fréquence, urgence et coût d'accès.

## Décision
Aucun nouvel écran ou panneau permanent ne doit être ajouté par défaut si l'information peut être fournie de manière contextuelle avec un coût d'accès acceptable.

## Dépendances impactées
HUD, inspection, combat, ciblage, contrôleurs, inventaire, arbres de compétences, exploration, carte, hub, dialogue, accessibilité.

## Risques
- Trop d'étapes pour accéder à une information fréquente.
- Perte de contexte lors de la fermeture d'une inspection.
- Divergence entre souris, manette et tactile.

## Tests et métriques
- Parcours joueur UI automatisés.
- Tests de focus/restitution du focus.
- Tests de ciblage et de preview non destructive.
- Playtests de compréhension sans coaching.

## Valeur joueur
Lisibilité, réduction de charge cognitive, décisions tactiques plus compréhensibles et meilleure adaptation mobile/manette.

## Réversibilité / plan de retour arrière
Les composants peuvent être déplacés entre couches si des playtests démontrent un coût d'accès excessif, sans abandonner le principe de hiérarchie de l'information.

## Conditions de réexamen
Quand des playtests montrent qu'une information essentielle est trop lente à atteindre ou qu'un élément permanent apporte une valeur nette mesurable.

## Relations Knowledge Graph
- depends_on: canon gameplay et besoins tactiques
- influences: combat, inventaire, compétences, exploration, hub, accessibilité
- contradicts: panneaux détaillés permanents par défaut
- validated_by: PR #255
- tested_by: parcours UI, ciblage, inspection, focus
- measured_by: playtests de compréhension et friction UI
