# LITD 2 — Combat jouable du vertical slice

> Statut : **RUNTIME FOUNDATION / SAREI**  
> Portée : **LITD 2 uniquement**.

## Objectif

Cette fondation transforme le vertical slice de Sarei en boucle de combat contrôlable dans Unreal : déplacement troisième personne, caméra, endurance, attaque légère, attaque lourde, esquive avec courte fenêtre d'invulnérabilité, parade/blocage, potion, dégâts localisés et premiers ennemis jouables.

## Contrôles actuels

- `WASD` : déplacement ;
- souris : caméra ;
- clic gauche : attaque légère ;
- `E` : attaque lourde ;
- espace : esquive ;
- clic droit maintenu : parade initiale puis blocage ;
- `Q` : potion.

Ces mappings vivent dans `unreal/LITD2/Config/DefaultInput.ini` et pourront être migrés vers Enhanced Input quand les assets d'input définitifs seront produits dans Unreal Editor.

## Personnage jouable

`ALITD2PlayerCombatCharacter` fournit :

- caméra orbitale troisième personne ;
- déplacement orienté caméra ;
- vitesse et rotation adaptées au combat nerveux ;
- attaque légère et lourde via sweep de mêlée ;
- coûts d'endurance distincts ;
- esquive directionnelle avec fenêtre d'invulnérabilité courte ;
- parade à fenêtre courte, puis blocage moins efficace ;
- utilisation d'une potion synchronisée avec l'état de run ;
- slots `UAnimMontage` pour attaque légère, attaque lourde, esquive et parade ;
- validation des impacts offensifs par `AnimNotify` quand un montage est assigné.

`ALITD2CombatGameMode` utilise ce personnage comme pawn par défaut du projet de vertical slice.

## Synchronisation animation ↔ gameplay

`ULITD2AnimNotify_CombatCommit` est maintenant le point commun entre les montages offensifs et le runtime.

Quand aucun montage n'est assigné, le fallback C++ garde le prototype jouable. Dès qu'un montage offensif est assigné, le coup n'est plus validé par un timer caché : le montage doit contenir le notify correspondant au vrai frame de contact/libération.

Événements actuels :

- `PlayerQueuedAttack` ;
- `AshWandererAttack` ;
- `LineBreakerSevereAttack` ;
- `SareiCrossbowRelease`.

Contrat détaillé : `docs/LITD2/COMBAT_ANIMATION_CONTRACT.md`.  
Source data-driven : `unreal/LITD2/Data/Combat/animation_combat_contracts.json`.

## Pipeline de dégâts unifié

`FLITD2DamageEventPayload` transporte :

`DamageType → HitBone → HitDirection → DamageAmount → ImpactForce → Penetration → BleedValue → TraumaValue → DismembermentValue`.

`ULITD2CombatantComponent` résout ensuite :

1. zone anatomique ;
2. invulnérabilité d'esquive ;
3. parade ;
4. blocage ;
5. dégâts effectifs ;
6. blessure temporaire ;
7. traumatisme ;
8. candidat au démembrement ;
9. mort.

### Règle trauma

Un traumatisme ne peut jamais apparaître via un jet aléatoire. Il exige explicitement `bReadableSevereCause = true`, un `TraumaValue` suffisant et une attaque réellement encaissée.

Une parade ou un blocage réussi marque l'impact comme défendu : l'attaque peut encore infliger les dégâts réduits prévus par le blocage, mais elle ne déclenche ni blessure grave, ni traumatisme, ni démembrement candidat. Les attaques futures explicitement « imblocables » devront le déclarer comme une mécanique propre, jamais contourner cette règle accidentellement.

Les traumatismes condamnent une portion de PV récupérables. Le composant de combat et le `RunDirector` conservent le même langage d'état.

### Soin

- fontaine : remonte jusqu'aux PV encore récupérables, sans effacer le traumatisme ;
- potion : consomme une charge de run, supprime tous les traumatismes et restaure les PV complets ;
- la cache médicale ne dépasse jamais la capacité de potion.

## Premier ennemi — Errant cendré

`ALITD2AshWandererCharacter` est le premier ennemi relié au pipeline.

Il :

- détecte le joueur ;
- s'approche ;
- déclenche un télégraphe avant attaque ;
- utilise `AttackMontage` + `AshWandererAttack` lorsque l'animation est assignée ;
- reste testable avec son windup C++ si aucun montage n'est assigné ;
- est interruptible par une pression offensive propre ;
- réagit à une parade par une récupération prolongée ;
- expose des hooks Blueprint pour hit reaction, gore/démembrement candidat, télégraphe, parade et mort ;
- signale sa mort à `ULITD2EncounterDirectorSubsystem` sous l'ID `ASH_WANDERER`.

L'Errant cendré de base n'inflige volontairement aucun traumatisme.

## Deuxième ennemi — Briseur de ligne

`ALITD2LineBreakerCharacter` valide une **attaque traumatique lourde mais entièrement lisible**.

Identité de gameplay actuelle :

- déplacement plus lent et silhouette de lourd ;
- environ 720 PV de tuning initial, sans logique de sac à PV ;
- portée courte ;
- télégraphe sévère ciblé à **1,10 s** ;
- récupération de **1,55 s** ;
- attaque contondante à 145 dégâts avant défense ;
- `ImpactForce = 0.92` ;
- `TraumaValue = 0.58` ;
- `bReadableSevereCause = true` ;
- `SevereAttackMontage` validé au contact par `LineBreakerSevereAttack` lorsqu'il est assigné ;
- engagement lourd : les réactions normales de hit ne cassent pas sa frappe sévère.

`TraumaValue = 0.58` est une valeur de tuning du vertical slice, pas une constante narrative sacrée. Avec les seuils actuels, un coup sévère non défendu produit **Traumatisme I** et condamne environ **10 % des PV max**.

### Matrice défensive attendue

- esquive pendant l'invulnérabilité : aucun dégât, aucun traumatisme ;
- parade dans la fenêtre : aucun dégât, aucun traumatisme, récupération du Briseur fortement prolongée ;
- blocage après la fenêtre de parade : dégâts réduits, mais aucun traumatisme ;
- coup sévère encaissé sans défense : dégâts complets + Traumatisme I ;
- fontaine après le coup : restaure seulement jusqu'au nouveau maximum récupérable ;
- potion : efface le traumatisme et rend le maximum de PV complet.

La mort du Briseur est transmise au `EncounterDirector` sous l'ID `LINE_BREAKER`, ce qui le raccorde directement aux rencontres Z2, Z4 et Z6 déjà définies dans Sarei.

## Troisième ennemi — Arbalétrier de Sarei

`ALITD2SareiCrossbowCharacter` introduit la première pression à distance réellement jouable.

Identité actuelle :

- environ 230 PV ;
- portée d'aggro 1750 unités ;
- cherche une distance de travail d'environ **560–1050 unités** ;
- recule si le joueur ferme la distance ;
- avance s'il est trop loin ;
- visée lisible d'environ **0,82 s** ;
- récupération d'environ **1,55 s** ;
- un coup reçu pendant la visée interrompt le tir ;
- `AimAndFireMontage` utilise `SareiCrossbowRelease` lorsqu'il est assigné ;
- le tir crée un vrai `ALITD2SareiBoltProjectile`, pas un dommage hitscan instantané ;
- la mort est transmise sous l'ID `SAREI_CROSSBOW`.

Le carreau voyage à grande vitesse et repasse par `ULITD2CombatantComponent` en cas de collision. Son tuning de base inflige 92 dégâts perforants, mais **aucun traumatisme** : sa fonction est de créer de la pression de positionnement, pas de dupliquer le rôle du Briseur.

Les rencontres Z2, la branche `GLASSMAKERS_STREET` de Z4 et les vagues de Z6 contiennent déjà `SAREI_CROSSBOW` dans le contrat de run.

Le registre runtime correspondant est `unreal/LITD2/Data/Combat/enemy_runtime_registry.json`.

## Présentation encore à produire dans Unreal Editor

Restent notamment à fabriquer/importer :

- squelette/mesh définitif du personnage ;
- locomotion et montages définitifs ;
- animations propres de l'Errant, du Briseur et de l'Arbalétrier ;
- placement des `LITD2 Combat Commit` aux vrais frames de contact/libération ;
- mesh/traînée/VFX du carreau d'arbalète ;
- VFX d'impact et gore ;
- démembrement visuel et contraintes de squelette ;
- sons d'armes, impacts, pas, mécanisme d'arbalète et réactions ;
- HUD PV/endurance/trauma/potions ;
- tuning à la manette et migration Enhanced Input si retenue.

## Critères du prochain test en éditeur

1. le joueur peut se déplacer et orienter la caméra sans conflit ;
2. attaque légère/lourde appliquent leur sweep exactement au notify lorsque leurs montages sont assignés ;
3. une esquive/parade avant le notify annule un coup joueur encore en attente ;
4. l'Errant peut être interrompu pendant sa préparation sans rester bloqué dans un état d'attaque ;
5. le Briseur conserve sa frappe sévère malgré une réaction de hit normale ;
6. l'esquive évite réellement l'attaque lourde du Briseur pendant sa fenêtre ;
7. une parade annule le coup sévère et prolonge fortement sa récupération ;
8. un blocage réduit les dégâts du coup sévère sans produire de traumatisme ;
9. un coup sévère non défendu produit Traumatisme I et condamne environ 10 % des PV max ;
10. l'Arbalétrier recule au contact, télégraphie son tir et libère le carreau au notify ;
11. un carreau peut manquer ou être évité et ne produit jamais de traumatisme de base ;
12. une fontaine restaure uniquement les PV encore récupérables après un traumatisme ;
13. une potion efface le traumatisme et restaure le maximum complet ;
14. les morts `ASH_WANDERER`, `LINE_BREAKER` et `SAREI_CROSSBOW` décrémentent correctement les rencontres ;
15. aucun traumatisme ne peut être déclenché aléatoirement.
