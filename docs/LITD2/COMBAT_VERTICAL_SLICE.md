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
- premiers slots `UAnimMontage` optionnels pour attaque légère, attaque lourde, esquive et parade.

`ALITD2CombatGameMode` utilise ce personnage comme pawn par défaut du projet de vertical slice.

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

Une parade ou un blocage réussi marque désormais l'impact comme défendu : l'attaque peut encore infliger les dégâts réduits prévus par le blocage, mais elle ne déclenche ni blessure grave, ni traumatisme, ni démembrement candidat. Les attaques futures explicitement « imblocables » devront le déclarer comme une mécanique propre, jamais contourner cette règle accidentellement.

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
- frappe après un windup lisible ;
- entre en récupération ;
- subit les attaques du joueur ;
- réagit à une parade par une récupération prolongée ;
- expose des hooks Blueprint pour hit reaction, gore/démembrement candidat, télégraphe, parade et mort ;
- signale sa mort à `ULITD2EncounterDirectorSubsystem` sous l'ID `ASH_WANDERER`.

L'Errant cendré de base n'inflige volontairement aucun traumatisme.

## Deuxième ennemi — Briseur de ligne

`ALITD2LineBreakerCharacter` est le premier ennemi conçu pour valider une **attaque traumatique lourde mais entièrement lisible**.

Identité de gameplay actuelle :

- déplacement plus lent et silhouette de lourd ;
- environ 720 PV de tuning initial, sans logique de sac à PV ;
- portée courte ;
- windup sévère de **1,10 s** ;
- récupération de **1,55 s** ;
- attaque contondante à 145 dégâts avant défense ;
- `ImpactForce = 0.92` ;
- `TraumaValue = 0.58` ;
- `bReadableSevereCause = true`.

`TraumaValue = 0.58` est une **valeur de tuning du vertical slice**, pas une constante narrative sacrée. Avec les seuils actuels, un coup sévère non défendu produit **Traumatisme I** et condamne environ **10 % des PV max**.

### Matrice défensive attendue

- esquive pendant l'invulnérabilité : aucun dégât, aucun traumatisme ;
- parade dans la fenêtre : aucun dégât, aucun traumatisme, récupération du Briseur fortement prolongée ;
- blocage après la fenêtre de parade : dégâts réduits, mais aucun traumatisme ;
- coup sévère encaissé sans défense : dégâts complets + Traumatisme I ;
- fontaine après le coup : restaure seulement jusqu'au nouveau maximum récupérable ;
- potion : efface le traumatisme et rend le maximum de PV complet.

La mort du Briseur est transmise au `EncounterDirector` sous l'ID `LINE_BREAKER`, ce qui le raccorde directement aux rencontres Z2, Z4 et Z6 déjà définies dans Sarei.

## Première branche des animations / montages

Le joueur expose maintenant des slots :

- `LightAttackMontage` ;
- `HeavyAttackMontage` ;
- `DodgeMontage` ;
- `ParryMontage`.

Le Briseur expose :

- `SevereAttackMontage` ;
- `HitReactionMontage` ;
- `DeathMontage`.

Le code joue automatiquement ces montages lorsqu'ils sont assignés. Les véritables assets `.uasset` restent à créer/importer dans Unreal Editor.

Pour cette étape, le moment d'impact reste déterminé par le timer C++ de windup afin que le gameplay fonctionne sans asset d'animation. **Le prochain passage animation devra déplacer la validation du hit vers un `AnimNotify`/une fenêtre de montage**, afin que l'image et le moment réel de l'impact deviennent exactement synchronisés.

## Présentation encore à produire dans Unreal Editor

Restent notamment à fabriquer/importer :

- squelette/mesh définitif du personnage ;
- locomotion et montages définitifs ;
- animations propres de l'Errant et du Briseur de ligne ;
- `AnimNotify` d'ouverture/fermeture des fenêtres de frappe ;
- VFX d'impact et gore ;
- démembrement visuel et contraintes de squelette ;
- sons d'armes, impacts, pas et réactions ;
- HUD PV/endurance/trauma/potions ;
- tuning à la manette et migration Enhanced Input si retenue.

## Critères du prochain test en éditeur

1. le joueur peut se déplacer et orienter la caméra sans conflit ;
2. attaque légère/lourde touchent un ennemi dans leur volume ;
3. l'endurance empêche le spam infini ;
4. l'esquive évite réellement l'attaque lourde du Briseur pendant sa fenêtre ;
5. une parade annule le coup sévère et prolonge fortement sa récupération ;
6. un blocage réduit les dégâts du coup sévère sans produire de traumatisme ;
7. un coup sévère non défendu produit Traumatisme I et condamne environ 10 % des PV max ;
8. une fontaine restaure uniquement les PV encore récupérables après ce traumatisme ;
9. une potion efface le traumatisme et restaure le maximum complet ;
10. la mort du Briseur décrémente correctement une rencontre `LINE_BREAKER` ;
11. les montages assignés sont joués sans modifier les règles de combat ;
12. aucun traumatisme ne peut être déclenché aléatoirement.
