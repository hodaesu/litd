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
- quatuor canonique Nayra, Tarek, Aïsha et Idris ;
- absence du quatuor obsolète Sahen/Mira/Narem/Ysra hors tests négatifs et exceptions historiques autorisées ;
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

Les références à l’ancien quatuor ne sont tolérées que lorsqu’elles servent explicitement de garde négative ou de trace historique gelée. Elles ne sont jamais autorisées comme combattants actifs.

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

## Définition de « prêt pour PC »

**Prêt pour PC** signifie que les contrôles automatisables sont cohérents et que les éléments encore ouverts exigent réellement un rendu, un périphérique, un SDK/signature ou un jugement sensoriel. Cela ne signifie pas que le jeu est terminé.
