# LITD : Les Veilleurs — contenu parallèle post-playtest v1

## But

Préparer les couches de contenu qui peuvent avancer sans PC **sans modifier la version destinée au playtest Windows**.

La référence de départ reste le commit `0c905800ec21e646e9252f1c14430ed8ad36ada3` de la PR #173. La PR #180 reste volontairement en brouillon, empilée sur `feature/veilleurs-content-foundation-v2`, désactivée par défaut et non câblée au runtime actif.

## Manifeste

`data/veilleurs/parallel_content/post_playtest_detail_manifest_v1.json`

Le manifeste v5 indexe désormais les événements du Refuge, leurs chaînes, leur exécution, le handoff Godot du service mémoire, la sauvegarde/migration, les fixtures/collisions, les réactions individuelles des auxiliaires, les événements régionaux et leurs échos, 8 chaînes multi-actes, la narration, l'UX, la télémétrie, le diagnostic, les altérations et les variantes de Rémanence/Némésis.

## Refuge — 24 événements et mémoire persistante

- `refuge_event_templates_v1.json` : 24 événements, deux pour chacune des 12 familles canoniques.
- `refuge_event_chains_v1.json` : 24 chaînes persistantes, une par événement, avec deux branches correspondant aux deux choix source.
- `refuge_chain_execution_contract_v1.json` : cycle `DORMANT → ELIGIBLE → QUEUED → SURFACED → RESOLVED/EXPIRED → RETIRED`.
- `refuge_memory_service_contract_v1.json` : API/signaux/intégration prévus pour Godot.
- `refuge_memory_save_schema_v1.json` : racine candidate `veilleurs_refuge_memory`, migration v1, aucun snapshot de scène.
- `refuge_memory_fixtures_v1.json` : 8 fixtures déterministes.
- `refuge_memory_collision_scenarios_v1.json` : 8 collisions de souvenirs.

Un rappel exige toujours une histoire réellement écrite et des conditions observables. L'arbitrage est déterministe et la file est persistée : recharger ne reroll pas le Refuge.

Le plafond actuel de deux rappels surfacés par retour, les priorités et les cooldowns restent **candidats** jusqu'au playtest PC.

## Handoff Godot

Document dédié : `docs/VEILLEURS_REFUGE_MEMORY_GODOT_HANDOFF_V1.md`.

Deux classes candidates existent et sont testées par Godot, sans être autoloadées ni utilisées par le jeu actif :

- `VeilleursRefugeMemoryServiceCandidate` ;
- `VeilleursAuxiliaryReactionResolverCandidate`.

Le service mémoire est propriétaire uniquement de ses enregistrements et de leur planification. Il émet des demandes vers Archives/Rémanence mais ne modifie jamais directement connaissance, rang de Rémanence, recrutement, blessures ou valeurs d'équilibrage.

## Réactions croisées et auxiliaires individuels

`refuge_cross_reaction_matrix_v1.json` décrit les axes de réaction possibles des quatre Veilleurs pour les 12 familles du Refuge.

`auxiliary_individual_reaction_contract_v1.json` impose qu'un auxiliaire possède un `entity_id` stable et une preuve individuelle de participation, observation, histoire partagée ou conséquence directe. L'espèce n'est jamais utilisée comme personnalité.

Le résolveur candidat reçoit des listes d'IDs précises (`direct_participants`, `direct_observers`, `materially_affected_entities`, `shared_history_entities`) : un événement collectif ne rend donc pas tous les auxiliaires artificiellement concernés.

Aucune nouvelle réplique canonique n'est générée par ces systèmes.

## Actes II–V — événements et conséquences

- `regional_event_candidates_acts_ii_v_v1.json` : 16 événements candidats, 4 par acte II–V.
- `regional_event_choice_echoes_v1.json` : 32 conséquences différées, une par choix.
- `multi_act_consequence_chains_v1.json` : 8 chaînes candidates qui peuvent traverser plusieurs actes.

Une conséquence peut confirmer, compliquer ou réfuter une lecture antérieure. Le choix du joueur ne crée jamais la vérité du monde. Une chaîne multi-actes peut rester incomplète pour toujours sans bloquer la campagne ; elle ne donne aucun bonus caché et ne crée aucune Némésis pour satisfaire son scénario.

## Narration source-backed

`narrative_trigger_binding_v1.json` conserve l'autorité du référentiel maître : 68 barks canoniques, 30 dialogues de boss et 16 fragments de Rémanence II–V, sans réécriture ni spoiler de phase future.

## UX

- `ux_screen_flow_v1.json` : 6 écrans Refuge/Archives + 4 overlays, téléphone/tablette/PC/manette, cible tactile ≥48 pt, aucun long press/hover obligatoire.
- `ux_copy_fr_post_playtest_v1.json` : wording français candidat pour connaissance, intentions, anatomie, exploration, extraction, Refuge, Archives, Rémanence et groupe.

Aucun pourcentage de capture, aucune jauge permanente d'Espoir/Folie, aucune vérité ennemie omnisciente et aucun spoiler de boss futur.

## Télémétrie et diagnostic

- `playtest_telemetry_matrix_v1.json` : 33 événements structurés sans texte libre, donnée personnelle ni identifiant de compte.
- `playtest_diagnosis_matrix_v1.json` : observation → diagnostics possibles → modifications candidates → conclusion interdite.

Une seule session ne suffit jamais à modifier une règle fondamentale. Une seule famille de paramètres doit être changée à la fois après observations répétées/croisées.

## Altérations et Rémanence

`expedition_alteration_candidates_v2.json` contient 18 altérations candidates dans 6 familles : lumière, bruit, corps, environnement, connaissance et extraction. Elles restent temporaires, seed-reproductibles, lisibles et contre-jouables.

`remanence_nemesis_variants_v2.json` contient 16 adaptations issues uniquement de faits vécus. Aucune omniscience, aucun spawn artificiel de Némésis, aucun gonflement de PV et aucune guérison fictive des blessures.

## Invariants canoniques protégés

- Connaissance : `UNKNOWN → SUSPECTED → OBSERVED → CONFIRMED → UNDERSTOOD`.
- 0–5 = projection de détail UI uniquement.
- Connaissance ≠ monnaie.
- Capture ≠ recrutement/ralliement.
- Blessures persistantes après ralliement.
- Cinq boss non recrutables.
- Équipe max 4, au moins un Veilleur.
- Refuge I→V = 4 / 6 / 8 / 10 / 12.
- Maximum un ennemi Mémoriel par rencontre.
- Aucun Némésis artificiel.
- Aucun snapshot complet de scène.
- Aucune condition numérique inventée pour le ralliement de l'Acte I.

## Tests

Suites Python :

- `test_veilleurs_post_playtest_content_v1.py`
- `test_veilleurs_post_playtest_detail_v1.py`
- `test_veilleurs_post_playtest_chains_v1.py`
- `test_veilleurs_post_playtest_execution_v1.py`
- `test_veilleurs_post_playtest_handoff_v1.py`

Smokes Godot candidats :

- `veilleurs_refuge_memory_service_candidate_smoke.tscn`
- `veilleurs_auxiliary_reaction_resolver_candidate_smoke.tscn`

Les smokes compilent/exécutent le handoff sur la PR #180 mais aucune scène de jeu ne référence ces classes.

## Après le playtest PC

1. mesurer la fréquence acceptable des rappels ;
2. valider priorités et cooldowns ;
3. brancher le service mémoire derrière un feature flag ;
4. tester sauvegarde/migration sur copies de sauvegardes ;
5. brancher Archives puis Rémanence ;
6. brancher le résolveur auxiliaire ;
7. activer une seule famille d'événements ;
8. rejouer et comparer ;
9. seulement ensuite envisager événements régionaux et chaînes multi-actes.

La PR #180 ne doit pas être fusionnée avant ces validations.
