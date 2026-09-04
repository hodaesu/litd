# LITD : Les Veilleurs — couverture Tests_48

Date : 2026-09-04

Statuts :

- `PASS_HEADLESS` : contrat exact couvert par un smoke automatisé.
- `COVERED_ADJACENT` : système voisin testé, mais le scénario exact doit encore être ajouté.
- `MECHANICAL_GAP_NO_PC` : runtime manquant ou incomplet ; peut et doit être développé/testé sans attendre un PC de production.
- `DEVICE_REQUIRED` : validation finale qui dépend réellement d'un appareil, du rendu ou d'un jugement ergonomique humain.

| # | Gate | Contrat | Statut actuel | Preuve / prochaine action |
|---:|---|---|---|---|
| 1 | G01 | Vitesse très différente → rapide avant lent | PASS_HEADLESS | `veilleurs_prepc_contract_smoke` |
| 2 | G01 | Étourdi juste avant le tour → action sautée + récupération | MECHANICAL_GAP_NO_PC | timeline actuelle ne possède pas encore de scheduler de statut/tour |
| 3 | G01 | Ralenti → délai de prochaine action plus long | MECHANICAL_GAP_NO_PC | timeline actuelle trie l'initiative mais ne planifie pas le délai suivant |
| 4 | G01 | Rapide répété → jamais de verrou infini | MECHANICAL_GAP_NO_PC | nécessite timeline continue avec garde anti-lock |
| 5 | G02 | Retraite P4 → permutation cohérente | MECHANICAL_GAP_NO_PC | règles de positions existent, moteur de permutation à créer |
| 6 | G02 | Poussée P1 → glissement voisin valide | MECHANICAL_GAP_NO_PC | moteur de déplacement de formation à créer |
| 7 | G02 | Large + 3 Medium → occupation respectée | MECHANICAL_GAP_NO_PC | modèle de taille/occupation à créer |
| 8 | G02 | Large impossible → refus propre | MECHANICAL_GAP_NO_PC | idem G02 |
| 9 | G03 | Bras détruit → compétence 2 bras indisponible | COVERED_ADJACENT | anatomie sait perdre une partie ; prérequis corporels des compétences à relier explicitement |
| 10 | G03 | Jambe perdue → mobilité recalculée | PASS_HEADLESS | `body_state_smoke` valide `limp_walk`; Rémanence conserve la perte |
| 11 | G03 | Main blessée → arme 2 mains pénalisée/indisponible | MECHANICAL_GAP_NO_PC | loadout actuel couvre consommables, pas prérequis biomécaniques d'armes |
| 12 | G03 | Œil détruit → précision visée change sans fuite d'info | COVERED_ADJACENT | anatomie/senseurs existent ; assertion précision ciblée à ajouter |
| 13 | G04 | Coup tête + armure torse → torse n'absorbe pas | MECHANICAL_GAP_NO_PC | couverture d'armure localisée non trouvée dans runtime actuel |
| 14 | G04 | Durabilité 0 → protection réduite | MECHANICAL_GAP_NO_PC | modèle de durabilité d'armure à brancher |
| 15 | G04 | Contrôle vs forte résistance → chance/cap cohérents | COVERED_ADJACENT | résistances existent dans plusieurs systèmes ; contrat générique à centraliser |
| 16 | G04 | Ancienne plaie protégée → exposition réduite, jamais immunité | PASS_HEADLESS | `remanence_smoke` + adaptation `guard_old_wound` |
| 17 | G05 | Entend sans voir → enquête position estimée | MECHANICAL_GAP_NO_PC | `EnemyCombatDirector` combat n'implémente pas encore perception sensorielle spatiale |
| 18 | G05 | Signal ancien → confiance diminue | MECHANICAL_GAP_NO_PC | modèle de croyance/confidence spatial à créer |
| 19 | G05 | Diversion deux sources → choix crédible non omniscient | MECHANICAL_GAP_NO_PC | idem G05 |
| 20 | G05 | Vieille mémoire/changement zone → ancienne info peut devenir fausse | MECHANICAL_GAP_NO_PC | mémoire existe, croyance spatiale versionnée manque |
| 21 | G06 | Cible paniquée → approche adaptée améliore issue | COVERED_ADJACENT | VS001 S6 teste peur/confiance et actions de désescalade ; effet exact de probabilité à verrouiller |
| 22 | G06 | Cible amputée → recrue garde membre perdu | PASS_HEADLESS | nouveau transfert automatique `CaptureWoundRuntime` + smoke |
| 23 | G06 | Compagnie 4/4 → pas de 5e slot, autre destin possible | MECHANICAL_GAP_NO_PC | Refuge Veilleurs 4 places pas encore implémenté comme runtime dédié |
| 24 | G06 | Échecs répétés de sceau → résistance mémorisée | PASS_HEADLESS | `capture_escaped` → `seal_resistance` + smoke exact |
| 25 | G07 | Veilleur mort définitivement → roster actif réduit | COVERED_ADJACENT | cadavre/mort testés ; roster Veilleurs permanent exact à ajouter |
| 26 | G07 | Save/load → même corpse ID + lésions | PASS_HEADLESS | `remanence_smoke` sérialise identité/corps et cadavre persistant |
| 27 | G07 | Retour sur corps transformé → identité conservée | PASS_HEADLESS | vieillissement + visites + Grande Rémanence conservent l'origine |
| 28 | G07 | Zone saturée → archivage/merge sans perte essentielle | PASS_HEADLESS | caps Rémanence + `archived_scars` testés |
| 29 | G08 | Deux témoins d'un même événement → croyances différentes | PASS_HEADLESS | nouveau smoke convictions opposées |
| 30 | G08 | Admiration vs confiance → secours désobéissant change axes différemment | COVERED_ADJACENT | `relationship_smoke` prouve axes séparés ; événement exact à ajouter |
| 31 | G08 | Blessure sévère/événement extrême → Trace possible et persistante | COVERED_ADJACENT | psychologie persistante testée ; corpus des 60 Traces pas encore importé comme moteur dédié |
| 32 | G08 | Trace latente + faible surcharge après repos → peut se résoudre | MECHANICAL_GAP_NO_PC | cycle de vie exact des Traces canoniques à implémenter |
| 33 | G09 | Survie/fuite → preuve de mémoire | PASS_HEADLESS | nouveau smoke événementiel |
| 34 | G09 | Mort immédiate → pas d'évolution posthume | PASS_HEADLESS | nouveau smoke via `RemanenceCombatBridge` |
| 35 | G09 | Stratégie répétée sur 3 rencontres → contre-mesure possible | COVERED_ADJACENT | adaptations événementielles existent ; répétition tactique générique à instrumenter |
| 36 | G09 | Membre perdu → adaptation ne le recrée jamais | PASS_HEADLESS | nouveau smoke exact |
| 37 | G10 | Autel profané ZoneScar → seed+scar reconstruit état | PASS_HEADLESS | `remanence_smoke` attache/reconstruit les cicatrices sur plan hybride |
| 38 | G10 | Raccourci persistant reste ouvert | COVERED_ADJACENT | type `opened_shortcut` existe ; scénario exact de route à ajouter |
| 39 | G11 | Refuge 4 places + 5e → attente/départ/remplacement par choix | MECHANICAL_GAP_NO_PC | Refuge Veilleurs dédié à implémenter |
| 40 | G11 | Besoin faim/peur ignoré → mémoire/risque de départ augmente | MECHANICAL_GAP_NO_PC | besoins/résidents du Refuge Veilleurs à implémenter |
| 41 | G12 | 1000 runs : difficulté moyenne augmente avec profondeur | MECHANICAL_GAP_NO_PC | générateur hybride actuel choisit salles, pas encore budgets d'ennemis mesurables par profondeur |
| 42 | G12 | Longue série → anti-répétition visible | COVERED_ADJACENT | le générateur interdit déjà la répétition d'un template dans un layout ; historique inter-runs à ajouter |
| 43 | G12 | Aucun counter-pick direct du loadout joueur | COVERED_ADJACENT | générateur actuel ne lit pas le loadout ; audit statique/contract test à ajouter |
| 44 | G13 | Action tactile fréquente → 1–2 interactions max | DEVICE_REQUIRED | structure automatisable, mais confort final doit être validé sur appareil réel |
| 45 | G13 | Inspection anatomique lisible sans microtexte | DEVICE_REQUIRED | CI vérifie tailles/bords ; lisibilité réelle nécessite appareil humain |
| 46 | G13 | Interruption/autosave → reprise cohérente | PASS_HEADLESS | nouveau smoke corrompt l'autosave courant et exige restauration du `.bak` valide |
| 47 | G14 | Ishar phase 2 → télégraphe + fenêtre de réponse | MECHANICAL_GAP_NO_PC | Ishar n'est pas encore présent dans le runtime du dépôt actuel |
| 48 | G14 | Pattern appris + variation contextuelle | MECHANICAL_GAP_NO_PC | dépend du runtime Ishar/IA de boss à implémenter |

## Résultat de tri

Le PC n'est **pas** le blocage des scénarios mécaniques. Les statuts `MECHANICAL_GAP_NO_PC` restent des tâches de code/data/Godot headless et doivent être poursuivis avant le handoff matériel.

Les seuls cas intrinsèquement `DEVICE_REQUIRED` dans cette matrice sont actuellement T44 et T45. Le profiling CPU/GPU/RAM/FPS, la qualité du rendu, les animations finales et le confort tactile prolongé restent également des validations matérielles extérieures à `Tests_48`.
