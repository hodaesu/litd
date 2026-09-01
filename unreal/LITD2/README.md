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

La première run complète est définie dans :

- `docs/LITD2/SAREI_FAUBOURGS_RUN.md` — structure canonique zone par zone, soins, traumatismes, rencontres, Rémanences, mini-boss, boss et retour aux Archives ;
- `Data/Runs/sarei_faubourgs_run.json` — contrat data-driven de l'opération pour l'implémentation Unreal.

La run part avec **3 potions**, ne permet aucun drop ennemi de potion, garde les soins ordinaires limités aux PV, et impose que Corps, Esprit et Politique puissent chacun vaincre le boss sans dépendre d'un build hybride. La première run découvre **Le Dernier Flacon** mais ne débloque pas prématurément la capacité de 4 potions.

## Runtime de run

Le vertical slice possède un runtime C++ dans `Source/LITD2/Run/` :

- `LITD2RunDirectorSubsystem` charge `sarei_faubourgs_run.json`, maintient l'état de la run et fait progresser Z0 → Z8 ;
- `LITD2EncounterDirectorSubsystem` lit les rencontres, branches, vagues, mini-boss et boss puis émet les requêtes de spawn ;
- `LITD2RunInteractionActors` fournit fontaines, caches médicales, déclencheurs de Rémanence et portes de branche ;
- les événements Blueprint servent de points de branchement pour level design, VFX, audio et mise en scène.

Le runtime transmet les Rémanences découvertes au `LITD2RemembranceSubsystem` afin que le retour aux Archives retrouve la connaissance acquise pendant la run.

## Combat jouable — fondation actuelle

Le projet possède maintenant une couche de combat native dans `Source/LITD2/Combat/` :

- `LITD2CombatTypes` définit le langage commun des dégâts, zones anatomiques, blessures, traumatismes, parade/blocage et candidat au démembrement ;
- `LITD2CombatantComponent` gère PV, endurance, régénération, parade, blocage, esquive invulnérable, PV condamnés, trauma, blessure temporaire de saignement, mort et synchronisation avec la run ;
- `LITD2PlayerCombatCharacter` fournit déplacement troisième personne, caméra, attaque légère/lourde, esquive, parade/blocage, potion, montages d'animation et verrouillage externe bref pour les saisies télégraphiées ;
- `LITD2AnimNotify_CombatCommit` synchronise les vrais frames d'impact/libération avec le gameplay lorsque des montages sont assignés ;
- `LITD2AshWandererCharacter` est l'Errant cendré de base, volontairement interruptible ;
- `LITD2LineBreakerCharacter` est le premier lourd : son coup sévère télégraphié teste un Traumatisme I déterministe quand il est encaissé sans défense ;
- `LITD2SareiCrossbowCharacter` est la première menace à distance, avec maintien de distance, visée interruptible et libération synchronisée par notify ;
- `LITD2SareiBoltProjectile` fournit un vrai carreau physique qui peut manquer ou être esquivé et repasse par le pipeline de dégâts unifié ;
- `LITD2AlleyHarrierCharacter` fournit le flanker rapide des vagues multidirectionnelles de Z6 ;
- `LITD2GuardSurgeonCharacter` est le mini-boss Z5 : incision avec saignement temporaire, saisie télégraphiée, fenêtre d'interruption et frappe sévère traumatique ;
- `LITD2CombatGameMode` utilise le personnage de combat comme pawn par défaut du vertical slice ;
- `Config/DefaultInput.ini` rend la base immédiatement pilotable au clavier/souris.

La direction générale et les critères d'essai en éditeur sont dans `docs/LITD2/COMBAT_VERTICAL_SLICE.md`. Le contrat spécifique du mini-boss est dans `docs/LITD2/GUARD_SURGEON_MINIBOSS.md`.

Le contrat animation ↔ gameplay est dans `docs/LITD2/COMBAT_ANIMATION_CONTRACT.md` et `Data/Combat/animation_combat_contracts.json`. Le registre des classes d'ennemis du slice est dans `Data/Combat/enemy_runtime_registry.json`.

Le trauma reste strictement déterministe : aucune probabilité aléatoire ne peut en créer un. Une cause sévère doit être explicitement signalée, lisible et effectivement encaissée. Esquive et parade l'évitent ; le blocage réduit les dégâts et empêche également le trauma pour les attaques actuellement blocables. Une future attaque imblocable devra être définie explicitement comme telle.

Les fontaines restaurent uniquement les PV encore récupérables ; les potions suppriment les traumatismes et restaurent complètement le personnage. Les blessures temporaires comme le saignement restent conceptuellement distinctes du trauma : le runtime ne les transforme jamais en PV condamnés.

Quand aucun montage offensif n'est assigné, le runtime garde un fallback C++ pour permettre les tests sans assets binaires. Dès qu'un montage est assigné, l'impact appartient à `ULITD2AnimNotify_CombatCommit` : un montage offensif sans le notify requis est considéré comme incomplet au lieu d'être silencieusement compensé par un timer.

Les modèles, montages `.uasset`, VFX de gore/démembrement, sons, HUD et présentation finale du projectile restent à produire dans Unreal Editor.

## Feuille de route de production officielle des Archives

La fabrication finale suit les contrats versionnés suivants :

- `docs/LITD2/REMANENCE_PRODUCTION_PACK.md` ;
- `Data/Remanence/archive_asset_manifest.json` ;
- `Data/Remanence/archive_validation_matrix.json`.

Un asset ne devient `VALIDATED` qu'après vérification réelle dans Unreal Editor ou dans une build jouable.

## Principes verrouillés

- pas de boucle temporelle ;
- pas de monnaie de Rémanence ;
- la progression persistante porte d'abord sur les connaissances et les possibilités ;
- les reconstructions importantes acceptent des voies de preuve alternatives ;
- toute récompense de Rémanence explique sa cause historique ;
- la révélation d'une connaissance reste brève et ne devient jamais une fanfare de loot ;
- Corps, Esprit, Politique et Serments restent indépendants des Archives ;
- LITD 1 et LITD 2 restent techniquement et ludiquement séparés.
