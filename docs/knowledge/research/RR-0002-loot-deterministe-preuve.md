# Research Record — Loot déterministe / preuve par seed

- ID: RR-0002
- Date: 2026-09-10
- Domaine: loot / equipment / determinism
- Question: Le loot déterministe par seed est-il aujourd'hui prouvé par une implémentation et un test actuels sur `main` ?
- Niveau: R0
- Statut: revalidate
- Confiance: medium

## Qui ? Quoi ? Où ? Pourquoi ? Comment ?

- Qui : système LITD Development Intelligence / équipe LITD.
- Quoi : invariant « même seed + même contexte → même résultat de loot ».
- Où : dépôt `hodaesu/litd`, branche `main`, Guardian, scripts, données et tests.
- Pourquoi : cet invariant est important pour la reproductibilité, le débogage et l'absence de reroll non maîtrisé.
- Comment : contrôle du Guardian actuel et recherche ciblée de preuves de génération déterministe.

## Hypothèses de départ

Le principe est canonique et suivi par le Guardian, mais sa validation technique ne doit pas être supposée tant qu'un test reproductible ne l'établit pas.

## Sources

- `docs/knowledge/guardian-rules.yml` sur `main` : règle `deterministic-loot`, sévérité orange, validation `automated_candidate`.
- `docs/knowledge/CATALOG.md` sur `main` : classe le sujet `to_verify` avant promotion.
- Recherche ciblée `deterministic loot seed` dans le dépôt par l'index GitHub : aucune preuve directe retournée lors de cette passe.

## Résultats concordants

Le dépôt déclare clairement l'invariant, mais le statut `automated_candidate` confirme qu'il s'agit encore d'un objectif de validation et non d'une preuve automatisée établie.

## Contradictions / limites

- Des seeds peuvent exister dans d'autres systèmes sans garantir le déterminisme du loot.
- Un générateur pseudo-aléatoire seedé n'est pas suffisant si l'ordre des appels ou le contexte ne sont pas stabilisés.
- L'absence de résultat de recherche n'exclut pas une implémentation nommée différemment.

## Recherche opposée

Tentative de réfutation : recherche d'un test répétant deux générations avec seed et contexte identiques et comparant les résultats. Aucun test explicite de ce type n'a été identifié pendant cette passe.

## Ce qui est vérifié dans LITD

L'invariant existe officiellement dans le Guardian et est donc suivi par le Core.

## Ce qui reste inconnu

- API canonique de génération de loot ;
- composition exacte du contexte déterministe ;
- conservation de l'ID/seed des objets ;
- stabilité de l'ordre des appels RNG ;
- test de non-reroll et test save/load associé.

## Conditions de promotion

Promouvoir en `active` / techniquement validé lorsque `main` contient un test automatisé démontrant qu'une seed et un contexte identiques produisent exactement le même loot, et qu'une variation de seed ou de contexte peut produire un résultat différent sans casser l'identité persistante des objets.

## Décisions influencées

Conserver `deterministic-loot` en `automated_candidate`; ne pas présenter l'invariant comme techniquement garanti.

## Date ou condition de revalidation

Revalider à la fusion du premier test de déterminisme de loot ou d'une implémentation dédiée accompagnée de sa preuve.

## Relations Knowledge Graph

- source_for: deterministic-loot-validation
- contradicts: deterministic-loot-assumed-validated
- validated_by: future-deterministic-loot-test
- influences: guardian-deterministic-loot
