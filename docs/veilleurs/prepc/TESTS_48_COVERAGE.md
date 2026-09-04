# LITD : Les Veilleurs — couverture canonique Tests_48

Date : 2026-09-04

Source canonique : onglet `Tests_48` de `LITD_Les_Veilleurs_Referentiel_Combat_Maitre_Narratif.xlsx`.
Fingerprint canonique `Tests_48` : `31bd5279fafc4ca5a40bb1646b60cac03d168f5d41dbad3dce5edb5ae875815f`.

## Correction de dérive documentaire

Une première version de cette matrice avait résumé/re-numéroté des scénarios de travail comme s'ils étaient les 48 scénarios canoniques. Cette version est annulée.

Règle désormais verrouillée :

- les IDs 1–48 ci-dessous correspondent mot pour mot au référentiel canonique ;
- un test utile mais absent de `Tests_48` est nommé `SMOKE_SUPPLEMENTAL` et ne reçoit jamais un faux ID canonique ;
- aucun des 48 cas n'est classé comme intrinsèquement `DEVICE_REQUIRED` : le référentiel exige une automatisation Godot pour chacun, complétée ensuite par du playtest tactile quand pertinent.

## Statuts

- `PASS_HEADLESS` : le résultat attendu complet du scénario canonique est couvert par un test automatisé exact.
- `PARTIAL_HEADLESS` : une partie importante du scénario exact est automatisée, mais une assertion canonique manque encore.
- `COVERED_ADJACENT` : le système voisin est testé, mais le scénario canonique exact n'est pas encore verrouillé.
- `MECHANICAL_GAP_NO_PC` : runtime ou données manquants/incomplets ; doit être développé et testé headless avant handoff matériel.

| ID | Système | Scénario canonique | Résultat attendu canonique | Statut | Preuve / prochaine action |
|---:|---|---|---|---|---|
| 1 | Timeline | 4 Veilleurs + 4 ennemis | Chaque acteur obtient 1 action/cycle; réactions n’ajoutent pas de nouveau tour. | PASS_HEADLESS | `veilleurs_prepc_contract_smoke` : scheduler cyclique + réaction hors-tour |
| 2 | Timeline | Retard + avance simultanés | Résolution déterministe; aucun acteur dupliqué ou perdu. | PASS_HEADLESS | application atomique des shifts + test de stabilité de l'ordre et unicité des jetons |
| 3 | Timeline | Boss multi-action | Actions boss visibles et séparées; pas d’action cachée gratuite. | PASS_HEADLESS | jetons boss explicites `action_index`, visibles, réactions sans tour gratuit |
| 4 | Formation | Cadavre P1 | La compression ne traverse pas un corps bloquant sans règle de passage. | MECHANICAL_GAP_NO_PC | ajouter resolver de formation/cadavre bloquant |
| 5 | Formation | Projection dans allié | Collision résolue puis positions valides; pas de superposition. | MECHANICAL_GAP_NO_PC | ajouter résolution de poussée en chaîne / refus propre |
| 6 | Formation | 4 ennemis + boss occupant 2 rangs | Le générateur refuse une formation physiquement impossible. | MECHANICAL_GAP_NO_PC | ajouter empreinte de rang et validation de capacité P1–P4 |
| 7 | Anatomie | Membre hors fonction | Compétences exigeant cette fonction deviennent indisponibles, autres restent jouables. | COVERED_ADJACENT | anatomie sait perdre une partie ; relier exigences fonctionnelles des compétences |
| 8 | Anatomie | Construct contre Hémocorde | Pas de saignement/hémorragie; technique invalidée ou fortement réduite selon définition. | MECHANICAL_GAP_NO_PC | centraliser immunité physiologique / compatibilité de technique |
| 9 | Anatomie | Démembrement | N’arrive que si impact, zone, énergie et gravité sont compatibles. | COVERED_ADJACENT | runtime de démembrement existe ; test exact multi-conditions à ajouter |
| 10 | Armure | Pièce brisée | La zone devient exposée; l’armure ne continue pas à absorber à pleine valeur. | MECHANICAL_GAP_NO_PC | brancher durabilité/localisation de protection |
| 11 | Armure | Contondant sur plaque | Transmission de choc possible sans perforation. | MECHANICAL_GAP_NO_PC | ajouter séparation perforation / trauma transmis |
| 12 | Blessures | Fracture persistante | Sauvegarde/rechargement conserve zone, gravité, traitement, séquelle. | COVERED_ADJACENT | blessures persistantes et SaveManager existent ; round-trip exact fracture à ajouter |
| 13 | Blessures | Stabilisation | Stoppe aggravation sans guérir la lésion. | COVERED_ADJACENT | soins/stabilisation existent dans systèmes voisins ; contrat exact à ajouter |
| 14 | Blessures | État critique + extraction | Un allié porteur peut quitter avec le blessé; pénalités appliquées. | MECHANICAL_GAP_NO_PC | portage/extraction fonctionnelle à implémenter |
| 15 | Cadavres | Mort puis revisit | Même CorpseState rechargé, pas de resimulation du ragdoll. | COVERED_ADJACENT | Rémanence/cadavres sérialisés ; assertion CorpseState identique à ajouter |
| 16 | Cadavres | Brûler un corps | État persiste et interdit absorption/réanimation incompatibles. | MECHANICAL_GAP_NO_PC | ajouter état brûlé + règles d'admissibilité persistantes |
| 17 | Cadavres | Boss Mère absorbe corps | L’assimilation cible seulement cadavres admissibles et est télégraphiée. | MECHANICAL_GAP_NO_PC | dépend runtime Mère des Veines + filtre cadavres |
| 18 | Lumière | Source détruite | Informations deviennent moins précises, jamais fausse certitude arbitraire. | COVERED_ADJACENT | lumière/information existent ; contrat de dégradation épistémique exact à ajouter |
| 19 | Lumière | Deux zones stables | Porte-Cendres phase 1 reconnaît correctement la condition. | MECHANICAL_GAP_NO_PC | dépend runtime Porte-Cendres + lecture zones stables |
| 20 | Psychologie | Peur 100 | Rupture psychologique distincte de Folie; effets persistants cohérents. | COVERED_ADJACENT | `psychology_smoke` couvre Peur/Folie ; assertion exacte seuil 100 + persistance à ajouter |
| 21 | Rémanence | Espèce inconnue | Intentions affichées qualitativement et connaissances progressent par preuves. | COVERED_ADJACENT | intentions qualitatives et Rémanence existent ; progression de connaissance exacte à lier |
| 22 | Rémanence | Espèce maîtrisée | Informations confirmées réapparaissent sur nouvelle expédition. | COVERED_ADJACENT | persistance Rémanence existe ; round-trip bestiaire maîtrisé à ajouter |
| 23 | Capture | Condition non remplie | Bouton de capture indique pourquoi la cible n’est pas admissible. | COVERED_ADJACENT | `capture_readiness` existe ; UI/reason code exact à verrouiller |
| 24 | Capture | Échec de capture | Cible reste ennemie, résistance augmente, intention agressive actualisée. | PARTIAL_HEADLESS | résistance mémorisée testée ; ajouter assertions cible toujours hostile + intention actualisée |
| 25 | Capture | Réussite | Cible retirée proprement du combat et enregistrée comme auxiliaire; jamais ajoutée au quatuor. | COVERED_ADJACENT | capture/ralliement existent ; test exact retrait + auxiliaire hors quatuor à ajouter |
| 26 | Rencontre | Budget menace | Aucun template généré au-dessus du budget sauf rencontre scriptée explicitement marquée. | MECHANICAL_GAP_NO_PC | intégrer/brancher budget de menace du pack canonique |
| 27 | Rencontre | Max acteurs | Jamais plus de 4 acteurs ennemis standards. | MECHANICAL_GAP_NO_PC | ajouter contrat de capacité au générateur de rencontres |
| 28 | Rencontre | Anti-répétition | Même template jamais 2 fois de suite. | COVERED_ADJACENT | anti-répétition intra-layout existe ; historique inter-rencontres à brancher |
| 29 | Rencontre | Injection mémorielle | Maximum 1 ennemi mémoriel injecté par génération standard. | MECHANICAL_GAP_NO_PC | brancher injection mémorielle bornée |
| 30 | Rencontre | Némésis | N’apparaît que si une histoire partagée l’a créée. | COVERED_ADJACENT | Rémanence/némésis existent ; verrou d'éligibilité générateur à ajouter |
| 31 | Variantes | N20 | Même rig de base; stats/IA/visuel spécialisés chargés sans scène spécifique. | MECHANICAL_GAP_NO_PC | intégrer données variantes + contrat de ressource/rig partagé |
| 32 | Variantes | N40 | Réactions avancées/forme experte sans casser les intentions mobiles. | MECHANICAL_GAP_NO_PC | intégrer variante experte + intentions bornées |
| 33 | IA | Cible blessée | Délié Affamé peut prioriser blessé mais respecte accessibilité réelle. | COVERED_ADJACENT | ciblage `weakest` existe ; accessibilité réelle manque au contrat |
| 34 | IA | Porte-Signe mains hors fonction | Perd les capacités exigeant gestes, change de plan IA. | MECHANICAL_GAP_NO_PC | lier anatomie fonctionnelle aux exigences de compétences IA |
| 35 | IA | Archiviste saturé | Quatre familles d’actions distinctes empêchent une réponse parfaite unique. | MECHANICAL_GAP_NO_PC | intégrer profil Archiviste + diversité minimale des familles |
| 36 | Boss Ishar | Phase 1 | Transition exige vitalité + 2 méthodes de franchissement distinctes. | MECHANICAL_GAP_NO_PC | intégrer `boss_phases` / contrôleur Ishar canonique |
| 37 | Boss Ishar | Mémoire | Répéter action renforce contre; nouvelle famille contourne l’adaptation. | MECHANICAL_GAP_NO_PC | brancher mémoire tactique du boss et familles d'action |
| 38 | Boss Orateur | Écho | Copie structure, pas asset/arme impossible; contexte peut la faire échouer. | MECHANICAL_GAP_NO_PC | runtime Orateur à intégrer |
| 39 | Boss Orateur | Silence | Actions individuelles restent utilisables; pas de désactivation totale de commandes. | MECHANICAL_GAP_NO_PC | runtime Silence à intégrer avec garde-fou UI/commandes |
| 40 | Boss Mère | Réseau | Dégâts redistribués seulement via connexions actives visibles. | MECHANICAL_GAP_NO_PC | runtime réseau Mère des Veines à intégrer |
| 41 | Boss Mère | Zones mortes | Coupures du réseau persistent entre phases. | MECHANICAL_GAP_NO_PC | persistance inter-phases du réseau à intégrer |
| 42 | Boss Porte-Cendres | Effacement | Ne peut effacer blessure, mort, cadavre, porte détruite ou Rémanence ancrée. | MECHANICAL_GAP_NO_PC | intégrer Effacement + liste d'états irréversibles |
| 43 | Boss Porte-Cendres | Procession | Route d’extraction se réduit de façon annoncée et peut être défendue. | MECHANICAL_GAP_NO_PC | intégrer route d'extraction télégraphiée/défendable |
| 44 | Boss Copiste | Copie | Copie les familles les plus récentes, pas les statistiques du joueur. | MECHANICAL_GAP_NO_PC | intégrer copie structurelle bornée |
| 45 | Boss Copiste | Correction | Une correction par fenêtre; ne peut pas annuler plusieurs conséquences lourdes simultanément. | MECHANICAL_GAP_NO_PC | intégrer budget/fenêtre de Correction |
| 46 | Boss Copiste | Palimpseste | Deux versions cohérentes; lumière stabilise; aucune téléportation aléatoire. | MECHANICAL_GAP_NO_PC | intégrer états de version cohérents + ancrage lumière |
| 47 | Boss Copiste | Finale | Synthèse choisit comportements observés; une nouvelle séquence doit pouvoir la battre. | MECHANICAL_GAP_NO_PC | intégrer synthèse adaptative avec ouverture anti-lock |
| 48 | Sauvegarde | Checkpoint pré-boss | Seed, salle, blessures, cadavres, terrain, mémoriels et connaissances restent identiques. | COVERED_ADJACENT | SaveManager sérialise plusieurs briques ; snapshot complet pré-boss exact à ajouter |

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

## Ordre de travail pré-PC corrigé

1. fermer G01 canonique : fait pour T01–T03 ;
2. formation T04–T06 ;
3. anatomie/armure/blessures T07–T14 ;
4. cadavres/lumière/psychologie/Rémanence T15–T22 ;
5. capture T23–T25 ;
6. générateur de rencontres/variantes T26–T32 ;
7. IA T33–T35 ;
8. boss T36–T47 ;
9. checkpoint complet T48 ;
10. playtests tactile/PC et profiling en complément des preuves headless.
