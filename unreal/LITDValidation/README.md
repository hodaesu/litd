# Prototype comparatif Unreal de LITD

Ce projet ne remplace pas Godot. Il recrée uniquement la salle de validation afin de comparer les deux moteurs avant toute décision de migration.

## Installation PC

1. Installer Unreal Engine 5 avec Epic Games Launcher.
2. Installer Visual Studio 2022 avec « Développement de jeux en C++ » et le SDK Windows.
3. Depuis la racine du dépôt :

```powershell
powershell -ExecutionPolicy Bypass -File .\unreal\LITDValidation\Tools\Setup-UnrealPrototype.ps1
```

Le script détecte Unreal, génère le projet Visual Studio, compile et lance la salle. Options : `-BuildOnly`, `-SkipBuild` ou `-EngineRoot "D:\Epic Games\UE_5.8"`.

## Contrôles

- ZQSD/WASD ou stick gauche : déplacement ;
- E ou bouton inférieur : interaction ;
- clic gauche ou gâchette droite : attaque ;
- G ou bouton supérieur : cendres ;
- F8 : réinitialisation.

## Comparaison

La salle reprend les onze contrôles de Godot : mouvement, dialogue, coffre, butin, quatre ennemis, seuil de capture vert-cendre, consommables, psychologie, blessure persistante, cendres et snapshot isolé.

Les modèles sont procéduraux. Les mêmes GLB Blender devront ensuite être importés dans les deux moteurs. Renseigner `comparison_scorecard.json` sur le même PC, à la même résolution.

Aucun système de campagne ne doit être migré tant qu'Unreal n'apporte pas un avantage de production clair, au-delà de son éclairage par défaut.
