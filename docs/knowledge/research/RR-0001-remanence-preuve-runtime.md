# Research Record — Rémanence / preuve runtime

- ID: RR-0001
- Date: 2026-09-10
- Domaine: persistence / remanence
- Question: La Rémanence et la persistance de ses conséquences sont-elles aujourd'hui prouvées dans le runtime ou les tests actuels de `main` ?
- Niveau: R0
- Statut: revalidate
- Confiance: medium

## Qui ? Quoi ? Où ? Pourquoi ? Comment ?

- Qui : système LITD Development Intelligence / équipe LITD.
- Quoi : invariant de Rémanence et persistance de conséquences entre états de jeu.
- Où : dépôt `hodaesu/litd`, branche `main`, données, scripts, tests et workflows.
- Pourquoi : ne pas confondre canon de design, preuve historique et preuve technique actuelle.
- Comment : recherche ciblée dans le dépôt courant et contrôle du catalogue/Guardian existants.

## Hypothèses de départ

Le concept de Rémanence est canonique dans la conception LITD, mais son état d'implémentation runtime actuel doit être démontré avant promotion en connaissance techniquement validée.

## Sources

- `docs/knowledge/CATALOG.md` sur `main`, passe 2026-09-10 : indique explicitement qu'aucune preuve actuelle suffisamment nette n'a été retrouvée et classe le sujet `to_verify`.
- Recherche de code sur `main` avec le terme `remanence` : aucune occurrence exploitable retournée par l'index GitHub lors de cette passe.

## Résultats concordants

Aucune preuve runtime ou test automatisé suffisamment nette n'a été retrouvée pendant cette passe pour certifier la persistance de Rémanence.

## Contradictions / limites

- Une absence de résultat dans l'index de recherche n'est pas une preuve absolue d'absence de code.
- Des implémentations peuvent utiliser un autre vocabulaire ou être présentes dans une branche/PR non fusionnée.
- Le canon de design ne suffit pas à certifier l'implémentation courante.

## Recherche opposée

Tentative de réfutation : recherche d'une preuve directe sur `main` qui permettrait de promouvoir Rémanence en `active`. Aucun test, contrat ou fichier runtime actuel suffisamment explicite n'a été identifié pendant cette passe.

## Ce qui est vérifié dans LITD

Le catalogue vivant reconnaît déjà le sujet et exige une preuve actuelle avant promotion.

## Ce qui reste inconnu

- fichier/runtime propriétaire de la Rémanence ;
- format de persistance ;
- comportement save/load ;
- propagation des conséquences ;
- test reproductible démontrant la persistance.

## Conditions de promotion

Le statut pourra passer à `active` / techniquement validé si au moins une preuve actuelle relie explicitement : état de Rémanence → sauvegarde/persistance → rechargement ou transition → conséquence observable, avec test automatisé ou smoke reproductible sur `main`.

## Décisions influencées

Ne pas durcir le Guardian sur Rémanence tant que la preuve technique actuelle n'est pas disponible.

## Date ou condition de revalidation

Revalider dès qu'un test ou une implémentation de persistance de Rémanence est fusionné sur `main`.

## Relations Knowledge Graph

- source_for: remanence-runtime-validation
- contradicts: remanence-assumed-implemented-without-proof
- validated_by: future-remanence-persistence-test
- influences: guardian-remanence-policy
