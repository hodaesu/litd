# LITD 2 — Unreal Engine

Projet Unreal séparé de LITD 1. Les mécaniques présentes ici sont propres à **LITD 2** et ne doivent pas être raccordées au projet Godot ou au prototype comparatif `LITDValidation` sans décision explicite.

## Fondation actuelle

La fondation C++ met en place les **Archives de Rémanence** :

- types de données pour les nœuds, sources, contradictions et reconstructions ;
- état de découverte persistant ;
- exigences de reconstruction avec sources alternatives ;
- déblocages de gameplay data-driven ;
- branche d'amorçage de Sarei décrite dans `Data/Remanence/sarei_seed.json` ;
- constellation UMG native interactive avec déplacement, zoom et dossier documentaire ;
- apparition progressive des fils, contradictions brisées, nœuds irréguliers et halos de catégorie ;
- ambiance procédurale de cendre/lumière et pulsations de nouvelles connaissances ;
- transition animée du dossier sélectionné ;
- révélation plein écran courte lors d'une reconstruction ;
- quatre slots audio optionnels : ouverture, sélection, contradiction et reconstruction ;
- direction sonore versionnée dans `Data/Remanence/archive_audio_direction.json`.

Le Widget Blueprint `WBP_RemembranceArchive` peut être généré dans Unreal à partir de la classe native. Les assets `.uasset`, sons définitifs, matériaux et contenus binaires restent à produire/importer dans l'éditeur Unreal ; la logique, la présentation native et les contrats de données sont versionnés ici.

## Premier vertical slice — Les Faubourgs de Sarei

La première run complète est désormais définie dans :

- `docs/LITD2/SAREI_FAUBOURGS_RUN.md` — structure canonique zone par zone, soins, traumatismes, rencontres, Rémanences, mini-boss, boss et retour aux Archives ;
- `Data/Runs/sarei_faubourgs_run.json` — contrat data-driven de l'opération pour l'implémentation Unreal.

La run part avec **3 potions**, ne permet aucun drop ennemi de potion, garde les soins ordinaires limités aux PV, et impose que Corps, Esprit et Politique puissent chacun vaincre le boss sans dépendre d'un build hybride. La première run découvre **Le Dernier Flacon** mais ne débloque pas prématurément la capacité de 4 potions ; le Rapport de Vel et le Coffret de la IIIe Armée restent réservés aux runs ultérieures de la branche.

## Runtime de run — squelette jouable data-driven

Le vertical slice possède maintenant un runtime C++ versionné dans `Source/LITD2/Run/` :

- `LITD2RunDirectorSubsystem` charge `sarei_faubourgs_run.json`, maintient l'état de la run et fait progresser Z0 → Z8 ;
- `LITD2EncounterDirectorSubsystem` lit les rencontres, branches, vagues, mini-boss et boss puis émet les requêtes de spawn destinées aux Blueprints/niveaux ;
- `LITD2RunInteractionActors` fournit des acteurs logiques pour fontaines, caches médicales, déclencheurs de Rémanence et portes de branche ;
- les événements Blueprint `OnZoneStarted`, `OnZoneCompleted`, `OnEnemySpawnRequested`, `OnWaveStarted`, `OnBossSpawnRequested`, `OnRemanenceDiscovered`, `OnBossPhaseChanged` et `OnRunCompleted` servent de points de branchement pour level design, VFX, audio et mise en scène.

Le contrat de santé du squelette respecte déjà les règles de Sarei : la fontaine remplit uniquement les PV récupérables, les traumatismes condamnent une partie des PV max, la potion efface tous les traumatismes, et une cache contextuelle ne remplace une potion que si la capacité n'est pas déjà pleine.

Le runtime transmet également les Rémanences découvertes au `LITD2RemembranceSubsystem`, ce qui permet au retour aux Archives de retrouver la connaissance acquise pendant la run.

Ce runtime est un **squelette de niveau jouable** : il orchestre la séquence, mais les acteurs ennemis définitifs, le système de combat complet, les animations, l'anatomie/gore et le level art restent à brancher/produire dans Unreal.

## Feuille de route de production officielle des Archives

La fabrication finale ne doit plus redécider l'architecture du système. Elle suit les trois contrats versionnés suivants :

- `docs/LITD2/REMANENCE_PRODUCTION_PACK.md` — direction artistique, UX, états de production, règles de droits et définition de terminé ;
- `Data/Remanence/archive_asset_manifest.json` — liste canonique des textures, matériaux, widgets, sons, FX et styles typographiques à produire ;
- `Data/Remanence/archive_validation_matrix.json` — validation obligatoire 1080p, 1440p, 4K, interaction, contenu, audio, performance, droits et séparation LITD 1/LITD 2.

Les statuts de production autorisés sont `TODO`, `READY`, `IMPLEMENTED`, `VALIDATED` et `BLOCKED`. Un asset ne devient `VALIDATED` qu'après vérification réelle dans Unreal Editor ou dans une build jouable.

## Principes verrouillés

- pas de boucle temporelle ;
- pas de monnaie de Rémanence ;
- la progression persistante porte d'abord sur les connaissances et les possibilités ;
- les reconstructions importantes acceptent des voies de preuve alternatives ;
- toute récompense de Rémanence explique sa cause historique ;
- la révélation d'une connaissance reste brève et ne devient jamais une fanfare de loot ;
- Corps, Esprit, Politique et Serments restent indépendants des Archives ;
- LITD 1 et LITD 2 restent techniquement et ludiquement séparés.
