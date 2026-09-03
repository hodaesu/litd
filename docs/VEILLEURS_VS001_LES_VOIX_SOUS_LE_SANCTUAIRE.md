# LITD : Les Veilleurs — VS001 « Les Voix sous le Sanctuaire »

## Statut

Contrat de vertical slice **pré-implémenté et exécutable côté logique**, prêt pour l’intégration des scènes jouables. Le but de VS001 est de démontrer en une expédition courte le noyau de **LITD : Les Veilleurs** : exploration, combat anatomique, lumière/bruit, cadavres persistants, Rémanence, recrutement ennemi, choix d’extraction et interface mobile/PC commune au niveau des règles.

Seed de développement : `WATCHERS_VERTICAL_001`.

## Quatuor

- **Nayra Orun — La Garde** : Garde/Bastion, protection, force et contrôle.
- **Tarek Senn — Le Pisteur** : Traque, perception, pièges, mobilité et poursuite.
- **Aïsha Maren — L’Anatomiste** : Diagnostic/Suture, anatomie, soins et lecture des corps.
- **Idris Vael — Le Médiateur** : Autorité/Concorde, coordination, peur et désescalade.

Les valeurs numériques et affinités sont définies dans `data/veilleurs/vs001_balance.json`.

## Carte de référence

```text
                       [S8]
                        |
Entrée — S1 — S2 — S3 — S5 — S7
              |         |
              S4        S6
```

- S1 : Vestibule effondré — observation/fresque.
- S2 : Galerie des cordes — piège/bruit.
- S3 : Salle des dormeurs — premier combat/cadavres.
- S4 : Réserve oubliée — ressources/Vasque noire, facultative.
- S5 : Crypte fracturée — enquête/cadavre de l’éclaireur.
- S6 : Le Survivant — recrutement d’une Goule blessée, facultative.
- S7 : Chambre des Voix — combat objectif/dispositif acoustique.
- S8 : Archive sous la Chambre — secret/lore, uniquement après étude du dispositif.

Le fallback exact est `data/dungeons/voices_under_sanctuary_map.json`. La version procédurale hybride doit préserver les rôles, l’ordre protégé et les invariants, pas forcément les coordonnées.

## Architecture existante réutilisée

VS001 s’appuie sur les systèmes centraux du dépôt :

- `ExpeditionManager` pour l’état général d’expédition et la sauvegarde globale ;
- `ExplorationDirector` pour les systèmes génériques de perception, pièges, patrouilles, bruit/lumière et états de salle ;
- `HUDDirector`/`ContextHUD` pour la divulgation contextuelle et les confirmations ;
- contrats globaux d’anatomie/blessures/capture existants pour éviter une seconde logique parallèle.

Aucun système VS001 ne doit dupliquer une règle globale lorsqu’une règle globale existe déjà. Les fichiers VS001 adaptent des valeurs et ajoutent du contenu tout en conservant les contrats centraux.

## Couche logique VS001 exécutable

Deux runtimes Godot purs existent désormais :

- `scripts/core/veilleurs_vs001_runtime.gd` : calculs de recrutement, lumière, bruit, événements, loot de référence et profils de Goules ;
- `scripts/core/veilleurs_vs001_session_runtime.gd` : état d’une expédition VS001, navigation S1–S8, Pulse, piège S2, combat abstrait, interaction/recrutement S6, dispositif S7, accès S8, loot, extraction et sérialisation.

Le smoke `scenes/tests/veilleurs_vs001_smoke.tscn` vérifie :

1. les bandes de probabilité provisoires du recrutement ;
2. les coûts lumière/bruit ;
3. les invariants relatifs Affamée/Éclaireuse/Vorace ;
4. les 67 or de la seed de référence ;
5. le parcours logique S1 → S2 → S3 → S5 → S6 → S5 → S7 → S8 ;
6. le désamorçage du piège ;
7. le recrutement prudent ;
8. l’étude du dispositif ;
9. l’ouverture conditionnelle de S8 ;
10. la sérialisation puis restauration de la session ;
11. l’extraction avec conservation des états S6/S7/S8.

Ce smoke est branché dans `tools/build/run_godot_ci.sh` et doit passer sous l’import Godot strict.

## Données VS001

### Donjon

- `data/dungeons/voices_under_sanctuary_hybrid_config.json`
- `data/dungeons/voices_under_sanctuary_map.json`
- `data/dungeons/voices_under_sanctuary_module_library.json`
- `data/dungeons/voices_under_sanctuary_remanence_anchors.json`
- `data/dungeons/voices_under_sanctuary_encounters.json`

### Gameplay

- `data/veilleurs/vs001_balance.json`
- `data/veilleurs/vs001_events.json`
- `data/veilleurs/vs001_dialogues.json`
- `data/veilleurs/vs001_ui_input_contract.json`
- `data/veilleurs/vs001_playtest_guardrails.json`
- `data/veilleurs/vs001_telemetry_contract.json`

### QA et équilibrage

- `tools/qa/veilleurs_vs001_audit.py`
- `tools/qa/veilleurs_vs001_balance_sim.py`
- `tests/test_veilleurs_vs001_data.py`
- `tests/test_veilleurs_vs001_balance_sim.py`
- `docs/VEILLEURS_VS001_QA_MATRIX.md`
- `docs/VEILLEURS_VS001_PLAYTEST_PROTOCOL.md`

## Exploration Pulse

Le Pulse est une horloge abstraite invisible. Un déplacement de corridor, une fouille, un traitement ou une interaction profonde peut consommer un ou plusieurs Pulses. Ouvrir la carte, consulter l’inventaire ou regarder brièvement ne consomme rien.

Ordre de résolution cible :

```text
player_action
→ light_update
→ noise_update
→ injury_update
→ enemy_movement
→ environment_update
→ event_check
→ remanence_check
→ save_state
```

Le RNG des événements et interactions répétables est dérivé de la seed et de l’état d’expédition afin d’empêcher le reroll par rechargement.

## Lumière

Échelle interne : 0–100. Départ VS001 : 82.

- 76–100 Claire
- 51–75 Stable
- 26–50 Faible
- 1–25 Critique
- 0 Obscurité

La faible lumière n’est pas un simple malus : elle peut améliorer la discrétion tout en dégradant perception et résistance aux embuscades.

Les valeurs sont une **baseline provisoire**. Le simulateur synthétique vérifie qu’elles ne deviennent pas manifestement incohérentes ; le playtest humain décide du réglage final.

## Bruit

Échelle : 0–100. Le bruit se propage le long des connexions avec atténuation par corridor/porte/mur et absorption des salles. Il redescend durant les Pulses calmes.

Paliers de réaction ennemie entendue :

- ≥20 : enquêter ;
- ≥40 : alerte ;
- ≥60 : préparation d’embuscade ;
- ≥80 : position approximative probable.

Même à 100, l’IA ne reçoit jamais gratuitement toute la carte ou l’état exact du groupe.

## Goules

VS001 réutilise `hungry_ghoul` comme identité de créature globale.

- **Goule affamée** : profil standard niveau 1.
- **Goule éclaireuse** : profil tactique de Goule affamée, pas nouvelle espèce ni nouvelle évolution.
- **Goule vorace** : évolution globale niveau 5 déjà prévue.

Le simulateur protège les différences structurelles entre les trois profils sans prétendre mesurer le plaisir ou la lisibilité du combat.

## Cadavres

Les cadavres produits dans S3/S7 restent. Les Goules peuvent s’en nourrir ou les déplacer. Les changements persistants doivent être enregistrés comme cicatrices d’ancrage + flags/history, jamais comme snapshots complets de scène.

## Anatomie et blessures

VS001 conserve la séparation :

- dégâts de PV ;
- trauma local par partie du corps ;
- saignement ;
- fracture ;
- conséquence fonctionnelle ;
- persistance après extraction.

Un échec de ciblage anatomique ne supprime pas les dégâts normaux : il réduit le trauma local. Les modes gore complet/réduit/off changent uniquement la présentation.

## Recrutement S6

La Goule de S6 commence grièvement blessée, craintive et défensive. La rencontre n’est pas un combat automatique.

Voies principales : observer, réduire la menace, diagnostiquer/soigner, désamorcer la peur, offrir une ressource, maîtriser, partir ou tuer.

Les actions des quatre Veilleurs ont des conséquences distinctes. Une approche douce augmente confiance/stabilité ; bloquer physiquement la sortie augmente la contrainte mais aussi la peur ; soigner crée un avantage relationnel important ; la force directe est possible mais moins fiable et laisse un historique différent.

La baseline a été corrigée après calcul exact : l’ancienne formule rendait la maîtrise immédiate pratiquement impossible malgré une cible de design de 20–45 %. La formule provisoire maintient désormais l’approche prudente dans la bande 70–90 % et la force immédiate dans 20–45 %, avec l’approche prudente nettement supérieure. Ces bandes restent à confirmer humainement.

Le recrutement reste bloqué si :

- `Manifestation destructrice` interdit la capture ;
- quota régional atteint ;
- capacité du Sanctuaire atteinte.

Après réussite, la créature conserve ses blessures et son historique. Elle reste indisponible au combat jusqu’à la fin des soins conformément au contrat global de capture.

## S7 : choix final local

Après le combat :

- **Détruire** : rend le dispositif inopérant, ne donne pas accès à S8.
- **Désactiver** : préserve le dispositif mais ne donne pas accès à S8.
- **Étudier** : coûte du temps et présente un risque ; en cas de réussite, révèle S8.

Ces trois choix valident l’objectif principal. S8 n’est jamais nécessaire.

## Rémanence

VS001 crée au minimum :

- connaissance d’une structure potentiellement antérieure au Sanctuaire ;
- réaction de la Vasque noire avec l’eau si testée ;
- compréhension du dispositif acoustique ;
- fragment des Trois Voies avant leur nomination si S8 est découvert ;
- historique du recrutement/mort/fuite de la Goule S6 ;
- états persistants du piège et des cadavres.

La Rémanence conserve aussi l’incertitude : une hypothèse peut rester faible ou être révisée plus tard.

## Mobile, tablette, PC, manette

Le gameplay et les sauvegardes restent identiques. Le contrat d’interface se trouve dans `vs001_ui_input_contract.json`.

Règle fondamentale :

> demander une information ne doit jamais déclencher une action irréversible.

Mobile : tap intention → tap cible ; swipe pour listes ; drag uniquement quand la manipulation d’objet est naturelle ; aucun appui long requis.

Tablette : même grammaire tactile avec panneau contextuel additionnel lorsque l’espace le permet.

PC : survol pour aperçu facultatif, clic/raccourci pour action ; affichage enrichi mais aucune information mécanique exclusive.

Manette : navigation par focus complète, sans dépendance à un pointeur.

## Équilibrage synthétique et humain

`veilleurs_vs001_balance_sim.py` protège automatiquement :

- lumière sur profils équilibré/méthodique ;
- bruit maximal ;
- fréquence d’événements synthétique ;
- hiérarchie structurelle des profils de Goules ;
- probabilités exactes S6 ;
- total de loot/or ;
- absence de prime économique à la mise à mort de S6.

Le fichier `vs001_playtest_guardrails.json` impose explicitement que ces valeurs restent **provisoires** tant que les playtests humains n’ont pas été réalisés.

Le protocole humain commence à 12 runs ciblés ; une modification importante n’est envisagée qu’après au moins 30 runs ou une rupture P0/P1 évidente.

## Ce qui reste réellement à faire dans Godot

Le noyau logique n’est plus seulement un document. Le travail restant est principalement l’intégration jouable :

1. instancier physiquement les modules S1–S8 ;
2. connecter les interactions monde aux méthodes du runtime de session ;
3. connecter combats réels et conséquences anatomiques à l’état VS001 ;
4. connecter les cadavres physiques aux ancres de Rémanence ;
5. connecter UI tactile/desktop/manette ;
6. connecter sauvegarde globale via `ExpeditionManager`/`SaveManager` ;
7. produire le blockout puis les assets ;
8. exécuter le protocole de playtest sur appareils réels.

## Définition de « prêt pour scène jouable »

Le bloc logique est prêt lorsque :

1. l’audit VS001 passe ;
2. la simulation synthétique passe ;
3. l’import strict Godot passe ;
4. le smoke VS001 passe ;
5. aucun contrat global existant n’est contredit ;
6. le graphe fixe est reproductible ;
7. S6/S7/S8 et la sérialisation ont des états terminaux testés.

Après cela, le prochain verrou n’est plus une décision de game design : c’est la construction et le test réel des scènes Godot, puis les playtests sur les appareils cibles.
