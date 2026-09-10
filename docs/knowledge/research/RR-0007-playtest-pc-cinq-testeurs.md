# Research Record — Playtest PC / cinq testeurs naïfs

- ID: RR-0007
- Date: 2026-09-10
- Domaine: player-validation / UX / production
- Question: Le protocole de playtest PC et ses résultats peuvent-ils être considérés comme validés ?
- Niveau: R0
- Statut: experimental
- Confiance: high

## Qui ? Quoi ? Où ? Pourquoi ? Comment ?

- Qui : équipe LITD et cinq testeurs n’ayant pas suivi le design.
- Quoi : gate de production PC et protocole de cinq sessions naïves.
- Où : PR #243, draft, `docs/PLAYTEST_5_NAIVE_TESTERS_PROTOCOL.md` et workflows associés.
- Pourquoi : séparer validation technique du build et compréhension réelle par des joueurs.
- Comment : contrôle de l’état de la PR, du protocole, des gates et du statut des observations humaines.

## Sources

- PR #243 : ouverte et draft ; validation technique annoncée `PASS`, validation humaine `NOT_RUN`.
- Protocole : cinq testeurs distincts, observation sans coaching, questionnaire post-session, seuils de gate et décisions `RETEST`, `ITERATE` ou `READY_FOR_NEXT_SLICE`.
- Le protocole exige notamment que les systèmes signature soient compris sans explication, et précise que cinq réussites de parcours ne suffisent pas à valider le slice.

## Résultats concordants

Le protocole est structuré et exploitable. Il distingue correctement preuve technique et preuve humaine.

## Contradictions / limites

Aucune conclusion sur la compréhension joueur ne peut être tirée tant que `human_validation_status=NOT_RUN` et que les cinq sessions n’ont pas été exécutées. La PR reste volontairement draft.

## Recherche opposée

Tentative de promotion : les smokes/builds peuvent être verts. Contre-preuve : le but même de la PR est de mesurer ce que l’automatisation ne peut pas établir ; les données humaines manquent encore.

## Ce qui est vérifié dans LITD

- protocole écrit ;
- critères observables ;
- build lié à un commit/hash ;
- séparation validation technique / humaine.

## Conditions de promotion

Passer de `experimental` à `active` pour le protocole après fusion. Pour une conclusion `READY_FOR_NEXT_SLICE`, exiger les cinq sessions réelles, les résultats consolidés, les seuils atteints et l’absence de blocage critique non corrigé.

## Relations Knowledge Graph

- source_for: pc-naive-playtest-protocol
- contradicts: technical-green-implies-player-validation
- validated_by: five-real-naive-playtests
- influences: player-value, ux-iteration, vertical-slice-readiness
