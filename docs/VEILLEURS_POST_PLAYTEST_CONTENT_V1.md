# LITD : Les Veilleurs — contenu parallèle post-playtest v1

## But

Préparer les couches de contenu qui peuvent avancer sans PC **sans modifier la version destinée au playtest Windows**.

La référence de départ est le commit `0c905800ec21e646e9252f1c14430ed8ad36ada3` de la PR #173. Les ajouts de cette branche ne sont pas branchés au runtime actif et ne doivent pas être fusionnés dans la branche de playtest avant décision explicite après les retours de test.

## Fichier principal

`data/veilleurs/parallel_content/post_playtest_content_v1.json`

Il regroupe huit chantiers préparatoires :

1. **Narration** — branchements futurs vers les barks canoniques, le bestiaire narratif, les dialogues de boss et les fragments de Rémanence II–V. La règle est de réutiliser la source maître avant toute nouvelle écriture canonique.
2. **Actes II–V** — index des espèces, rencontres, synergies, boss, nombres de phases et capacités du Refuge déjà établis.
3. **Altérations d’expédition** — six familles de réglages candidates, temporaires et désactivées. Ce sont des propositions techniques, pas du canon tant qu’elles ne sont pas validées par le playtest.
4. **Archives** — hooks futurs pour Identité/Connaissance, Corps, Combat, Histoire et Traces. La perception actuelle peut réduire le détail affiché mais ne supprime jamais une connaissance acquise.
5. **Refuge** — les 12 familles canoniques d’événements sont préparées comme hooks de résolution, avec les quatre axes relationnels et la capacité 4/6/8/10/12.
6. **Rémanence / Némésis** — variantes fondées uniquement sur l’histoire réellement vécue. Aucun spawn artificiel, aucune connaissance omnisciente et aucun gonflement artificiel de PV.
7. **UX FR** — microtextes candidats pour l’incertitude, les phases de boss inconnues, le ciblage anatomique, l’extraction, le Refuge et la Rémanence. Aucun pourcentage de capture ni vérité cachée révélée.
8. **Équilibrage** — registre de knobs télémétriques post-playtest. Aucun chiffre actif n’est modifié ; les réglages sont destinés à être appliqués un par un après mesure.

## Invariants canoniques protégés

- Connaissance : `UNKNOWN → SUSPECTED → OBSERVED → CONFIRMED → UNDERSTOOD`.
- Les niveaux 0–5 restent uniquement une projection de détail UI.
- La connaissance n’est pas une monnaie.
- Capture ≠ recrutement/ralliement.
- Les blessures ne sont pas remises à zéro au ralliement.
- Les cinq boss ne sont pas recrutables.
- Équipe : 4 maximum, au moins un Veilleur.
- Refuge : capacités I→V = 4 / 6 / 8 / 10 / 12.
- Une rencontre ne peut contenir qu’un ennemi Mémoriel au maximum.
- Un Némésis ne peut jamais apparaître artificiellement : il doit avoir une histoire partagée.
- Pas de snapshot complet de scène pour la Rémanence.

## Protection du playtest

Le paquet est explicitement `enabled_by_default: false` et `runtime_wiring: none_until_post_playtest_merge`.

Le test `tests/test_veilleurs_post_playtest_content_v1.py` vérifie notamment que les contrats actifs `content_foundation_v2.json`, `encounter_generation_contract_v1.json` et `archives_refuge_ui_contract_v1.json` ne référencent pas le paquet parallèle. Il compare également les garde-fous au référentiel canonique déjà présent dans le dépôt.

## Après le playtest PC

Les retours doivent être classés avant activation : lisibilité tactique, durée des combats, pression hémorragique, lumière/bruit, densité de rencontres, compréhension du ralliement, clarté des télégraphes de boss et charge cognitive de l’interface.

Une modification d’équilibrage doit changer une seule famille de paramètres à la fois et enregistrer le build, la seed et l’état de la partie. Les nouvelles couches narratives ou de Rémanence doivent rester pilotées par les événements vécus et par la connaissance acquise, jamais par une omniscience du système.
