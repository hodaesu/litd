# ADR-0002 — Quatuor canonique de départ de LITD : Les Veilleurs

- Statut : active
- Confiance : very_high
- Domaine : canon / personnages / combat
- Date : 2026-09-10
- Niveau de recherche : R0 (décision interne déjà validée et fusionnée)

## Qui ?
Le joueur, les quatre Veilleurs de départ, les systèmes de combat, progression, voix, animation, équipement, UI et QA.

## Quoi ?
Le quatuor canonique de départ est :
1. Mathilde — `duelist`
2. Marec — `breaker`
3. Anouk — `mystic`
4. Aurélien — `surgeon`

## Où ?
Dans les données héros/roster, la logique de partie, les tests de canon, l'UI, les voix, les animations et les outils de production.

## Pourquoi ?
Le projet avait accumulé plusieurs anciens quatuors concurrents. Cette décision établit une source de vérité unique et empêche leur réintroduction automatique.

## Comment ?
La PR #246 a migré le roster actif vers ces quatre héros et ajouté des garde-fous empêchant les anciens rosters d'être réexposés comme quatuor de départ. Les PR #250 et #259 ont ensuite corrigé des dépendances restées alignées sur des personnages/classes antérieurs.

## Alternatives considérées
- Nayra / Tarek / Aïsha / Idris : superseded comme roster de départ.
- Sahen / Mira / Narem / Ysra : superseded comme roster de départ.
- Aurélien / Malvor / Lysandra / Darius : superseded comme roster de départ.

Ces personnages peuvent exister ailleurs dans le projet, mais aucun ne récupère automatiquement un statut de héros de départ.

## Éléments de preuve
- PR #246 fusionnée : migration canonique du quatuor.
- PR #250 fusionnée : migration des contrats cinématiques restés sur Darius/Malvor/Lysandra.
- PR #259 fusionnée : équipement du niveau de test complété pour les classes du nouveau quatuor et smoke joueur restauré.

## Contre-preuves / tentative de réfutation
La formation exacte R1–R4 n'est pas figée par cette ADR. Elle peut évoluer selon kits/arbre/loadout si les tests et la lisibilité de combat le justifient. Le roster, lui, reste canonique tant qu'une nouvelle décision explicite ne le remplace pas.

## Décision
Toute fonctionnalité qui expose automatiquement un quatuor de départ différent est une régression canonique.

## Dépendances impactées
`data/heroes.json`, roster Veilleurs, combat, équipement, narration, audio/voix, Blender/assets, UI, tests et builds de playtest.

## Risques
- Données historiques encore présentes dans des fichiers non actifs.
- Tests ou outils secondaires pouvant réintroduire un ancien nom.
- Confusion entre ordre de roster et rang de combat.

## Tests et métriques
- Tests de roster canonique.
- Tests cinématiques interdisant le retour actif d'anciens héros.
- Contrat d'équipement minimum du quatuor de départ.
- Smoke joueur avec le roster courant.

## Valeur joueur
Cohérence narrative, identité stable du groupe de départ et absence de contradictions visibles entre écrans/systèmes.

## Réversibilité / plan de retour arrière
Un changement de quatuor exige une nouvelle ADR qui supersède explicitement celle-ci et une migration atomique des données, tests, UI, narration, assets et équipements.

## Conditions de réexamen
Uniquement si le design du quatuor de départ est volontairement modifié.

## Relations Knowledge Graph
- depends_on: canon Les Veilleurs
- influences: combat, équipement, voix, animation, UI, playtests
- contradicts: anciens rosters de départ
- supersedes: anciennes compositions de départ
- validated_by: PR #246, PR #250, PR #259
- tested_by: tests de roster/cinématique/équipement + runtime player smoke
- measured_by: CI et smoke joueur
