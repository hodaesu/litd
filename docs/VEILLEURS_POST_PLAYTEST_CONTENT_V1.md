# LITD : Les Veilleurs — contenu parallèle post-playtest v1

## But

Préparer les couches de contenu qui peuvent avancer sans PC **sans modifier la version destinée au playtest Windows**.

La référence de départ reste le commit `0c905800ec21e646e9252f1c14430ed8ad36ada3` de la PR #173. La PR #180 reste volontairement en brouillon, empilée sur `feature/veilleurs-content-foundation-v2`, désactivée par défaut et non câblée au runtime actif.

## Manifeste

`data/veilleurs/parallel_content/post_playtest_detail_manifest_v1.json`

Le manifeste v3 indexe désormais les événements du Refuge, leurs chaînes persistantes, les réactions croisées, les événements régionaux des actes II–V, la narration source-backed, les écrans UX, les textes UX français, la télémétrie, la matrice de diagnostic, les altérations et les variantes de Rémanence/Némésis.

## Refuge — 24 événements + 24 chaînes persistantes

`refuge_event_templates_v1.json`

Deux événements existent pour chacune des 12 familles canoniques : COHABITATION, CONFLIT, RAPPROCHEMENT, SOUVENIR, BESOIN_BIOLOGIQUE, BESOIN_PSYCHOLOGIQUE, TRANSFORMATION, TRAVAIL, DECOUVERTE, DEPART, CRISE et POLITIQUE.

`refuge_event_chains_v1.json`

Les 24 événements ne sont plus des scènes isolées : chacun possède une clé de mémoire et deux branches de rappel correspondant exactement aux deux choix de l'événement source. Les rappels sont exprimés en nombre d'expéditions : retour suivant, court, moyen ou long terme.

Un rappel ne peut survenir que si une histoire pertinente a réellement été écrite et qu'un état observable la réactive : même paire présente, route revisitée, blessure réactivée, auxiliaire toujours au Refuge, nouvelle crise, trace de Némésis, preuve contradictoire, etc.

Chaque branche peut écrire dans les Archives, l'histoire du Refuge, les relations, le corps, les routes ou la Rémanence. Elle ne crée jamais de vérité absolue, ne remet jamais une blessure persistante à zéro et ne rend jamais un boss recrutable.

## Réactions croisées — quatre Veilleurs + auxiliaires

`refuge_cross_reaction_matrix_v1.json`

Les 12 familles du Refuge possèdent désormais une matrice de réaction pour :

- Nayra Orun — sécurité, protection, formation, conséquences concrètes ;
- Tarek Senn — traces, répétitions, routes, faits observables ;
- Aïsha Maren — corps, preuve, stabilisation, incertitude ;
- Idris Vael — règles, responsabilité, participation, désaccord documenté.

Les auxiliaires ne reçoivent jamais une personnalité générique de leur espèce. Une réaction d'auxiliaire exige un contexte individuel : nouvelle recrue, ancien adversaire, survivant d'un événement partagé, blessé, spécialiste, témoin, auxiliaire sur le départ, etc.

Cette couche ne crée aucune nouvelle réplique canonique : elle définit qui peut réagir, sur quel fait et quelle mémoire peut être écrite.

## Actes II–V — 16 événements régionaux candidats

`regional_event_candidates_acts_ii_v_v1.json`

Quatre événements candidats sont préparés pour chacun des actes II, III, IV et V.

Ils s'appuient uniquement sur des éléments déjà établis : gestes et silence de l'Acte II, réseaux et croissance de l'Acte III, effacement et cendre pâle de l'Acte IV, copies et versions de l'Acte V. Chaque événement comporte deux choix contextuels et un rappel futur possible.

Ces événements restent explicitement non canoniques tant qu'ils n'ont pas été validés après playtest. Ils ne peuvent ni inventer une règle de ralliement, ni révéler une mécanique ennemie non observée, ni exposer une phase future de boss.

## Narration source-backed

`narrative_trigger_binding_v1.json`

Les textes du référentiel maître restent autoritaires. La branche couvre les 68 barks canoniques, les 30 dialogues de boss et les 16 fragments de Rémanence II–V sans réécriture de leur texte source.

## UX — écrans et texte français gelé

`ux_screen_flow_v1.json`

Six écrans Refuge/Archives et quatre overlays de combat restent définis pour téléphone, tablette, PC et manette, avec cible tactile ≥ 48 pt, aucun long press obligatoire, aucun hover obligatoire et confirmation explicite des actions irréversibles.

`ux_copy_fr_post_playtest_v1.json`

Le wording français est désormais gelé comme **candidat prêt à tester**. Il couvre les cinq états canoniques de connaissance, l'incertitude, les phases de boss, les intentions, le ciblage anatomique, les blessures persistantes, lumière/bruit, extraction, Refuge, ralliement, Archives, Rémanence et règles de groupe.

Il reste inactif tant que le playtest PC n'a pas validé la compréhension réelle des textes. Aucun pourcentage de capture, aucune jauge permanente d'Espoir/Folie, aucune vérité ennemie omnisciente et aucun spoiler de phase future n'y sont autorisés.

## Télémétrie — 33 événements structurés

`playtest_telemetry_matrix_v1.json`

La matrice couvre session, expédition, pièce, lumière, bruit, rencontre, décision de tour, action, ciblage, intention, corps, peur, portage, retraite/extraction, ralliement, Archives, Rémanence et Refuge.

Elle ne collecte ni texte libre, ni donnée personnelle, ni identifiant de compte.

## Diagnostic post-playtest

`playtest_diagnosis_matrix_v1.json`

La télémétrie est désormais reliée à une matrice « observation → diagnostic possible → modification candidate → conclusion interdite ».

Les cas couvrent notamment : décisions trop lentes ou trop rapides, annulations, consultation des intentions, ciblage anatomique, pression hémorragique, blessures persistantes, lumière, bruit, densité de rencontres, extraction trop tôt/trop tard, compréhension du ralliement et de la capacité du Refuge, événements qui semblent aléatoires, usage des Archives, mauvaise lecture de l'incertitude, télégraphes de boss, reconnaissance de la Rémanence/Némésis et friction tactile/manette.

Aucune modification active n'est produite automatiquement. Une seule session ne peut jamais justifier un changement d'une règle fondamentale ; il faut des observations répétées ou croisées entre seeds/builds, puis modifier une seule famille de paramètres à la fois.

## Altérations — 18 candidates

`expedition_alteration_candidates_v2.json`

Trois candidates existent pour chacune des six familles : lumière, bruit, corps, environnement, connaissance et extraction. Elles restent temporaires, reproductibles par seed, lisibles, contre-jouables et inactives avant validation.

## Rémanence / Némésis — 16 adaptations vécues

`remanence_nemesis_variants_v2.json`

Chaque adaptation exige une histoire réelle : survie, meurtre d'un Veilleur, mutilation, fuite/capture ratée, objet, retraite ou rencontres répétées. Elle conserve les blessures réelles, doit être télégraphiée et contre-jouable, ne lit jamais le build du joueur et ne transforme jamais une Némésis en sac à PV.

## Invariants canoniques protégés

- Connaissance : `UNKNOWN → SUSPECTED → OBSERVED → CONFIRMED → UNDERSTOOD`.
- Les niveaux 0–5 restent uniquement une projection de détail UI.
- La connaissance n'est pas une monnaie.
- Capture ≠ recrutement/ralliement.
- Les blessures ne sont pas remises à zéro au ralliement.
- Les cinq boss ne sont pas recrutables.
- Équipe : 4 maximum, au moins un Veilleur.
- Refuge : capacités I→V = 4 / 6 / 8 / 10 / 12.
- Une rencontre ne peut contenir qu'un ennemi Mémoriel au maximum.
- Un Némésis ne peut jamais apparaître artificiellement : il doit avoir une histoire partagée.
- Pas de snapshot complet de scène pour la Rémanence.
- Aucune condition numérique de ralliement n'est inventée pour l'Acte I.

## Tests et protection du playtest

Les suites :

- `tests/test_veilleurs_post_playtest_content_v1.py` ;
- `tests/test_veilleurs_post_playtest_detail_v1.py` ;
- `tests/test_veilleurs_post_playtest_chains_v1.py`.

La dernière vérifie notamment la couverture exacte des 24 événements par 24 chaînes, deux rappels correspondant aux deux choix de chaque événement, les 12 familles et les quatre Veilleurs dans la matrice de réactions croisées, 16 événements régionaux répartis 4/4/4/4, les cinq états de connaissance, la matrice de diagnostic et surtout l'absence de référence à ces fichiers dans les contrats actifs du playtest.

## Après le playtest PC

Les retours doivent d'abord être classés : lisibilité tactique, durée des combats, pression hémorragique, lumière/bruit, densité de rencontres, extraction, compréhension du ralliement, clarté des boss, utilité de l'anatomie, Rémanence et friction téléphone/manette/PC.

Ensuite seulement, la matrice de diagnostic permet de sélectionner une hypothèse, d'activer au maximum une famille de modifications, de rejouer avec build/seed enregistrés et de comparer le résultat. La PR #180 ne doit pas être fusionnée avant cette étape.
