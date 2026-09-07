# LITD : Les Veilleurs — protocole de validation matérielle

## But

Après le verrou pré-PC, il ne reste que huit validations qui exigent réellement un écran, un appareil, un périphérique, une écoute ou la chaîne Apple. Ce document transforme ces huit points en protocole reproductible.

Le contrat machine est :

`data/veilleurs/hardware_validation_contract.json`

Le rapporteur de session est :

`tools/workstation/veilleurs_hardware_session.py`

## Règle de fermeture

Un gate n'est considéré comme terminé que si :

1. il a été exécuté sur une plateforme concernée ;
2. toutes les preuves obligatoires ont été saisies ;
3. le résultat est `pass` ;
4. aucun problème bloquant n'est ouvert pour ce gate.

Une impression visuelle ou un simple « ça marche » ne suffit pas.

## 1 — Tactile réel

À tester sur iPhone et Android réels.

Parcours minimal : hub, navigation de donjon, sélection des cibles, sélection des zones corporelles, compétences, retraite, recrutement et sauvegarde/reprise.

À noter : erreurs de toucher, gestes involontaires, commandes trop petites, conflits avec les gestes système et actions difficiles à atteindre au pouce.

Échec bloquant : une action critique difficile ou impossible à exécuter de façon fiable.

## 2 — Safe areas réelles

À tester sur plusieurs formats réels lorsque disponibles, notamment appareils avec encoche, Dynamic Island ou zones système importantes.

Vérifier : HUD de combat, hub, modales, menus contextuels et informations de bord d'écran.

Échec bloquant : texte ou contrôle indispensable masqué, coupé ou inaccessible.

## 3 — Haptique réelle

Tester : validation UI, erreur UI, impact léger, impact lourd, événement critique, ultime et traumatisme majeur/amputation.

Le joueur doit pouvoir distinguer les familles de feedback sans fatigue excessive. La désactivation de l'haptique doit fonctionner sans supprimer le feedback visuel/audio indispensable.

## 4 — Performance, mémoire et thermique

Plateformes : iOS, Android et Windows.

Scénarios : lancement à froid, 10 minutes au Refuge, 20 minutes de combat, traversée des six donjons, stress des ultimes et boucles sauvegarde/reprise.

Cible : 60 FPS lorsque le matériel le permet. Plancher dur : le jeu ne doit pas rester durablement sous 30 FPS.

Aucun crash n'est accepté. Une baisse thermique prolongée ne doit pas rendre le jeu injouable. Les mesures de FPS, pics de frame time et mémoire doivent être consignées.

## 5 — Lisibilité et qualité visuelle finales

Tester à taille réelle sur téléphone, tablette si disponible et desktop.

Écrans prioritaires : Refuge, combat, état corporel, inventaire, arbres de compétences, recrutement, Archives, ultimes et scènes sombres.

Vérifier que les informations tactiques ne dépendent pas uniquement de la couleur et que sang, VFX, textures et cadres ne masquent pas le gameplay.

## 6 — Contrôleur physique

Tester menu principal, Refuge, combat, zones corporelles, compétences, modales, pause et reprise.

Aucun menu ne doit piéger le focus. Toutes les actions indispensables doivent être accessibles sans souris ni tactile pendant une session manette. Tester aussi déconnexion puis reconnexion.

## 7 — Audio réel

Écouter sur haut-parleur de téléphone, casque et sortie PC.

Tester : ambiance du Refuge, mix combat, dialogue, ultime et bas volume.

Les signaux tactiques doivent rester audibles. Aucun clipping reproductible, saut de volume agressif ou dialogue systématiquement masqué n'est accepté.

## 8 — Build iOS signé installé

Ce gate exige macOS/Xcode et une configuration de signature Apple valide.

Valider : export signé, installation sur iPhone réel, lancement à froid, sauvegarde/reprise, arrière-plan/premier plan, combat, tactile, audio et haptique.

Le build signé ne doit nécessiter aucune modification des données de gameplay pour fonctionner.

## Création d'une session de test

Exemple iPhone :

```powershell
python tools/workstation/veilleurs_hardware_session.py init --session iphone_test_01 --platform ios --device "iPhone" --os-version "iOS"
```

Le fichier est créé sous :

`local/reports/veilleurs_hardware/`

## Enregistrer un gate

Chaque élément de preuve se passe avec `--evidence key=value`.

Exemple :

```powershell
python tools/workstation/veilleurs_hardware_session.py record --session-file local/reports/veilleurs_hardware/iphone_test_01.json --gate real_mobile_touch --status pass --evidence device_model=iPhone --evidence os_version=iOS --evidence screen_size=phone --evidence tester_notes=ok --evidence misinput_count=0 --evidence blocking_issue_count=0
```

Si une preuve obligatoire manque, un `pass` est refusé et devient `incomplete`.

## Vérifier une session

```powershell
python tools/workstation/veilleurs_hardware_session.py status --session-file local/reports/veilleurs_hardware/iphone_test_01.json
```

Une session n'est verte que lorsque tous les gates applicables à sa plateforme sont `pass`.

## Ordre conseillé sur PC/appareils

1. Import Godot 4.3 et QA rapide.
2. Lisibilité/qualité visuelle desktop.
3. Contrôleur physique.
4. Performance Windows.
5. Build Android et tests tactiles/safe areas/audio/performance.
6. Build iOS signé.
7. Tests tactile, safe areas, haptique, audio et performance iPhone.
8. Relecture des rapports et fermeture des gates sans problème bloquant.

À ce stade, le travail n'est plus de concevoir les tests : il consiste uniquement à exécuter ce protocole sur le matériel réel et à corriger ce que les mesures révèlent.
