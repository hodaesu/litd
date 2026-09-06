# LITD : Les Veilleurs — Fondation de contenu v2

Cette couche raccorde **Les Veilleurs** à l’architecture déjà présente dans `data/veilleurs/` en utilisant le référentiel maître récupéré le 3 septembre 2026 comme source prioritaire.

## Source de vérité vérifiée

Source : `LITD_Les_Veilleurs_Referentiel_Combat_Maitre_Narratif.xlsx`.

Pack d’archive : `/LITD/Les_Veilleurs/PrePC_Canonical_2026-09-03/LITD_Les_Veilleurs_Canonical_PrePC_Pack_2026-09-03.zip`.

SHA-256 : `0739666c23b6aad99d79128147b84322155bbdd5ff49c62b0990eaf11fec8919`.

Les fichiers de provenance de la PR #163 sont vendus dans `data/veilleurs/canonical_prepc_2026_09_03/` et `docs/veilleurs/canonical_prepc_2026_09_03/`.

## Bestiaire verrouillé

- 24 ennemis ordinaires ;
- 8 familles : Déliés, Pèlerins Fendus, Gardiens de Pierre, Bêtes de Suie, Silencieux, Veines, Porte-Cendres, Gardiens de Version ;
- 5 boss ;
- 29 entités de combat au total.

Les 24 noms ordinaires sont dans `species_catalog_recovered_v1.json`. Le registre maître 29 entités est dans `canonical_prepc_2026_09_03/bestiary_registry_v1.json`.

Les anciennes structures 5/25, 6/24 et 7/15 restent archivales et ne doivent pas repeupler les données de production.

## Rencontres et synergies

Les **64 rencontres** sont verrouillées par nom, type, nombre d’acteurs et composition dans `encounter_index_v1.json`.

Le maximum observé dans le référentiel est de 4 acteurs ennemis dans une composition, compatible avec le budget mobile actuel.

Les **21 synergies ennemies** sont dans `enemy_synergy_catalog_v1.json`. Le référentiel ne leur donne pas de noms séparés : chacune est définie par une paire, une force 1–3, un fonctionnement et un contre-jeu. Aucun nom de synergie artificiel n’est ajouté.

Le générateur hybride conserve ses règles d’anti-répétition et projette la Rémanence après le layout. Il ne crée jamais artificiellement une Némésis.

## Boss — canon actuel

1. **Ishar, Gardien du Passage** — 3 phases ;
2. **Orateur Sans Voix** — 3 phases ;
3. **Mère des Veines** — 3 phases ;
4. **Porte-Cendres Blanc** — 3 phases ;
5. **Le Copiste** — 4 phases.

Total : **16 phases**, détaillées dans `boss_phase_catalog_v1.json` avec doctrine, déclenchement, mécanique, contre-jeu, arène, intentions, erreur punie, transition et récompense.

Les cinq boss sont **non recrutables**. Leur connaissance reste limitée aux phases effectivement observées.

## Recrutement et Refuge

Le référentiel distingue explicitement **capture/neutralisation** et **ralliement** : capturer ne recrute jamais automatiquement.

Les blessures ne sont pas effacées lors du ralliement.

Capacité du Refuge :

- Acte I : 4 ;
- Acte II : 6 ;
- Acte III : 8 ;
- Acte IV : 10 ;
- Acte V : 12.

Équipe active : 4 combattants maximum avec au moins 1 Veilleur.

Pour les huit ennemis ordinaires de l’Acte I, la source dit seulement `Auxiliaire possible; ne remplace jamais un Veilleur`. **Aucune condition numérique ne doit être inventée.** Les Actes II–V disposent de conditions précises dans `canonical_prepc_2026_09_03/system_rules_v1.json`.

Le Refuge utilise 12 familles d’événements et quatre axes relationnels : Confiance, Respect, Peur, Ressentiment. Le contrat runtime est `refuge_runtime_contract_v1.json`.

## Archives et Rémanence

États de connaissance canoniques :

`UNKNOWN → SUSPECTED → OBSERVED → CONFIRMED → UNDERSTOOD`

La Connaissance n’est pas une monnaie. **Observation ≠ certitude** et la Lumière stabilise le référentiel partagé sans créer de vérité absolue.

Les Archives gardent cinq vues : Identité/Connaissance, Corps, Combat, Histoire, Traces.

Le pack apporte :

- 29 fiches narratives de bestiaire ;
- 16 jeux de fragments Rémanence Corps/Esprit/Politique pour les ennemis des Actes II–V ;
- acquisition canonique : observation en combat, analyse/cadavre, recrutement/coexistence ;
- usages : bestiaire avancé, interactions régionales, dialogues et bonus auxiliaires.

Le contrat `remanence_archive_runtime_contract_v1.json` relie ces données aux blessures persistantes, promotions mémorielles, relations, cicatrices du monde et sauvegarde par états/flags plutôt que snapshots complets.

## Narration et dialogues

Le corpus maître maintenant raccordé contient :

- **68 barks** des quatre Veilleurs ;
- **30 lignes de dialogues de boss** ;
- **15 événements narratifs régionaux** ;
- **29 entrées narratives de bestiaire** ;
- 64 rencontres narratives dans le pack d’archive.

Les barks et dialogues de boss exacts sont vendus sous `canonical_prepc_2026_09_03/current/`. Les 15 événements sont dans `narrative_event_catalog_v1.json`.

Les dialogues restent 100 % textuels, sans doublage. Les textes doivent distinguer fait, hypothèse et incertitude ; les blessures, relations, connaissances et cicatrices peuvent modifier les futurs hooks narratifs.

## Principaux fichiers de production

- `content_foundation_v2.json`
- `species_catalog_recovered_v1.json`
- `canonical_bestiary_normalization_v2.json`
- `encounter_index_v1.json`
- `enemy_synergy_catalog_v1.json`
- `boss_phase_catalog_v1.json`
- `recruitment_refuge_contract_v1.json`
- `refuge_runtime_contract_v1.json`
- `remanence_entity_contract_v1.json`
- `remanence_archive_runtime_contract_v1.json`
- `archives_refuge_ui_contract_v1.json`
- `narrative_continuity_contract_v1.json`
- `narrative_event_catalog_v1.json`
- `tests/test_veilleurs_content_foundation_v2.py`

## Ce qui nécessite encore le PC / Godot

Le canon de contenu n’est plus le blocage principal. Restent à valider dans le runtime :

1. chargement des catalogues et des 64 rencontres ;
2. génération hybride et injection des cicatrices ;
3. machine d’état capture → ralliement → Refuge ;
4. capacité progressive du Refuge et sauvegarde des recrues ;
5. événements de Refuge et relations ;
6. mise à jour des Archives par Rémanence ;
7. visibilité phase-scopée des boss ;
8. résolution des hooks de dialogues ;
9. navigation tactile/manette ;
10. tests Godot, Python, Remanence Smoke, Balance Telemetry et QA avant fusion.
