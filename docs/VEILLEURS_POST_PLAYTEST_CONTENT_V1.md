# LITD : Les Veilleurs — contenu parallèle post-playtest v1

## But

Préparer les couches de contenu qui peuvent avancer sans PC **sans modifier la version destinée au playtest Windows**.

La référence de départ est le commit `0c905800ec21e646e9252f1c14430ed8ad36ada3` de la PR #173. Les ajouts de cette branche ne sont pas branchés au runtime actif et ne doivent pas être fusionnés dans la branche de playtest avant décision explicite après les retours de test.

La PR #180 reste volontairement en brouillon et empilée sur `feature/veilleurs-content-foundation-v2`.

## Couche générale

`data/veilleurs/parallel_content/post_playtest_content_v1.json`

Elle prépare huit chantiers : narration, actes II–V, altérations d’expédition, Archives, Refuge, Rémanence/Némésis, microtextes UX français et leviers d’équilibrage.

## Couche détaillée

`data/veilleurs/parallel_content/post_playtest_detail_manifest_v1.json`

Ce manifeste reste `enabled_by_default: false` et `runtime_wiring: none_until_explicit_post_playtest_decision`. Il référence six contrats détaillés.

### 1. Refuge — 24 événements candidats

`refuge_event_templates_v1.json`

Deux événements existent pour chacune des 12 familles canoniques :

- COHABITATION ;
- CONFLIT ;
- RAPPROCHEMENT ;
- SOUVENIR ;
- BESOIN_BIOLOGIQUE ;
- BESOIN_PSYCHOLOGIQUE ;
- TRANSFORMATION ;
- TRAVAIL ;
- DECOUVERTE ;
- DEPART ;
- CRISE ;
- POLITIQUE.

Chaque événement exige un état réellement vécu ou observable : expédition commune, retraite, blessure persistante, ralliement, cadavre ramené, panique vécue, transformation corporelle, promotion de Rémanence, découverte contradictoire, Refuge plein, etc.

Les choix écrivent des historiques, traces, règles de Refuge ou hooks de préparation. Les effets numériques relationnels restent volontairement indéfinis jusqu’au playtest. Un événement ne peut ni effacer une blessure persistante ni rendre un boss recrutable.

### 2. Narration — 68 barks, 30 dialogues de boss, 16 fragments de Rémanence

`narrative_trigger_binding_v1.json`

Les textes ne sont pas recopiés ni réécrits : les clés du référentiel maître restent autoritaires.

Les 68 barks sont couverts par :

- 12 déclencheurs génériques par Veilleur : `combat_start`, `ally_hurt`, `ally_critical`, `light_low`, `enemy_observed`, `retreat`, `corpse_ally`, `corpse_enemy`, `capture_ready`, `boss_phase`, `victory`, `camp` ;
- 5 entrées d’acte par Veilleur.

Les 30 dialogues de boss sont liés individuellement à leur clé source et à un événement runtime candidat : intro, réponse, entrée de phase, réponse de phase, victoire ou réponse de victoire. Une réplique liée à une phase ne peut être jouée qu’après l’entrée réelle dans cette phase ; aucune phase future n’est révélée.

Les 16 entrées de Rémanence des actes II–V sont liées aux espèces exactes. Les voies d’acquisition restent : observation, analyse de cadavre, puis coexistence/ralliement pour le fragment rare prévu par la source.

### 3. UX — six écrans + quatre overlays de combat

`ux_screen_flow_v1.json`

Écrans détaillés :

1. Refuge ;
2. Groupe actif ;
3. Recrues ;
4. Détail d’une recrue ;
5. Archives ;
6. Préparation d’expédition.

Overlays : détail d’intention, ciblage anatomique, confirmation d’extraction, delta des Archives.

Les profils téléphone, tablette, PC et manette sont explicités. Les invariants restent : cible tactile ≥ 48 pt, zone sûre mobile, aucun long press obligatoire, aucun hover obligatoire, cinq actions primaires maximum visibles sur téléphone, aucune information critique transmise par la couleur seule et validation des actions irréversibles.

### 4. Télémétrie — 33 événements structurés

`playtest_telemetry_matrix_v1.json`

La matrice couvre session, expédition, pièce, lumière, bruit, rencontre, décision de tour, sélection/annulation d’action, ciblage anatomique, lecture d’intention, états corporels, peur, portage, retraite/extraction, ralliement, Archives, Rémanence et Refuge.

Aucune donnée personnelle, aucun texte libre, aucune réplique et aucun identifiant de compte ne sont collectés par ce contrat candidat.

Les métriques dérivées permettent notamment de séparer :

- difficulté tactique et friction d’entrée ;
- incertitude volontaire et interface illisible ;
- pression des blessures et départ trop tardif ;
- utilité réelle du ciblage anatomique ;
- consultation des intentions et des Archives ;
- pression lumière/bruit ;
- compréhension du ralliement ;
- reconnaissance d’une entité Mémorielle ou Némésis.

### 5. Altérations — 18 candidates

`expedition_alteration_candidates_v2.json`

Trois altérations sont préparées pour chacune des six familles : lumière, bruit, corps, environnement, connaissance et extraction.

Toutes sont temporaires, reproductibles par seed, lisibles, contre-jouables et désactivées. Elles ne peuvent pas :

- devenir un bonus/malus permanent ;
- effacer une connaissance stockée ;
- créer un état sans victoire possible ;
- supprimer tout itinéraire/contre-jeu ;
- être activées avant validation du playtest.

### 6. Rémanence / Némésis — 16 adaptations vécues

`remanence_nemesis_variants_v2.json`

Les variantes exploitent les sources de promotion canoniques : survie, meurtre d’un Veilleur, mutilation, fuite/capture ratée, objet important, retraite forcée et rencontres répétées.

Chaque adaptation contient :

- un prérequis d’histoire ;
- un comportement candidat utilisant les capacités existantes de l’entité ;
- un télégraphe ;
- un contre-jeu ;
- une trace narrative destinée aux Archives/Traces.

Une Némésis reste rare, issue d’une histoire partagée saillante, conserve ses blessures réelles et ne lit jamais le build du joueur. Elle n’est jamais un simple multiplicateur de PV.

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
- Aucune condition numérique de ralliement n’est inventée pour l’Acte I.

## Protection du playtest

Le paquet général et le manifeste détaillé sont tous deux désactivés et non câblés au runtime.

`tests/test_veilleurs_post_playtest_content_v1.py` protège la première couche.

`tests/test_veilleurs_post_playtest_detail_v1.py` vérifie notamment :

- 24 événements / 12 familles du Refuge ;
- couverture exacte des déclencheurs des 68 barks ;
- liaison exacte des 30 clés de dialogues de boss ;
- liaison des 16 entrées de Rémanence II–V ;
- garde-fous UX mobile/PC/manette ;
- 33 événements de télémétrie sans texte libre ni donnée personnelle ;
- 18 altérations temporaires et contre-jouables ;
- 16 variantes de Rémanence fondées sur le vécu ;
- absence de référence à cette couche dans les contrats actifs du playtest.

## Après le playtest PC

Les retours sont à classer avant activation : lisibilité tactique, durée des combats, pression hémorragique, lumière/bruit, densité de rencontres, compréhension du ralliement, clarté des télégraphes de boss, utilité de l'anatomie et charge cognitive de l’interface.

Une modification d’équilibrage doit changer une seule famille de paramètres à la fois et conserver le build, la seed et l’état de partie nécessaires à la comparaison. Les nouvelles couches narratives ou de Rémanence doivent rester pilotées par les événements vécus et la connaissance acquise, jamais par une omniscience du système.
