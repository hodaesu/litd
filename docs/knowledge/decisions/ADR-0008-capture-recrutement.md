# ADR-0008 — Capture et recrutement des créatures

- Statut : revalidate
- Confiance : high_for_ange / medium_high_for_other_rules
- Domaine : gameplay / capture / progression
- Date : 2026-09-10
- Niveau de recherche : R1 (règle Guardian actuelle + preuve historique fusionnée)

## Qui ?
Les créatures capturables, les boss, le joueur et les systèmes de capture/recrutement.

## Quoi ?
Le canon actuellement protégé par le Guardian impose que le boss Ange ne soit jamais capturable. Le noyau roguelike historiquement fusionné décrit également une capture conditionnée aux blessures, une limite de deux captures par zone et un blocage possible par Manifestation destructrice.

## Où ?
- `docs/knowledge/guardian-rules.yml` : règle `angel-not-capturable`, sévérité rouge, validation automatisée pour les créatures capturables.
- PR #70 fusionnée : règles roguelike de capture et parcours UI incluant capture avant extraction.

## Pourquoi ?
La capture touche le bestiaire, la progression, l’équilibrage et le canon des boss. Une divergence peut rendre un boss recruté à tort, casser la rareté d’une famille ou produire des sauvegardes incompatibles.

## Comment ?
Les interdictions canoniques doivent être exprimées dans les données et/ou invariants testables, pas uniquement dans l’UI. Le Guardian doit bloquer les violations de règles canoniques dures ; les limites de recrutement plus fines doivent rester `revalidate` tant que leur implémentation actuelle n’est pas reconfirmée.

## Éléments de preuve
Le Guardian actuel contient explicitement `angel-not-capturable` en sévérité rouge avec validation automatisée. La PR #70, fusionnée le 2026-08-22, documente une capture conditionnée aux blessures, une limite de deux par zone, la Manifestation destructrice et les boss/Ange non capturables, avec un parcours UI de capture validé à la date de fusion.

## Contre-preuves / tentative de réfutation
La PR #70 représente un état historique. Elle ne suffit pas, à elle seule, à prouver que chaque limite secondaire est encore correctement appliquée par le runtime actuel. En revanche, l’interdiction de capture de l’Ange possède encore une règle Guardian dédiée dans `main`, ce qui lui donne un niveau de preuve actuel supérieur.

## Décision
- `Ange non capturable` : invariant canonique actif, confiance élevée.
- `capture conditionnée aux blessures`, `maximum deux par zone` et `Manifestation destructrice` : connaissances historiquement validées, statut `revalidate` jusqu’à rattachement à des données/tests runtime actuels.
- aucune règle secondaire ne doit être annoncée comme fonctionnelle uniquement à partir d’un ancien document ou d’une discussion.

## Tests et métriques à relier
- l’Ange ne peut jamais entrer dans la liste des capturables ;
- unicité des identifiants de créatures capturables ;
- tests de préconditions de capture ;
- limite de recrutement/capture testée dans le runtime réel ;
- sauvegarde/rechargement d’une créature recrutée.

## Relations Knowledge Graph
- validated_by: guardian-rules.yml pour l’Ange
- historical_evidence: PR #70 pour les règles secondaires
- influences: bestiaire, progression, combat, sauvegarde, sanctuaire
- risk_for: incohérence canonique, exploitation de progression, corruption de roster

## Conditions de réexamen
Réexaminer lors de toute modification du bestiaire, des règles de recrutement, du boss Ange, des sanctuaires ou du format de sauvegarde des créatures.