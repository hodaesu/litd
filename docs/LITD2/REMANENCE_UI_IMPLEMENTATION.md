# LITD 2 — Implémentation de l'interface des Archives de Rémanence

Ce document décrit l'implémentation Unreal de l'écran des Archives. Il complète `REMANENCE_ARCHIVES.md` sans modifier les règles canoniques du système.

## État actuel

La première version jouable est portée par `ULITD2RemembranceArchiveScreen`, un `UUserWidget` natif. Le rendu, la navigation et la reconstruction vivent en C++ afin de disposer d'un écran fonctionnel même avant la création manuelle des assets UMG binaires.

Le Widget Blueprint `WBP_RemembranceArchive` est un enfant léger de cette classe native. Il sert de point d'entrée UMG pour les artistes et peut recevoir plus tard animations, matériaux, icônes et mise en page finale sans dupliquer la logique de données.

## Fonctionnalités implémentées

- constellation documentaire interactive ;
- déplacement de la vue par glisser-déposer ;
- zoom autour du curseur à la molette ;
- sélection d'un nœud et dossier latéral ;
- états `INCONNU`, `TRACE`, `DOCUMENTÉ`, `RECONSTRUIT`, `CONTESTÉ` ;
- couleurs par famille documentaire ;
- relations normales sous forme de fils discrets ;
- contradictions sous forme de liens rouges brisés ;
- masquage des connaissances non découvertes, sauf silhouettes explicitement visibles ;
- bouton de reconstruction lorsqu'un ensemble de preuves est satisfait ;
- animation de pulsation or vieilli sur le résultat d'une reconstruction ;
- sauvegarde automatique des Archives après reconstruction ;
- disposition de la branche Sarei pilotée par `sarei_ui_layout.json` ;
- repli automatique vers une disposition radiale si le fichier de layout est absent.

## Fichiers principaux

- `unreal/LITD2/Source/LITD2/Remanence/UI/LITD2RemembranceArchiveScreen.h`
- `unreal/LITD2/Source/LITD2/Remanence/UI/LITD2RemembranceArchiveScreen.cpp`
- `unreal/LITD2/Data/Remanence/sarei_seed.json`
- `unreal/LITD2/Data/Remanence/sarei_ui_layout.json`
- `unreal/LITD2/Content/Python/build_remanence_ui.py`
- `unreal/LITD2/Tools/Build-RemanenceUI.ps1`

## Génération du Widget Blueprint

Sur un PC équipé d'Unreal Engine 5.8 :

```powershell
powershell -ExecutionPolicy Bypass -File .\unreal\LITD2\Tools\Build-RemanenceUI.ps1
```

Le script :

1. détecte Unreal Engine ;
2. génère les fichiers projet ;
3. compile `LITD2Editor` ;
4. exécute le script Python dans Unreal Editor en mode commande ;
5. produit `/Game/UI/Remanence/WBP_RemembranceArchive` ;
6. vérifie que le `.uasset` a bien été créé ;
7. ouvre ensuite l'éditeur, sauf avec `-NoLaunch`.

Options utiles :

```powershell
# moteur installé dans un dossier non standard
.\unreal\LITD2\Tools\Build-RemanenceUI.ps1 -EngineRoot "D:\Epic Games\UE_5.8"

# ne pas recompiler si LITD2Editor vient déjà d'être compilé
.\unreal\LITD2\Tools\Build-RemanenceUI.ps1 -SkipBuild

# générer l'asset sans ouvrir l'éditeur après coup
.\unreal\LITD2\Tools\Build-RemanenceUI.ps1 -NoLaunch
```

## Contrôles de la première version

- clic sur un nœud : inspecter ;
- glisser sur le fond de la constellation : déplacer la vue ;
- molette : zoomer/dézoomer autour du curseur ;
- bouton `RECONSTRUIRE` dans le dossier latéral : appliquer la première reconstruction actuellement satisfaisable.

## Séparation LITD Universe

Cette interface et ses mécaniques sont spécifiques à **LITD 2**. Les données de référence et bibliothèques réutilisables restent centralisées au niveau LITD Universe, mais ce système d'Archives ne doit pas être injecté dans le gameplay de LITD 1 sans décision explicite.
