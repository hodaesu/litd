# LITD : Les Veilleurs — verrou pré-PC

## Objectif

Ce jalon fixe la frontière entre ce qui peut être préparé, contrôlé et sécurisé automatiquement dans le dépôt et ce qui nécessite réellement un poste de travail ou un appareil physique.

La règle est volontairement stricte : **une tâche n'est reportée au PC que si sa qualité dépend du matériel, du rendu réel, d'un SDK/signature externe ou d'un jugement visuel/auditif impossible en headless**.

## Ce qui est verrouillé avant PC

Le contrat machine est `data/veilleurs/pre_pc_gate.json` et son audit est `tools/qa/veilleurs_pre_pc_audit.py`.

Le gate pré-PC contrôle automatiquement :

- Godot 4.3 comme version projet ;
- présence des fichiers de production essentiels ;
- activation par défaut de l'addon `Veilleurs Production Pipeline` ;
- roster canonique des quatre Veilleurs : Nayra, Tarek, Aïsha et Idris ;
- absence d'identifiants runtime obsolètes dans les fichiers Veilleurs de production ;
- contrat des six donjons v0.9 ;
- contrat QA v0.9 ;
- définition des 12 ultimes et de leurs cinq slots d'assets obligatoires ;
- cibles de validation téléphone, tablette, desktop, contrôleur et mouvement réduit pour les ultimes ;
- presets d'export Web, Windows, Android, iOS et Linux ;
- câblage des smokes Wave 3, six donjons, tactile et parcours UI ;
- intégration de l'audit dans le pipeline de production ;
- séparation explicite des validations automatiques et matérielles.

## Pipeline automatique

Toute production Veilleurs suit :

`source canonique -> données/assets -> intégration Godot -> contrat -> smoke -> rapport -> PR -> fusion`

Le mode `quick` couvre la validation quotidienne. Le mode `changed` cible une PR. Le mode `full` appelle la suite de régression historique complète.

Le rapport du verrou pré-PC est écrit dans :

`build/automation/veilleurs_pre_pc_status.json`

Le rapport général reste :

`build/automation/veilleurs_pipeline_report.json`

## Handoff des ultimes avant production d'assets finaux

Les 12 ultimes sont déjà décrits comme contrats de production. Chaque ultime doit conserver :

- sa mécanique ;
- ses conditions et garde-fous ;
- sa chorégraphie en beats ;
- un slot animation ;
- un slot caméra ;
- un slot audio ;
- un slot haptique ;
- un slot VFX ;
- une variante ou vérification mouvement réduit ;
- une validation de lisibilité téléphone/tablette/desktop.

Le verrou pré-PC vérifie ces obligations sans prétendre que les assets artistiques finaux existent déjà. Leur réalisation et leur jugement final appartiennent au handoff matériel/artistique.

## Ce qui doit attendre un PC ou un appareil réel

### Tactile réel

Le smoke vérifie les événements et les tailles/cibles logiques. Le confort d'un pouce, la friction des gestes, les erreurs involontaires et l'accessibilité réelle doivent être essayés sur téléphone/tablette.

### Safe areas

Les contraintes logiques peuvent être prévues, mais encoche, Dynamic Island, barres système et variations réelles doivent être vues sur plusieurs appareils.

### Haptique

Les événements et intensités demandées peuvent être contractuels. Leur sensation et leur différenciation doivent être validées physiquement.

### Performance et thermique

La CI peut détecter des erreurs et certains budgets. FPS réel, chauffe, mémoire, consommation et throttling demandent les appareils cibles.

### Qualité visuelle finale

La CI ne peut pas décider si un HUD est trop petit, un contraste trop faible, un VFX trop envahissant ou une animation assez lisible sur un écran réel.

### Contrôleur physique

Le focus et les actions peuvent être simulés ; la sensation, les conflits de mapping et les périphériques réels doivent être vérifiés sur matériel.

### Audio réel

Le runtime et les fichiers peuvent être testés automatiquement. Mixage, intelligibilité, dynamique et fatigue doivent être contrôlés sur haut-parleurs et casque.

### Build iOS signé

Le preset iOS peut être verrouillé dans le dépôt. L'installation finale sur iPhone dépend de l'environnement Apple approprié, de Xcode et de la signature.

## Première ouverture sur PC

L'addon de production est désormais activé dans `project.godot`. Il ne doit donc plus être nécessaire de l'activer manuellement dans les réglages du projet.

À l'ouverture du dépôt :

1. ouvrir le projet avec Godot 4.3 ;
2. laisser l'import terminer ;
3. lancer **Veilleurs QA** ;
4. pour un jalon, lancer **Veilleurs QA complète** ;
5. passer ensuite seulement aux validations physiques listées ci-dessus.

Si le gate automatique est vert, aucune phase de conception ou de recopie de données ne doit être réintroduite pendant cette étape.

## Définition de « prêt pour PC »

**Prêt pour PC** signifie : tous les contrôles automatisables passent, les contrats de production sont cohérents et les seuls éléments restant ouverts exigent un rendu, un appareil, un périphérique, un SDK/signature ou un jugement sensoriel réel.

Cela ne signifie pas « jeu terminé ». Cela signifie que le travail restant n'est plus reporté au PC par commodité : il y est envoyé parce qu'il a réellement besoin du PC ou du matériel cible.
