# ADR-0006 — Rangs et formation de combat

- Statut : active
- Confiance : high
- Domaine : combat / UX / formation
- Date : 2026-09-10
- Niveau de recherche : R0 (import d'un contrat déjà testé dans le dépôt)

## Qui ?
Le quatuor canonique et tout système qui affiche ou résout les positions de combat.

## Quoi ?
Le système utilise les rangs R1 à R4. L'ordre visuel canonique garde R1 au contact des ennemis et affiche les rangs de gauche à droite sous la forme `R4 R3 R2 R1`.

## Où ?
- `scripts/ui/main_v47.gd`
- `scripts/core/combat_position_rules.gd`
- `tests/test_combat_formation_contract.py`
- `data/veilleurs/canonical_roster.json`

## Pourquoi ?
La position influe sur lisibilité, ciblage, fonctions de classe et cohérence tactique. Une inversion de l'ordre visuel ou une dérive entre logique et UI produit directement des erreurs de compréhension joueur.

## Comment ?
Le contrat de test verrouille :
- les classes canoniques du quatuor ;
- la distinction classes de front / arrière ;
- un départage déterministe par ordre canonique quand les scores de rôle sont égaux ;
- `visual_order := [4, 3, 2, 1]`, donc R1 côté ennemi.

## Éléments de preuve
`tests/test_combat_formation_contract.py` vérifie explicitement Mathilde=`duelist`, Marec=`breaker`, Anouk=`mystic`, Aurélien=`surgeon`, les groupes de rôles de front/arrière, le départage déterministe et l'ordre visuel R4→R1.

## Contre-preuves / tentative de réfutation
Une formation tactique précise du quatuor n'est pas figée éternellement par cette ADR. La PR #256 traite une formation candidate recalculable selon arbre/loadout. Le canon stable ici porte sur le modèle R1–R4, le sens d'affichage/contact et la cohérence des règles de position, pas sur l'interdiction future de toute variation de placement.

## Décision
R1 reste le rang de contact ennemi et l'affichage de référence reste R4→R1. Toute logique qui inverse silencieusement cette convention doit être traitée comme une régression. Les placements individuels peuvent évoluer par décision gameplay explicite tant qu'ils respectent ce contrat.

## Tests et métriques
- `tests/test_combat_formation_contract.py` ;
- cohérence logique/visuel des rangs ;
- absence de support placé devant un combattant de mêlée par simple dérive de scoring ;
- stabilité du départage déterministe.

## Relations Knowledge Graph
- depends_on: ADR-0002-quatuor-canonique-les-veilleurs
- influences: ciblage, HUD, compétences, IA, déplacement, inspection
- validated_by: `tests/test_combat_formation_contract.py`
- contradicts: toute convention ancienne plaçant visuellement R1 à gauche ou éloigné des ennemis
- risk_for: erreurs de ciblage, incohérences UI/logique, formation illisible

## Conditions de réexamen
Réexaminer uniquement si le système de rangs lui-même est redessiné explicitement ou si une nouvelle représentation tactique remplace R1–R4.