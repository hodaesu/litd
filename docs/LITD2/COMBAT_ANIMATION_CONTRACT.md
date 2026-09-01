# LITD 2 — Contrat animation ↔ combat

> Portée : **LITD 2 / vertical slice de Sarei**  
> Objectif : faire coïncider l'image, le télégraphe et l'instant réel où le gameplay applique un impact.

## Principe

Le runtime ne doit plus appliquer un coup au milieu d'un montage simplement parce qu'un timer C++ arrive à zéro.

Dès qu'un montage d'attaque est assigné, le moment de contact appartient à l'animation via `ULITD2AnimNotify_CombatCommit`.

Si aucun montage n'est assigné, le fallback C++ reste actif afin que le prototype demeure testable sans assets binaires Unreal.

Conséquence importante : **un montage d'attaque assigné sans le bon notify est un asset invalide**. Il ne doit pas produire de dégâts par un timer caché qui masquerait l'erreur d'intégration.

La source data-driven de ces contrats est `unreal/LITD2/Data/Combat/animation_combat_contracts.json`.

## Notify partagé

Classe : `ULITD2AnimNotify_CombatCommit`

Événements disponibles :

- `PlayerQueuedAttack` ;
- `AshWandererAttack` ;
- `LineBreakerSevereAttack` ;
- `SareiCrossbowRelease`.

Chaque notify délègue au propriétaire du Skeletal Mesh. Le code de dégâts reste dans le personnage/composant de combat, jamais dans l'asset animation lui-même.

Cela conserve un pipeline unique : animation → commit → `FLITD2DamageEventPayload` → anatomie/défense/blessure/trauma/gore.

## Joueur

### Attaque légère

Slot : `LightAttackMontage`  
Notify : `PlayerQueuedAttack`  
Cible de timing initiale : contact vers **0,19 s** dans un montage d'environ **0,48 s**.

L'entrée consomme l'endurance et met le coup en attente. Le sweep réel n'est exécuté qu'au notify.

Une esquive ou une parade déclenchée avant ce notify annule le coup en attente. On obtient donc un vrai choix entre engagement et annulation défensive, sans « hit fantôme » après interruption de l'animation.

### Attaque lourde

Slot : `HeavyAttackMontage`  
Notify : `PlayerQueuedAttack`  
Cible initiale : contact vers **0,39 s** dans un montage d'environ **0,82 s**.

Même contrat que l'attaque légère, avec préparation et récupération plus lisibles.

### Esquive et parade

Les montages `DodgeMontage` et `ParryMontage` sont déjà branchés, mais leurs fenêtres de gameplay restent pour l'instant déclenchées à l'input :

- esquive : `DodgeInvulnerabilitySeconds = 0.22` ;
- parade : `ParryWindowSeconds = 0.18`.

Une future passe pourra transformer ces fenêtres en `AnimNotifyState` si le motion matching / montage final l'exige. Ce n'est pas nécessaire pour supprimer le décalage actuel des impacts offensifs.

## Errant cendré

Slot : `AttackMontage`  
Notify : `AshWandererAttack`  
Contact cible : **0,48 s**.

L'Errant est volontairement interruptible. Un coup propre reçu pendant son armement annule sa frappe en attente, joue éventuellement sa réaction d'impact et impose une courte récupération.

Cette règle donne au joueur un premier ennemi sur lequel apprendre la pression offensive sans rendre tous les adversaires annulables.

## Briseur de ligne

Slot : `SevereAttackMontage`  
Notify : `LineBreakerSevereAttack`  
Impact cible : **1,10 s**.

Le Briseur conserve sa logique d'engagement lourd : une réaction de hit normale ne doit pas interrompre le montage sévère. Son attaque traumatique reste donc évitable/parrable grâce à son télégraphe, mais pas neutralisable par un simple coup léger au dernier instant.

Le notify ne décide jamais du traumatisme. Il déclenche seulement l'impact. Le `CombatantComponent` décide ensuite, avec la règle canonique : cause sévère lisible + attaque non défendue + valeur de trauma suffisante.

## Arbalétrier de Sarei

Slot : `AimAndFireMontage`  
Notify : `SareiCrossbowRelease`  
Libération cible : **0,82 s**.

Le notify ne touche pas instantanément le joueur. Il **libère réellement un projectile** `ALITD2SareiBoltProjectile`.

Le carreau :

- voyage physiquement ;
- peut manquer sa cible ;
- peut être évité par l'esquive ;
- passe par le même `CombatantComponent` s'il touche ;
- inflige des dégâts perforants ;
- ne produit aucun traumatisme dans son tuning de base.

L'Arbalétrier cherche à maintenir une distance de combat, recule si le joueur arrive au contact et avance s'il se trouve trop loin. Le fait de réussir à l'atteindre interrompt sa visée : le contre-jeu naturel de cette unité est donc la mobilité et la pression.

## Convention de fabrication dans Unreal Editor

Pour chaque montage offensif :

1. créer/assigner le montage au Blueprint dérivé de la classe native ;
2. vérifier que l'anticipation correspond au télégraphe attendu ;
3. placer `LITD2 Combat Commit` au vrai frame de contact/libération ;
4. sélectionner le `CommitEvent` correspondant ;
5. tester au ralenti que le visuel et le résultat de gameplay sont simultanés ;
6. vérifier interruption, esquive, parade, blocage et mort pendant le montage ;
7. ne valider l'asset qu'après un test réel dans l'éditeur ou une build.

## Règle de sécurité de production

Le timer C++ est uniquement un fallback **sans montage**. Dès qu'un montage existe, aucun timer ne doit produire silencieusement l'impact à sa place.

Cette règle empêche qu'un changement de vitesse d'animation, de retargeting, de montage ou de frame rate désynchronise la lame/le marteau/le carreau du moment où le joueur reçoit réellement les dégâts.
