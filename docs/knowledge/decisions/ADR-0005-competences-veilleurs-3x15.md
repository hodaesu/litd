# ADR-0005 — Compétences des Veilleurs : 3 arbres × 15 compétences

- Statut : active
- Confiance : high
- Domaine : gameplay / progression / combat
- Date : 2026-09-10
- Niveau de recherche : R0 (import de canon déjà implémenté et auditable dans le dépôt)

## Qui ?
Les quatre Veilleurs canoniques : Mathilde, Marec, Anouk et Aurélien.

## Quoi ?
Chaque Veilleur dispose de trois arbres de compétences, contenant chacun quinze compétences structurées. Les données sont séparées par héros dans `data/veilleurs/skills/`.

## Où ?
- `data/veilleurs/skills/mathilde.json`
- `data/veilleurs/skills/marec.json`
- `data/veilleurs/skills/anouk.json`
- `data/veilleurs/skills/aurelien.json`
- contrats associés dans `data/veilleurs/skills/source_contract.json` et `resolver_contract.json`

## Pourquoi ?
La profondeur des arbres constitue un invariant de progression et une partie du canon des Veilleurs. La bibliothèque doit permettre de détecter toute réduction accidentelle, duplication ou retour vers une ancienne structure.

## Comment ?
Le contenu reste data-driven. Le resolver ne doit pas coder des exceptions arbitraires propres à un héros lorsque le comportement peut être décrit dans les données/contrats.

## Éléments de preuve
Le dépôt contient quatre fichiers de compétences distincts pour Mathilde, Marec, Anouk et Aurélien. Le fichier de Mathilde expose explicitement trois arbres (`traque`, `entaille`, `disparition`) et quinze entrées numérotées par arbre, avec un ultime associé à chaque arbre. Les autres Veilleurs possèdent leurs propres fichiers structurés dans le même répertoire.

La PR #247 documente également l'audit courant du quatuor à 3×15, soit 45 compétences par Veilleur et 180 au total, mais cette PR étant encore ouverte elle n'est utilisée ici que comme preuve corroborante, pas comme autorité principale.

## Contre-preuves / tentative de réfutation
Le système global LITD contient encore des créatures dont les arbres n'ont pas tous quinze compétences. ADR-0001 impose donc de ne pas généraliser cet invariant des quatre Veilleurs à toutes les créatures tant que leur implémentation de référence n'est pas complète.

## Décision
Pour les quatre Veilleurs canoniques, 3×15 est un invariant actif. Toute modification qui réduit le nombre d'arbres ou de compétences doit être traitée comme une régression sauf décision canonique explicite qui supersède cette ADR.

## Tests et métriques
- nombre d'arbres par Veilleur = 3 ;
- nombre de compétences par arbre = 15 ;
- unicité des IDs de compétences ;
- présence d'un ultime par arbre ;
- validation des contrats source/resolver.

## Relations Knowledge Graph
- depends_on: ADR-0002-quatuor-canonique-les-veilleurs
- influences: progression, combat, UI des arbres, équilibrage, resolver
- validated_by: données `data/veilleurs/skills/*.json`
- risk_for: régressions de progression, UI incomplète, données orphelines

## Conditions de réexamen
Réexaminer si le canon de progression change explicitement, si les arbres sont restructurés, ou si une migration remplace le format actuel des données.