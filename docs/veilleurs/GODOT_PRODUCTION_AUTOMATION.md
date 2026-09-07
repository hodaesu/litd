# LITD : Les Veilleurs — automatisation de production Godot

## But

Toute nouvelle production destinée à **LITD : Les Veilleurs** doit pouvoir entrer dans le dépôt, être classée, validée, importée sous **Godot 4.7.x**, testée et rendue traçable sans reconstruire manuellement une chaîne différente à chaque ajout.

La CI est épinglée sur **Godot 4.7.2**. Le pipeline orchestre les audits Python, l’import Godot strict, les smokes Veilleurs, la QA mobile/UI et la suite historique de non-régression.

## Points d’entrée

- Windows : `tools/godot/run_veilleurs_pipeline.ps1`
- macOS/Linux : `tools/godot/run_veilleurs_pipeline.sh`
- Python direct : `tools/godot/veilleurs_pipeline.py`
- CI : `.github/workflows/veilleurs-production-automation.yml`
- Godot Editor : addon `addons/veilleurs_pipeline/`
- verrou pré-PC : `data/veilleurs/pre_pc_gate.json`
- audit pré-PC : `tools/qa/veilleurs_pre_pc_audit.py`
- audit d’intégrité : `tools/qa/veilleurs_repository_integrity_audit.py`

Rapports principaux :

- `build/automation/veilleurs_pipeline_report.json`
- `build/automation/veilleurs_content_index.json`
- `build/automation/veilleurs_pre_pc_status.json`
- `build/automation/veilleurs_repository_integrity.json`

## Modes

### `quick`

Validation quotidienne :

1. validation JSON ;
2. collisions de casse ;
3. références `res://` statiques ;
4. verrou pré-PC ;
5. audit d’intégrité transversal ;
6. audits Veilleurs v0.6 → v0.9 ;
7. import Godot 4.7 strict ;
8. smokes v0.6 → v0.9 ;
9. QA six donjons ;
10. régression tactile logique ;
11. parcours UI joueur.

### `changed`

Mode des pull requests : indexe et contrôle les fichiers modifiés par rapport à la branche de base, puis exécute les gates pertinents.

### `full`

Mode de jalon/release : après l’import strict, appelle `tools/build/run_godot_ci.sh` pour la régression globale.

## Commandes

Python :

```bash
python tools/godot/veilleurs_pipeline.py --mode quick --require-godot
python tools/godot/veilleurs_pipeline.py --mode full --require-godot
```

Windows :

```powershell
.\tools\godot\run_veilleurs_pipeline.ps1 -Mode quick
.\tools\godot\run_veilleurs_pipeline.ps1 -Mode full -RequireGodot
```

Si Godot n’est pas dans le `PATH`, `GODOT_BIN` peut pointer vers un exécutable **Godot 4.7.x**.

## Catégories surveillées

Le pipeline surveille notamment :

- données `data/veilleurs/**` ;
- assets et production Blender ;
- animation ;
- audio, musique et voix ;
- UI ;
- gameplay et scènes Veilleurs ;
- tests, audits et scènes QA ;
- `project.godot` et presets d’export.

## Règles de production

Toute production suit :

**source canonique → données/asset → intégration Godot → contrat → smoke → rapport → PR → fusion**.

Principes :

1. identifiants canoniques stables ;
2. aucun doublon ne différant que par la casse ;
3. données structurées data-driven ;
4. références Godot statiques en `res://` ;
5. séparation assets source/runtime ;
6. smoke headless pour toute nouvelle scène jouable importante ;
7. audit Python pour tout contrat transverse objectivable ;
8. tactile/mobile toujours régressé ;
9. extension des systèmes existants plutôt que duplication ;
10. protection des vagues v0.6 → v0.9 par régression ;
11. report au PC uniquement lorsque matériel, SDK/signature ou jugement sensoriel sont réellement nécessaires ;
12. Sahen/Mira/Narem/Ysra interdits du runtime courant hors tests négatifs/exceptions historiques explicitement autorisées.

## Godot Editor

L’addon `Veilleurs Production Pipeline` expose :

- **Veilleurs QA** ;
- **Veilleurs QA complète**.

Il transmet automatiquement l’exécutable Godot courant via `GODOT_BIN` et est déclaré dans `project.godot`.

## GitHub Actions

Les workflows Veilleurs utilisent **Godot 4.7.2** pour les jobs CI. Ils couvrent contrats, import strict, smokes v0.6→v0.9, six donjons, tactile/UI et export Android debug.

Le mode manuel peut activer la suite complète historique.

## Validations qui restent matérielles

La CI ne remplace pas :

- tactile réel iPhone/Android ;
- safe areas ;
- haptique ;
- GPU/CPU/mémoire/chauffe ;
- qualité visuelle finale ;
- lisibilité à taille réelle ;
- manette physique ;
- audio réel ;
- build iOS signé/installé.
