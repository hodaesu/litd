# ADR-0001 — Guardian progressif et non bureaucratique

- Statut : accepté
- Confiance : forte
- Domaine : qualité / gouvernance
- Date : 2026-09-10

## Qui ?
L'équipe LITD, la CI GitHub et les futurs contributeurs.

## Quoi ?
Le Guardian distingue les invariants déjà implémentés des cibles canoniques encore en cours d'implémentation.

## Où ?
Dans `docs/knowledge/guardian-rules.yml`, `tools/quality/validate_knowledge.py` et les workflows associés.

## Pourquoi ?
Un garde-fou utile doit empêcher les régressions réelles sans rendre la branche rouge pour une fonctionnalité encore volontairement incomplète. Une règle canonique non encore atteinte doit être visible, mais ne devient bloquante qu'une fois son implémentation de référence validée.

## Comment ?
- Les invariants déjà présents et mesurables peuvent être bloquants.
- Les cibles futures sont suivies comme écarts de préparation.
- Lorsqu'une cible devient réellement implémentée, un test anti-régression est ajouté dans la même évolution.
- Toute promotion vers un blocage doit citer la donnée ou le test de référence.

## Alternatives considérées
1. Bloquer immédiatement toutes les règles canoniques : rejeté, car cela rendrait la CI rouge sur des travaux non terminés.
2. Garder toutes les règles purement documentaires : rejeté, car elles n'empêcheraient aucune régression.
3. Guardian progressif : retenu.

## Éléments de preuve
Le dépôt contient actuellement des créatures avec exactement trois arbres, mais les arbres observés ne contiennent pas encore quinze compétences chacun. Cela démontre la nécessité de distinguer structure implémentée et cible finale.

## Contre-preuves / tentative de réfutation
Risque principal : une règle peut rester trop longtemps non bloquante. Mitigation : chaque écart doit rester visible et être promu en invariant automatisé dès que son implémentation de référence est validée.

## Dépendances impactées
CI, données de progression, documentation canonique, tests de gameplay.

## Risques
- Faux positifs si une règle est promue trop tôt.
- Faux sentiment de sécurité si une règle reste documentaire trop longtemps.

## Tests et métriques
- Validation structurelle du Knowledge System.
- Validation JSON des données ciblées.
- Nombre d'invariants automatisés vs candidats.
- Nombre d'écarts canoniques connus.

## Valeur joueur
Indirecte mais forte : réduit les régressions qui altèrent les règles de jeu validées.

## Réversibilité / plan de retour arrière
Chaque règle peut être rétrogradée en avertissement si elle produit des faux positifs, sans supprimer l'historique de la décision.
