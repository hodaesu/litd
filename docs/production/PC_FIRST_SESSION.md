# Première session PC — Light in the Dark

## Ordre obligatoire

1. Cloner le dépôt puis ouvrir sa racine.
2. Double-cliquer sur `tools/workstation/LITD_PC_PREPARE.cmd` (administrateur recommandé).
3. Conserver le bundle créé dans `local/backups/`.
4. Redémarrer le terminal Windows afin de rafraîchir le PATH.
5. Lancer `LITD_PC_TEST.cmd`.
6. Corriger chaque logiciel marqué manquant dans `local/reports/pc_preflight.json`.
7. Lancer `LITD_PC_IMPORT.cmd`.
8. Lancer `LITD_PC_QA_ROOM.cmd` pour ouvrir directement la salle de validation.
9. Lancer ensuite `LITD_PC_LAUNCH.cmd` pour le projet complet.
10. Installer Unreal Engine 5.8 dans Epic Games Launcher, puis lancer `LITD_UNREAL_COMPARE.cmd`.

## Logiciels attendus

- Git
- Git LFS
- Python 3.12
- Godot 4.3 (version de référence du projet)
- Blender
- MuseScore Studio
- REAPER
- Visual Studio 2022 : Développement de jeux en C++, MSVC et SDK Windows
- Epic Games Launcher
- Unreal Engine 5.8 (installation manuelle dans le Launcher)

Le diagnostic enregistre processeur, RAM, GPU/VRAM et espace disque dans `local/reports/pc_preflight.json`. Il exige 150 Go libres au minimum ; 250 Go sont conseillés si Godot et Unreal restent installés ensemble.

Pour placer les caches et rendus lourds sur un autre disque, lancer depuis PowerShell :

```powershell
.\tools\workstation\LITD_PC_SETUP.ps1 -Install -VerifyRemote -HeavyDataRoot "D:\LITD_LOCAL"
```

Les banques SINE/Berlin Free Orchestra et les autres bibliothèques sous licence restent locales et ne doivent pas être ajoutées à Git.

## Validation visuelle dans Godot

- lancer d'abord la salle de validation isolée ; elle ne modifie pas la sauvegarde de campagne ;
- vérifier déplacement, caméra, clavier/souris et manette ;
- parler à Ilyan, ouvrir le coffre et récupérer son objet ;
- combattre les quatre ennemis et utiliser compétences, soin et grenade ;
- inspecter héros et ennemis sans mettre le combat en pause ;
- vérifier l'indicateur de capture dans la fiche contextuelle ;
- vérifier postures de Peur/Espoir, Folie et blessure persistante ;
- sauvegarder, charger et contrôler le retour après combat ;
- parcourir Sanctuaire → Porte → donjon ;
- demander la cendre avec G ;
- confirmer qu’elle reste invisible sans demande ;
- confirmer la priorité quête puis le retour vers le boss ;
- bloquer une sortie et vérifier le recalcul ;
- confirmer sa disparition après 3,5 secondes ;
- vérifier le double appui dans la zone supérieure droite sur l’appareil tactile ;
- contrôler lisibilité, densité, couleur et performances.

## Audio

1. Exécuter le diagnostic du pipeline musical.
2. Ouvrir REAPER et importer le MIDI maître.
3. Détecter les instruments disponibles.
4. Configurer les 21 régions et la matrice de rendu.
5. Produire les 210 WAV synchronisés.
6. Lancer le finaliseur avant l’import Godot.
7. Initialiser la sonothèque SFX locale puis ingérer uniquement des sources dont la licence est vérifiée.
8. Écouter les variantes en jeu : aucune validation automatique ne remplace l’écoute.

## Blender

- commencer par Croisé et Chasseur ;
- valider échelle, orientation, rig, sockets et skinning sur un GLB test ;
- corriger ce contrat avant les autres héros ;
- poursuivre avec Médecin, Acolyte et Gardien ;
- produire ensuite les familles d’ennemis puis le kit Sanctuaire/Terre des Cendres ;
- vérifier chaque déformation et animation dans Godot.

## Critères de sortie

La première session est réussie lorsque l’import Godot est propre, le parcours critique fonctionne, la cendre répond correctement, les rapports locaux sont verts et un premier GLB ainsi qu’un premier rendu audio sont validés humainement.

## Comparaison Godot / Unreal

Ne décider d'aucune migration avant d'avoir rempli `unreal/LITDValidation/comparison_scorecard.json` avec le même PC, la même résolution et les mêmes GLB/textures. Relever au minimum : FPS moyen, 1 % low, RAM, VRAM, démarrage, import, taille du build et temps nécessaire pour modifier une interaction. Unreal doit apporter un avantage de production clair, pas seulement un éclairage par défaut plus flatteur.
