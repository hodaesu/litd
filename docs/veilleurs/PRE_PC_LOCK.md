# LITD : Les Veilleurs — verrou pré-PC

## Objectif

Ce jalon sépare ce qui peut être contrôlé automatiquement dans le dépôt de ce qui exige réellement un PC ou un appareil physique.

Le contrat machine est `data/veilleurs/pre_pc_gate.json` et son audit est `tools/qa/veilleurs_pre_pc_audit.py`.

## Ce qui est verrouillé automatiquement

Le gate pré-PC contrôle notamment :

- famille moteur **Godot 4.7.x** pour le projet ;
- CI Godot épinglée sur **4.7.2** ;
- fichiers de production essentiels ;
- addon `Veilleurs Production Pipeline` ;
- quatuor **player-facing canonique** : Nayra Orun, Tarek Senn, Aïsha Maren et Idris Vael ;
- IDs d’entité canoniques `ENT_WATCHER_NAYRA`, `ENT_WATCHER_TAREK`, `ENT_WATCHER_AISHA`, `ENT_WATCHER_IDRIS` ;
- runtime IDs canoniques `nayra_orun`, `tarek_senn`, `aisha_maren`, `idris_vael` ;
- interdiction des anciens IDs `ENT_WATCHER_SAHEN`, `ENT_WATCHER_MIRA`, `ENT_WATCHER_NAREM`, `ENT_WATCHER_YSRA` hors gardes négatives prévues ;
- six donjons de production ;
- contrats QA v0.6 → v0.9 ;
- 12 ultimes et leurs slots de production ;
- presets Web, Windows, Android, iOS et Linux ;
- import Godot strict ;
- smokes v0.6, v0.7, v0.8 et v0.9 ;
- QA six donjons ;
- régression tactile logique ;
- parcours UI joueur ;
- sauvegarde/reprise et Rémanence selon les gates associés ;
- séparation des validations automatiques et matérielles.

Les données v0.6 actives (`data/veilleurs/v06/watchers.json`) et le verrou pré-PC définissent le quatuor canonique utilisé pour cette verticale. Les anciens ponts de compatibilité autorisés restent confinés aux fichiers explicitement listés dans `allowed_stale_reference_files` jusqu’à leur migration dédiée.

## Pipeline

Toute production Veilleurs suit :

`source canonique -> données/assets -> intégration Godot -> contrat -> smoke -> rapport -> PR -> fusion`

- `quick` : validation quotidienne ;
- `changed` : validation ciblée d’une PR ;
- `full` : régression historique complète.

Rapports :

- `build/automation/veilleurs_pre_pc_status.json` ;
- `build/automation/veilleurs_pipeline_report.json` ;
- `build/automation/veilleurs_repository_integrity.json`.

## Ce qui exige encore du matériel réel

Les contrôles headless ne remplacent pas :

- confort tactile réel sur iPhone/Android ;
- safe areas, encoche et Dynamic Island ;
- haptique ;
- FPS, mémoire, chauffe et throttling ;
- qualité visuelle et lisibilité finales ;
- contrôleur physique ;
- mixage sur haut-parleurs/casque ;
- build iOS signé et installé sur iPhone.

## Première ouverture sur PC

Prérequis pour Les Veilleurs :

- Git ;
- Python 3 ;
- **Godot 4.7.x**.

Le lanceur Windows est :

`tools/workstation/LITD_VEILLEURS_PC_PREPARE.cmd`

Équivalent direct :

```bash
python tools/workstation/veilleurs_pc_preflight.py --run-tests
```

Le rapport est écrit dans :

`local/reports/veilleurs_pc_preflight.json`

Blender, Reaper, MuseScore, Visual Studio et Unreal Engine ne sont pas requis pour cette première session.

Après un préflight vert :

1. ouvrir `project.godot` avec Godot 4.7.x ;
2. laisser l’import terminer ;
3. lancer **Veilleurs QA** ;
4. pour un jalon, lancer **Veilleurs QA complète** ;
5. poursuivre avec les validations visuelles, tactiles, audio et performance sur matériel réel.

## Auto-test développeur prioritaire

Pour la verticale du Chapitre I, le chemin recommandé est désormais :

```bat
tools\workstation\LITD_VEILLEURS_FIRST_PLAYTEST.cmd
```

Sans identifiant explicite, le lanceur utilise `developer-selftest`. La build exportée est alors lancée avec l'instrumentation développeur opt-in : étapes de la tranche 30–45 minutes, chronomètre, écran courant et journal local des problèmes. Cette instrumentation ne valide aucun gate humain et n'est pas activée pour les testeurs naïfs.

## Définition de « prêt pour PC »

**Prêt pour PC** signifie que les contrôles automatisables sont cohérents et que les éléments encore ouverts exigent réellement un rendu, un périphérique, un SDK/signature ou un jugement sensoriel. Cela ne signifie pas que le jeu est terminé.
