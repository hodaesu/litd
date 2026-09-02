# LITD : Les Veilleurs — VS001 « Les Voix sous le Sanctuaire »

## Statut

Contrat de vertical slice prêt à implémenter. Le but de VS001 est de démontrer en une expédition courte le noyau de **LITD : Les Veilleurs** : exploration, combat anatomique, lumière/bruit, cadavres persistants, Rémanence, recrutement ennemi, choix d’extraction et interface mobile/PC commune au niveau des règles.

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

## Règle d’architecture

VS001 s’appuie sur les systèmes existants :

- `ExpeditionManager` pour l’état et la sérialisation d’expédition ;
- `ExplorationDirector` pour perception, pièges, patrouilles, bruit/lumière et états de salle ;
- `HUDDirector`/`ContextHUD` pour la divulgation contextuelle et les confirmations ;
- contrats globaux d’anatomie/blessures/capture existants pour éviter une seconde logique parallèle.

Aucun système VS001 ne doit dupliquer une règle globale lorsqu’une règle globale existe déjà. Les fichiers VS001 peuvent adapter des valeurs et ajouter du contenu mais doivent rester compatibles avec les contrats centraux.

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

### QA

- `tools/qa/veilleurs_vs001_audit.py`
- `tests/test_veilleurs_vs001_data.py`
- `docs/VEILLEURS_VS001_QA_MATRIX.md`

## Exploration Pulse

Le Pulse est une horloge abstraite invisible. Un déplacement de corridor, une fouille, un traitement ou une interaction profonde peut consommer un ou plusieurs Pulses. Ouvrir la carte, consulter l’inventaire ou regarder brièvement ne consomme rien.

Ordre de résolution :

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

Cette distinction empêche de casser le bestiaire/capture global.

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

Voies principales :

- observer ;
- réduire la menace ;
- diagnostiquer/soigner ;
- désamorcer la peur ;
- offrir une ressource ;
- maîtriser ;
- partir ;
- tuer.

Les actions des quatre Veilleurs ont des conséquences distinctes. Une approche douce augmente confiance/stabilité ; bloquer physiquement la sortie augmente la contrainte mais aussi la peur ; soigner crée un avantage relationnel important ; la force directe est possible mais moins fiable et laisse un historique différent.

Le recrutement est bloqué si :

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

## Ce qui est explicitement laissé au playtest

Ces valeurs sont verrouillées comme **baseline**, pas comme équilibrage final :

- consommation lumière ;
- seuils et propagation du bruit ;
- statistiques des trois profils de Goules ;
- taux de recrutement ;
- loot ;
- probabilités d’événements ;
- seuils de difficulté des interactions.

Elles ne doivent être modifiées qu’après mesure contre les objectifs de la matrice QA.

## Définition de « prêt à coder »

Le contenu est prêt à coder lorsque :

1. l’audit de données passe ;
2. aucun contrat global existant n’est contredit ;
3. le graphe fixe est reproductible ;
4. chaque salle possède ses interactions et sorties ;
5. les quatre Veilleurs ont des variantes de dialogue ;
6. les branches S6 et S7 ont des états terminaux définis ;
7. la Rémanence utilise des anchors/flags ;
8. les mêmes commandes abstraites sont utilisables tactile/souris/clavier/manette.

Le blocage suivant n’est plus une décision de game design : c’est l’intégration Godot, le lancement réel du projet, l’exécution de `pytest`, puis les playtests sur résolutions et appareils réels.
