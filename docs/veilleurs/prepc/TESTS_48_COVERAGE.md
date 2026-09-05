# LITD : Les Veilleurs — couverture canonique Tests_48

Date : 2026-09-05

Source canonique : onglet `Tests_48` de `LITD_Les_Veilleurs_Referentiel_Combat_Maitre_Narratif.xlsx`.
Fingerprint canonique `Tests_48` : `31bd5279fafc4ca5a40bb1646b60cac03d168f5d41dbad3dce5edb5ae875815f`.

## État de fermeture pré-PC

**48 / 48 scénarios canoniques = `PASS_HEADLESS`.**

Le head mécanique `e9b2a816617e41bf2885da5937a16ee65adfb7e6` a passé :

- la CI Godot stricte complète ;
- les tests Python et audits QA ;
- `Remanence Smoke` ;
- `Balance Telemetry`.

Les validations tactile, PC et appareil restent obligatoires lorsqu'elles apportent une preuve perceptive ou matérielle (ergonomie tactile, lisibilité, performances, rendu, ressenti d'équilibrage), mais elles **complètent** ces contrats mécaniques : elles ne remplacent pas les 48 preuves headless.

## Règles de traçabilité

- les IDs 1–48 ci-dessous correspondent aux scénarios du référentiel canonique ;
- un test utile mais absent de `Tests_48` reste nommé `SMOKE_SUPPLEMENTAL` et ne reçoit jamais un faux ID canonique ;
- `PASS_HEADLESS` signifie que le résultat attendu complet du scénario est couvert par une assertion automatisée exécutée par Godot ;
- aucune approximation documentaire ne doit re-numéroter ou redéfinir `Tests_48`.

| ID | Système | Scénario canonique | Résultat attendu canonique | Statut | Preuve headless |
|---:|---|---|---|---|---|
| 1 | Timeline | 4 Veilleurs + 4 ennemis | Chaque acteur obtient 1 action/cycle; réactions n’ajoutent pas de nouveau tour. | PASS_HEADLESS | `veilleurs_prepc_contract_smoke` |
| 2 | Timeline | Retard + avance simultanés | Résolution déterministe; aucun acteur dupliqué ou perdu. | PASS_HEADLESS | `veilleurs_prepc_contract_smoke` |
| 3 | Timeline | Boss multi-action | Actions boss visibles et séparées; pas d’action cachée gratuite. | PASS_HEADLESS | `veilleurs_prepc_contract_smoke` |
| 4 | Formation | Cadavre P1 | La compression ne traverse pas un corps bloquant sans règle de passage. | PASS_HEADLESS | `veilleurs_formation_contract_smoke` |
| 5 | Formation | Projection dans allié | Collision résolue puis positions valides; pas de superposition. | PASS_HEADLESS | `veilleurs_formation_contract_smoke` |
| 6 | Formation | 4 ennemis + boss occupant 2 rangs | Le générateur refuse une formation physiquement impossible. | PASS_HEADLESS | `veilleurs_formation_contract_smoke` |
| 7 | Anatomie | Membre hors fonction | Compétences exigeant cette fonction deviennent indisponibles, autres restent jouables. | PASS_HEADLESS | `veilleurs_physical_contract_smoke` |
| 8 | Anatomie | Construct contre Hémocorde | Pas de saignement/hémorragie; technique invalidée ou fortement réduite selon définition. | PASS_HEADLESS | `veilleurs_physical_contract_smoke` |
| 9 | Anatomie | Démembrement | N’arrive que si impact, zone, énergie et gravité sont compatibles. | PASS_HEADLESS | `veilleurs_physical_contract_smoke` |
| 10 | Armure | Pièce brisée | La zone devient exposée; l’armure ne continue pas à absorber à pleine valeur. | PASS_HEADLESS | `veilleurs_physical_contract_smoke` |
| 11 | Armure | Contondant sur plaque | Transmission de choc possible sans perforation. | PASS_HEADLESS | `veilleurs_physical_contract_smoke` |
| 12 | Blessures | Fracture persistante | Sauvegarde/rechargement conserve zone, gravité, traitement, séquelle. | PASS_HEADLESS | `veilleurs_physical_contract_smoke` |
| 13 | Blessures | Stabilisation | Stoppe aggravation sans guérir la lésion. | PASS_HEADLESS | `veilleurs_physical_contract_smoke` |
| 14 | Blessures | État critique + extraction | Un allié porteur peut quitter avec le blessé; pénalités appliquées. | PASS_HEADLESS | `veilleurs_physical_contract_smoke` |
| 15 | Cadavres | Mort puis revisit | Même CorpseState rechargé, pas de resimulation du ragdoll. | PASS_HEADLESS | `veilleurs_corpse_contract_smoke` |
| 16 | Cadavres | Brûler un corps | État persiste et interdit absorption/réanimation incompatibles. | PASS_HEADLESS | `veilleurs_corpse_contract_smoke` |
| 17 | Cadavres | Boss Mère absorbe corps | L’assimilation cible seulement cadavres admissibles et est télégraphiée. | PASS_HEADLESS | `veilleurs_corpse_contract_smoke` |
| 18 | Lumière | Source détruite | Informations deviennent moins précises, jamais fausse certitude arbitraire. | PASS_HEADLESS | `veilleurs_information_psychology_contract_smoke` |
| 19 | Lumière | Deux zones stables | Porte-Cendres phase 1 reconnaît correctement la condition. | PASS_HEADLESS | `veilleurs_information_psychology_contract_smoke` |
| 20 | Psychologie | Peur 100 | Rupture psychologique distincte de Folie; effets persistants cohérents. | PASS_HEADLESS | `veilleurs_information_psychology_contract_smoke` |
| 21 | Rémanence | Espèce inconnue | Intentions affichées qualitativement et connaissances progressent par preuves. | PASS_HEADLESS | `veilleurs_information_psychology_contract_smoke` |
| 22 | Rémanence | Espèce maîtrisée | Informations confirmées réapparaissent sur nouvelle expédition. | PASS_HEADLESS | `veilleurs_information_psychology_contract_smoke` |
| 23 | Capture | Condition non remplie | Bouton de capture indique pourquoi la cible n’est pas admissible. | PASS_HEADLESS | `veilleurs_capture_contract_smoke` |
| 24 | Capture | Échec de capture | Cible reste ennemie, résistance augmente, intention agressive actualisée. | PASS_HEADLESS | `veilleurs_capture_contract_smoke` |
| 25 | Capture | Réussite | Cible retirée proprement du combat et enregistrée comme auxiliaire; jamais ajoutée au quatuor. | PASS_HEADLESS | `veilleurs_capture_contract_smoke` |
| 26 | Rencontre | Budget menace | Aucun template généré au-dessus du budget sauf rencontre scriptée explicitement marquée. | PASS_HEADLESS | `veilleurs_encounter_contract_smoke` + 64 compositions canoniques |
| 27 | Rencontre | Max acteurs | Jamais plus de 4 acteurs ennemis standards. | PASS_HEADLESS | `veilleurs_encounter_contract_smoke` |
| 28 | Rencontre | Anti-répétition | Même template jamais 2 fois de suite. | PASS_HEADLESS | `veilleurs_encounter_contract_smoke` + historique 5 salles |
| 29 | Rencontre | Injection mémorielle | Maximum 1 ennemi mémoriel injecté par génération standard. | PASS_HEADLESS | `veilleurs_encounter_contract_smoke` |
| 30 | Rencontre | Némésis | N’apparaît que si une histoire partagée l’a créée. | PASS_HEADLESS | `veilleurs_encounter_contract_smoke` |
| 31 | Variantes | N20 | Même rig de base; stats/IA/visuel spécialisés chargés sans scène spécifique. | PASS_HEADLESS | `veilleurs_encounter_contract_smoke` |
| 32 | Variantes | N40 | Réactions avancées/forme experte sans casser les intentions mobiles. | PASS_HEADLESS | `veilleurs_encounter_contract_smoke` |
| 33 | IA | Cible blessée | Délié Affamé peut prioriser blessé mais respecte accessibilité réelle. | PASS_HEADLESS | `veilleurs_enemy_ai_contract_smoke` |
| 34 | IA | Porte-Signe mains hors fonction | Perd les capacités exigeant gestes, change de plan IA. | PASS_HEADLESS | `veilleurs_enemy_ai_contract_smoke` + `CombatPhysicalRules` |
| 35 | IA | Archiviste saturé | Quatre familles d’actions distinctes empêchent une réponse parfaite unique. | PASS_HEADLESS | `veilleurs_enemy_ai_contract_smoke` |
| 36 | Boss Ishar | Phase 1 | Transition exige vitalité + 2 méthodes de franchissement distinctes. | PASS_HEADLESS | `veilleurs_boss_contract_smoke` |
| 37 | Boss Ishar | Mémoire | Répéter action renforce contre; nouvelle famille contourne l’adaptation. | PASS_HEADLESS | `veilleurs_boss_contract_smoke` |
| 38 | Boss Orateur | Écho | Copie structure, pas asset/arme impossible; contexte peut la faire échouer. | PASS_HEADLESS | `veilleurs_boss_contract_smoke` |
| 39 | Boss Orateur | Silence | Actions individuelles restent utilisables; pas de désactivation totale de commandes. | PASS_HEADLESS | `veilleurs_boss_contract_smoke` |
| 40 | Boss Mère | Réseau | Dégâts redistribués seulement via connexions actives visibles. | PASS_HEADLESS | `veilleurs_boss_contract_smoke` |
| 41 | Boss Mère | Zones mortes | Coupures du réseau persistent entre phases. | PASS_HEADLESS | `veilleurs_boss_contract_smoke` |
| 42 | Boss Porte-Cendres | Effacement | Ne peut effacer blessure, mort, cadavre, porte détruite ou Rémanence ancrée. | PASS_HEADLESS | `veilleurs_boss_contract_smoke` |
| 43 | Boss Porte-Cendres | Procession | Route d’extraction se réduit de façon annoncée et peut être défendue. | PASS_HEADLESS | `veilleurs_boss_contract_smoke` |
| 44 | Boss Copiste | Copie | Copie les familles les plus récentes, pas les statistiques du joueur. | PASS_HEADLESS | `veilleurs_boss_contract_smoke` |
| 45 | Boss Copiste | Correction | Une correction par fenêtre; ne peut pas annuler plusieurs conséquences lourdes simultanément. | PASS_HEADLESS | `veilleurs_boss_contract_smoke` |
| 46 | Boss Copiste | Palimpseste | Deux versions cohérentes; lumière stabilise; aucune téléportation aléatoire. | PASS_HEADLESS | `veilleurs_boss_contract_smoke` |
| 47 | Boss Copiste | Finale | Synthèse choisit comportements observés; une nouvelle séquence doit pouvoir la battre. | PASS_HEADLESS | `veilleurs_boss_contract_smoke` |
| 48 | Sauvegarde | Checkpoint pré-boss | Seed, salle, blessures, cadavres, terrain, mémoriels et connaissances restent identiques. | PASS_HEADLESS | `veilleurs_preboss_checkpoint_smoke` : round-trip JSON profond + équivalence numérique JSON contrôlée |

## Données canoniques désormais branchées

Le bloc rencontres/variantes ne repose pas sur des fixtures inventées : les données du référentiel maître ont été intégrées sous forme exploitable par Godot :

- **64 compositions** canoniques issues de `Compositions_64` ;
- **25 règles acte × profondeur** de budget, élite, mémoriel et variantes ;
- variantes **N1 / N20 / N40** partageant le rig de famille ;
- maximum **4 acteurs ennemis standards** ;
- maximum **1 mémoriel** injecté en génération standard ;
- Némésis uniquement si une histoire partagée préexistante la rend légitime ;
- même template interdit deux fois de suite ; deux apparitions dans les cinq dernières salles appliquent le malus canonique de poids de 60 %.

## Smokes supplémentaires conservés

Ces tests restent utiles mais ne sont **pas** des IDs `Tests_48` :

- priorité simple par vitesse ;
- étourdissement consommant un créneau sans créer de nouveau tour ;
- capture d'une cible amputée conservant membre perdu, lésions, trauma et origine de Rémanence ;
- soins de convalescence sans repousse de membre ;
- deux témoins pouvant interpréter différemment le même événement ;
- ennemi survivant/fuyant laissant une mémoire ;
- mort immédiate n'entraînant pas d'évolution posthume ;
- adaptation ne recréant jamais un membre perdu ;
- corruption d'autosave avec restauration du backup valide.

## Handoff après fermeture mécanique

La fermeture pré-PC de `Tests_48` est terminée. L'ordre de validation suivant devient :

1. maintenir les **48/48 PASS_HEADLESS** sans régression pendant l'intégration au gameplay vivant ;
2. brancher progressivement ces contrats aux scènes finales, contenus et données de production ;
3. effectuer les playtests tactiles iPhone/iPad : taille des cibles, gestes, confirmations, lisibilité des intentions et confort ;
4. effectuer les playtests PC : clavier/souris/manette et UI PC dédiée ;
5. profiler CPU/GPU/RAM, temps de chargement, densité de cadavres, Rémanence et génération ;
6. valider animations, VFX, audio, lumière et rendu sur appareils réels ;
7. équilibrer le ressenti sans affaiblir les invariants mécaniques couverts ici.
