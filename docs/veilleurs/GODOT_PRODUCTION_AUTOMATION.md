# LITD : Les Veilleurs — automatisation de production Godot

## But

Toute nouvelle production destinée à **LITD : Les Veilleurs** doit pouvoir entrer dans le dépôt, être classée, validée, importée par Godot 4.3, testée et rendue traçable sans reconstruire manuellement une chaîne différente à chaque ajout.

Le pipeline ne remplace pas les systèmes existants. Il les orchestre : audits Python, import Godot strict, smokes Veilleurs, QA mobile/UI et suite complète historique.

## Point d'entrée unique

- Windows : `tools/godot/run_veilleurs_pipeline.ps1`
- macOS/Linux : `tools/godot/run_veilleurs_pipeline.sh`
- CI : `.github/workflows/veilleurs-production-automation.yml`
- Godot Editor : addon `addons/veilleurs_pipeline/`
- verrou pré-PC : `data/veilleurs/pre_pc_gate.json`
- audit pré-PC : `tools/qa/veilleurs_pre_pc_audit.py`

Le rapport machine est généré dans :

`build/automation/veilleurs_pipeline_report.json`

Un index des fichiers pris en compte est généré dans :

`build/automation/veilleurs_content_index.json`

Le statut du verrou pré-PC est généré dans :

`build/automation/veilleurs_pre_pc_status.json`

## Les trois modes

### `quick`

À exécuter avant un commit ou après une petite intégration.

Il effectue :

1. validation JSON ;
2. détection des collisions de casse ;
3. contrôle des références `res://` statiques ;
4. audit du verrou pré-PC ;
5. audits Veilleurs v0.6 → v0.9 présents dans le dépôt ;
6. import Godot 4.3 strict ;
7. smoke tactique v0.6 ;
8. smoke production v0.7 ;
9. smoke Wave 2 v0.8 ;
10. smoke Wave 3 v0.9 ;
11. scène QA six donjons ;
12. régression tactile mobile ;
13. régression du parcours UI joueur.

### `changed`

Utilisé par les pull requests. Seuls les fichiers modifiés par rapport à la branche de base sont indexés et contrôlés statiquement. Les catégories touchées apparaissent dans le rapport.

### `full`

À utiliser avant une fusion importante, un jalon ou une release. Après l'import strict, il appelle la suite historique :

`tools/build/run_godot_ci.sh`

Cette suite reste la référence de non-régression globale.

## Catégories automatiquement surveillées

### Données

`data/veilleurs/**` et JSON de jeu.

Exemples : héros, ennemis, boss, compétences, progression, rencontres, loot, blessures, recrutement, Rémanence, dialogues structurés et paramètres de balance.

### Art / Blender

`assets/**`, `tools/art/**`, `tools/blender/**`.

Exemples : personnages, ennemis, environnements, matériaux, textures, props, icônes, portraits et exports 3D.

### Animation

`tools/animation/**` ainsi que les scènes/scripts d'animation.

Exemples : locomotion, impacts, compétences, réactions corporelles, morts, ultimes, caméra et transitions.

### Audio

`tools/audio/**`, `tools/music_pipeline/**`, `tools/voice/**`, banques audio et musique.

Exemples : SFX, musique adaptative, voix, ambiance, signaux UI et retours de combat.

### Interface

`scripts/ui/**`, `scenes/ui/**` et scènes UI Veilleurs.

Exemples : HUD, menus contextuels, informations contextuelles, hub, Refuge, Archives, équipement, compétences, recrutement et écrans téléphone/tablette/PC.

### Gameplay

`scripts/core/**`, `scripts/world/**`, `scenes/veilleurs/**`.

Exemples : combat, anatomie, blessures, démembrement, IA, exploration, graphe de donjon, rencontres, sauvegarde, progression et Rémanence.

### Tests

`scenes/tests/**`, `scripts/qa/**`, `tools/qa/**`.

Chaque système important doit avoir son contrat ou son smoke correspondant avant d'être considéré terminé.

## Règle de production à appliquer à tout nouveau contenu

Pour toute production future, l'ordre est :

**source canonique → données/asset → intégration Godot → contrat → smoke → rapport → PR → fusion**.

Une production n'est pas considérée comme intégrée parce qu'un fichier existe. Elle l'est quand le pipeline l'accepte.

## Conventions pour les futures productions

1. Un identifiant canonique stable et en minuscules `snake_case` pour les identifiants de contenu ; les IDs runtime historiques restent ceux des contrats existants.
2. Aucun doublon différant uniquement par la casse.
3. Les données structurées restent data-driven ; ne pas recopier les valeurs dans plusieurs scripts.
4. Toute référence Godot statique utilise `res://`.
5. Les assets source et les assets runtime ne doivent pas être confondus.
6. Toute nouvelle scène jouable importante reçoit un smoke headless.
7. Tout nouveau système transverse reçoit un audit Python lorsque le contrat peut être vérifié sans moteur.
8. Le tactile et les contraintes mobile restent des régressions obligatoires pour Les Veilleurs.
9. Les systèmes existants `DataLoader`, sauvegarde, blessures/capture, Rémanence, rencontres et génération de donjon doivent être étendus plutôt que dupliqués.
10. Les anciennes vagues validées restent protégées par régression.
11. Une tâche n'est reportée au PC que si elle nécessite réellement matériel, SDK/signature externe ou jugement sensoriel.
12. L'ancien quatuor Sahen/Mira/Narem/Ysra ne peut apparaître dans le runtime courant ; ses références éventuelles sont limitées aux tests négatifs explicitement autorisés et aux contrats historiques gelés.

## Utilisation Windows

Depuis la racine du dépôt :

```powershell
.\tools\godot\run_veilleurs_pipeline.ps1 -Mode quick
```

Pour tout tester :

```powershell
.\tools\godot\run_veilleurs_pipeline.ps1 -Mode full -RequireGodot
```

`GODOT_BIN` peut pointer vers l'exécutable Godot 4.3 si `godot` n'est pas dans le PATH.

## Depuis Godot

L'addon `Veilleurs Production Pipeline` ajoute deux commandes :

- **Veilleurs QA** : gate rapide ;
- **Veilleurs QA complète** : régression globale.

L'addon lance le contrôle dans un processus externe afin de ne pas bloquer l'éditeur. Il transmet automatiquement le chemin de l'exécutable Godot courant via `GODOT_BIN`.

L'addon est maintenant déclaré dans `[editor_plugins]` de `project.godot`. Après récupération de la version courante du dépôt, il doit donc être activé avec le projet sans étape manuelle supplémentaire.

## Verrou pré-PC

Le document détaillé est `docs/veilleurs/PRE_PC_LOCK.md`.

Le verrou vérifie ce qui est objectivable avant appareil réel : roster canonique, absence d'IDs obsolètes hors exceptions historiques contrôlées, contrats des six donjons, QA v0.9, 12 ultimes, slots d'assets, presets d'export, smokes v0.6→v0.9, câblage du pipeline et séparation des validations matérielles.

Il ne déclare pas les assets visuels/audio finaux « terminés » : il garantit que leur contrat de production est prêt avant le handoff artistique et matériel.

## GitHub Actions

À chaque pull request touchant Les Veilleurs, la CI lance :

1. `Content contracts and production index` ;
2. `Godot 4.3 pre-PC production smokes`.

Le premier job exécute aussi l'audit pré-PC via la configuration du pipeline. Le second rejoue les quatre vagues techniques v0.6, v0.7, v0.8 et v0.9 avant la QA six donjons, le tactile logique et le parcours UI.

Le workflow manuel permet en plus d'activer `full_suite`, qui exécute la suite Godot historique complète.

Les journaux et rapports sont conservés comme artifacts GitHub Actions lorsqu'ils sont disponibles.

## Ce qui reste forcément matériel / poste de travail

Le headless et la CI sécurisent énormément de choses, mais ne remplacent pas :

- validation tactile réelle sur iPhone/Android ;
- safe areas réelles ;
- haptique ;
- rendu GPU, mémoire, chauffe et performance sur appareils cibles ;
- qualité visuelle finale ;
- lisibilité à taille réelle ;
- manette physique ;
- audio sur haut-parleurs/casque réels ;
- build iOS signé/installé sur appareil.

Ces validations doivent rester des gates de jalon, pas des manipulations nécessaires à chaque petit ajout.
