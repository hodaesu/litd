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

Les **64 rencontres** restent verrouillées par le référentiel maître dans `encounter_index_v1.json`. Leur projection runtime est maintenant découpée par acte :

- `encounters/encounters_act_1_v1.json` : 16 ;
- `encounters/encounters_act_2_v1.json` : 12 ;
- `encounters/encounters_act_3_v1.json` : 12 ;
- `encounters/encounters_act_4_v1.json` : 12 ;
- `encounters/encounters_act_5_v1.json` : 12.

`encounter_catalog_64_v1.json` relie ces cinq fichiers à la source `Compositions_64` verrouillée par SHA-256. Chaque entrée runtime reçoit un ID stable, les `species_ids`, les `synergy_ids`, le danger de terrain, la leçon tactique et les garde-fous Rémanence. Le maximum reste 4 acteurs ennemis et une Némésis n’est jamais créée artificiellement.

Les **21 synergies ennemies** restent définies sans nom artificiel dans `enemy_synergy_catalog_v1.json` : paire, force, fonctionnement, contre-jeu. `enemy_synergy_binding_v1.json` leur ajoute seulement un ID technique stable et les `species_ids`. Toute synergie reste visible et cassable ; son contre-jeu détaillé n’entre dans les Archives qu’après observation ou étude.

Le générateur hybride conserve : pas deux fois le même template consécutivement, fenêtre d’historique de cinq salles et poids ×0,4 après deux occurrences dans cette fenêtre. La Rémanence est projetée après le layout.

## Boss — canon actuel

1. **Ishar, Gardien du Passage** — 3 phases ;
2. **Orateur Sans Voix** — 3 phases ;
3. **Mère des Veines** — 3 phases ;
4. **Porte-Cendres Blanc** — 3 phases ;
5. **Le Copiste** — 4 phases.

Total : **16 phases**. `boss_phase_catalog_v1.json` reste la projection directe de la source maître. Les fichiers `bosses/*_phases_v1.json` ajoutent la couche de lecture tactique : mécanique, contre-jeu, arène, intentions, erreur punie, transition et six degrés d’affichage.

Important : les cinq états épistémiques canoniques restent :

`UNKNOWN → SUSPECTED → OBSERVED → CONFIRMED → UNDERSTOOD`

Les degrés 0–5 des intentions ne remplacent pas ce modèle. Ils constituent uniquement une **projection de détail de l’interface**. Ils ne sont pas une monnaie et ne rendent jamais l’interface omnisciente. `boss_phase_knowledge_v1.json` impose qu’une phase non vécue reste invisible.

Les cinq boss sont **non recrutables**.

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

Les Archives gardent cinq vues : Identité/Connaissance, Corps, Combat, Histoire, Traces.

Le pack apporte :

- 29 fiches narratives de bestiaire ;
- 16 jeux de fragments Rémanence Corps/Esprit/Politique pour les ennemis des Actes II–V ;
- acquisition canonique : observation en combat, analyse/cadavre, recrutement/coexistence ;
- usages : bestiaire avancé, interactions régionales, dialogues et bonus auxiliaires.

`archives_bestiary_29_v1.json` relie les 29 entrées de `bestiaire_narratif_29.json` aux IDs de production et à l’interface. La progression d’affichage est : première observation → comportement → corps → étude profonde/cadavre → sens/lore, tout en conservant les cinq états épistémiques de la source. Les informations inconnues restent explicitement inconnues.

La vue Combat incorpore les intentions et synergies réellement observées. Histoire et Traces sont alimentées par la Rémanence individuelle : rencontres, blessures, relations, cicatrices et adaptations réellement vécues. Les fiches des cinq boss n’exposent aucune action de recrutement et se complètent uniquement avec les phases déjà rencontrées.

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

Sources/projections directes :

- `content_foundation_v2.json`
- `species_catalog_recovered_v1.json`
- `canonical_bestiary_normalization_v2.json`
- `encounter_index_v1.json`
- `enemy_synergy_catalog_v1.json`
- `boss_phase_catalog_v1.json`
- `narrative_event_catalog_v1.json`

Bindings runtime ajoutés :

- `enemy_synergy_binding_v1.json`
- `encounter_catalog_64_v1.json`
- `encounters/encounters_act_1_v1.json` … `encounters_act_5_v1.json`
- `boss_phase_knowledge_v1.json`
- `bosses/ishar_i_phases_v1.json`
- `bosses/orateur_ii_phases_v1.json`
- `bosses/mere_iii_phases_v1.json`
- `bosses/porte_cendres_iv_phases_v1.json`
- `bosses/copiste_v_phases_v1.json`
- `archives_bestiary_29_v1.json`

Contrats liés :

- `recruitment_refuge_contract_v1.json`
- `refuge_runtime_contract_v1.json`
- `remanence_entity_contract_v1.json`
- `remanence_archive_runtime_contract_v1.json`
- `archives_refuge_ui_contract_v1.json`
- `narrative_continuity_contract_v1.json`

Tests :

- `tests/test_veilleurs_content_foundation_v2.py` protège la source canonique ;
- `tests/test_veilleurs_runtime_bindings_v1.py` protège les nouveaux bindings runtime et vérifie leur correspondance avec la source.

## Ce qui nécessite encore le PC / Godot

Le contenu de cette étape n’est plus le blocage principal. Restent à valider dans le runtime :

1. chargement réel des catalogues runtime ;
2. génération hybride des 64 rencontres et injection des cicatrices ;
3. activation/désactivation des 21 synergies pendant le combat ;
4. IntentResolver et lecture progressive des intentions ;
5. machine d’état capture → ralliement → Refuge ;
6. capacité progressive du Refuge et sauvegarde des recrues ;
7. événements de Refuge et relations ;
8. mise à jour dynamique des Archives par Rémanence ;
9. visibilité phase-scopée des 16 phases de boss ;
10. résolution des hooks de dialogues ;
11. navigation tactile/manette ;
12. tests Godot, Python, Remanence Smoke, Balance Telemetry et QA avant fusion.
