# Light in the Dark — LITD Universe

Dépôt Godot principal de **Light in the Dark**, regroupant les systèmes, contenus, outils QA et branches de production de LITD Universe. La cible technique active de **LITD : Les Veilleurs** est Godot 4.7.x, avec CI épinglée sur Godot 4.7.2.

## LITD : Les Veilleurs

- [Playbook de production](docs/veilleurs/PRODUCTION_PLAYBOOK.md)
- [Bible DA de production](docs/veilleurs/ART_DIRECTION_PRODUCTION_BIBLE.md)
- [Protocole de playtest continu](docs/veilleurs/PLAYTEST_PROTOCOL.md)
- [Gate de validation verticale](docs/veilleurs/VERTICAL_VALIDATION_GATE.md)
- [Bibliothèque — création de jeu vidéo](docs/research/BIBLIOTHEQUE_CREATION_JEU_VIDEO.md)
- [Verrou pré-PC](docs/veilleurs/PRE_PC_LOCK.md)
- [Automatisation de production Godot](docs/veilleurs/GODOT_PRODUCTION_AUTOMATION.md)
- [Validation matérielle](docs/veilleurs/HARDWARE_VALIDATION_PROTOCOL.md)
- [Handoff final des assets](docs/veilleurs/FINAL_ASSET_HANDOFF.md)
- [Automatisation d’intégration de contenu](docs/veilleurs/CONTENT_INTAKE_AUTOMATION.md)
- [Export Android CI](docs/veilleurs/ANDROID_CI_EXPORT.md)
- [Audit d’intégrité du dépôt](docs/veilleurs/REPOSITORY_INTEGRITY_AUDIT.md)
- [Politique de nettoyage des fichiers obsolètes](docs/veilleurs/OBSOLETE_CLEANUP_POLICY.md)

## Documentation LITD Universe

- [Bibliothèque artistique mondiale](docs/BIBLIOTHEQUE_ARTISTIQUE_MONDE.md)
- [Bible du lore — Trois Éveils](docs/LORE_BIBLE.md)
- [Monde extérieur, Voile et Chute](docs/LORE_MONDE_VOILE_ET_CHUTE.md)
- [Civilisations étrangères — peuples, puissances et après-Chute](docs/CIVILISATIONS_ETRANGERES_APRES_CHUTE.md)
- [Civilisations antérieures et Premier Voile](docs/CIVILISATIONS_ANTERIEURES_ET_PREMIER_VOILE.md)
- [Civilisations antérieures des mondes extérieurs](docs/CIVILISATIONS_ANTERIEURES_MONDES_EXTERIEURS.md)
- [Campagne principale — 10 chapitres, boss, révélations et fins](docs/CAMPAGNE_PRINCIPALE.md)
- [Combat tactique — rangs, déplacements et synergies](docs/COMBAT_TACTIQUE_RANGS.md)
- [Combat — démembrements tactiques](docs/COMBAT_DEMEMBREMENTS.md)
- [Combat v5 — déplacements forcés, démembrements et phases de boss](docs/COMBAT_DEPLACEMENTS_DEMEMBREMENTS.md)
- [Combat v6 — familles ennemies et réactions aux démembrements](docs/COMBAT_FAMILLES_ENNEMIES.md)
- [Combat v13 — anatomie avancée, blessures, capture, psychologie, Infirmerie et Blender](docs/COMBAT_ANATOMIE_AVANCEE.md)
- [Chapitre I — verticale jouable des Terres de Cendre](docs/CHAPITRE_01_VERTICAL_SLICE.md)
- [Chapitre II — enquête jouable et Route des Bornes](docs/CHAPITRE_02_VERTICAL_SLICE.md)
- [Chapitre III — Projet Seuil, responsabilités et Écho](docs/CHAPITRE_03_PROJET_SEUIL.md)
- [Chapitre IV — Première Rupture et Ashaï de Nhal](docs/CHAPITRE_04_PREMIERE_RUPTURE.md)
- [Chapitre V — Or-Silex et la Grande Fermeture](docs/CHAPITRE_05_GRANDE_FERMETURE.md)
- [Chapitre VI — Les Absents](docs/CHAPITRE_06_LES_ABSENTS.md)
- [Chapitre VII — Les responsables vivants](docs/CHAPITRE_07_RESPONSABLES_VIVANTS.md)
- [Chapitre VIII — Le monde extérieur](docs/CHAPITRE_08_MONDE_EXTERIEUR.md)
- [Chapitre IX — Ce qu'est réellement le Voile](docs/CHAPITRE_09_NATURE_DU_VOILE.md)
- [Chapitre X — La lumière mérite d'être défendue](docs/CHAPITRE_10_LA_LUMIERE_MERITE_ETRE_DEFENDUE.md)
- [Épilogues, postgame et Nouveau Cycle+](docs/EPILOGUES_POSTGAME_NG_PLUS.md)
- [Histoire fondatrice — Dernière Guerre et Trois Éveils](docs/HISTOIRE_TROIS_EVEILS.md)
- [La Concorde — droit et justice](docs/CONCORDE_DROIT_JUSTICE.md)
- [La Concorde avant la Chute — courants politiques](docs/CONCORDE_COURANTS_PRE_CHUTE.md)
- [La Concorde — cités, institutions, histoire et quêtes politiques](docs/CONCORDE_MONDE_POLITIQUE.md)
- [La Concorde après la Chute — courants et figures politiques](docs/CONCORDE_COURANTS_POST_CHUTE.md)

## Vérifier le projet

```bash
python -m pip install -r requirements-dev.txt
python -m pytest
python -m tools.qa.audit
python -m tools.qa.cross_system_audit
python -m tools.qa.balance_audit
python -m tools.qa.combat_turn_audit
python -m tools.qa.tactical_combat_audit
python -m tools.qa.dismemberment_audit
python -m tools.qa.displacement_combat_audit
python -m tools.qa.enemy_family_tactics_audit
python -m tools.qa.anatomy_system_audit
python -m tools.qa.veilleurs_player_validation_audit
python -m tools.qa.combat_economy_sim_v2
```

`tools.qa.audit` vérifie les données de base, les références `res://`, les assets, les conflits Git, les workflows YAML et la cohérence structurelle du gate joueur Les Veilleurs.

`tools.qa.cross_system_audit` vérifie les relations entre systèmes : campagne I→X, scènes et routes, contrats des boss, sept Vestiges Profonds, sauvegarde, autoloads, postgame et règles du Nouveau Cycle+.

`tools.qa.balance_audit` vérifie la progression 1→50, le coût et les prérequis des arbres, les ascensions des compagnons, les six fins, les soft-locks économiques du postgame, le scaling NG+ et les recrutements de boss/mini-boss.

`tools.qa.combat_turn_audit` verrouille le moteur de rounds à quatre héros conservé par la chaîne historique de compatibilité : chaque héros vivant agit une fois par round, le compagnon agit une seule fois après le groupe, puis les ennemis.

`tools.qa.tactical_combat_audit` vérifie les rangs, déplacements, techniques propres aux héros, ciblage avant/arrière et synergies de formation.

`tools.qa.dismemberment_audit` vérifie que le démembrement reste tactique, que le ciblage anatomique remplace le choix aléatoire historique et que le niveau de gore reste indépendant de la mécanique.

`tools.qa.displacement_combat_audit` vérifie poussées/tractions, recul sous Peur et manœuvres de boss liées à leurs parties anatomiques uniques.

`tools.qa.enemy_family_tactics_audit` vérifie les familles tactiques, les comportements élite/boss et les réactions aux pertes de fonctions.

`tools.qa.anatomy_system_audit` verrouille l’anatomie avancée : ciblage volontaire, Trauma par partie, spécialisations, anatomies de boss, IA adaptative, Peur/Folie, capture, convalescence, blessures fonctionnelles, interface anatomique et contrats Blender/VFX.

`tools.qa.veilleurs_player_validation_audit` vérifie le contrat de preuve joueur du Chapitre I, ses liaisons avec les validations matérielles et garantit que le modèle versionné reste en `NOT_RUN` tant qu'aucun playtest humain n'a réellement eu lieu.

`tools.qa.combat_economy_sim_v2` reste une couche de compatibilité du modèle numérique ; les simulateurs plus récents peuvent l’importer au lieu de dupliquer toute la logique historique.

Les rapports QA sont écrits dans `reports/`.

Le pipeline Blender anatomique est préparé par `data/blender/dismemberment_contract.json` et `tools/blender/generate_dismemberment_jobs.py`.

Sous macOS/Linux :

```bash
bash ./tools/build/run_ci.sh
```

Le script exécute également le smoke test Godot si `godot` est disponible localement.

## GitHub Actions

- **CI** : tests Python, audits de structure/équilibrage et smoke Godot headless.
- **Production Veilleurs** : contrats, import strict Godot 4.7, smokes v0.6→v0.9, six donjons, régression tactile/UI et export Android debug.
- **Nightly QA** : régressions automatisées.
- **Release** : création d’une release lors d’un tag `v*`.

## État technique actuel

Le dépôt n’est plus un bootstrap de Sprint 1. Les fichiers d’import Working Copy, anciens rapports statiques, manifeste Sprint 1 et guides d’initialisation déjà accomplis ont été retirés. Les composants historiques encore importés par le runtime, les sauvegardes, les tests ou les simulateurs restent conservés jusqu’à leur migration réelle.

Pour préparer une session PC Les Veilleurs :

```bash
python tools/workstation/veilleurs_pc_preflight.py --run-tests
```

Sous Windows, le lanceur `tools/workstation/LITD_VEILLEURS_PC_PREPARE.cmd` fournit le même point d’entrée pratique.
