# LITD 2 — Le Chirurgien de garde

> Statut : **RUNTIME FOUNDATION / MINI-BOSS SAREI**  
> Portée : **LITD 2 uniquement**.

## Rôle

`ALITD2GuardSurgeonCharacter` est le mini-boss de `Z5_HOSPITAL_ANNEX`. Il ne doit pas être traité comme un « médecin fou » caricatural : son langage de combat vient de gestes précis, d'outils médicaux détournés et d'une connaissance anatomique utilisée sous pression.

Son but de gameplay est de tester quatre compétences déjà prévues pour Sarei :

1. gérer une blessure temporaire de saignement ;
2. lire une saisie avant qu'elle ne verrouille brièvement le mouvement ;
3. reconnaître et exploiter une fenêtre d'interruption ;
4. répondre à une attaque sévère capable de produire un traumatisme lisible.

## Cycle d'actions

Le prototype emploie volontairement un cycle déterministe `INCISION → GRAB → SEVERE_STRIKE` afin de rendre le comportement testable et lisible avant l'ajout futur d'une sélection tactique plus riche.

### INCISION

- dégâts directs : 76 ;
- windup cible : 0,46 s ;
- récupération : 0,68 s ;
- `BleedValue = 0.88` ;
- aucun traumatisme ;
- si l'impact n'est ni bloqué ni paré, il produit une blessure temporaire de saignement ;
- tuning actuel du saignement : **9 PV/s pendant 5 s** ;
- le saignement est une blessure temporaire et ne condamne pas les PV max ;
- un nouveau saignement rafraîchit/renforce le plus fort effet actif au lieu de s'empiler sans limite.

### GRAB

- dégâts directs : 58 ;
- windup cible : 0,82 s ;
- récupération : 1,05 s ;
- aucun traumatisme ;
- contact non défendu : verrouille le mouvement du joueur **0,45 s** ;
- blocage ou parade : empêche le verrouillage ;
- le verrou annule une attaque joueur encore en attente et coupe le blocage actif ;
- la caméra reste contrôlable afin que la saisie ne transforme pas le jeu en cinématique forcée.

### SEVERE_STRIKE

- dégâts directs : 155 ;
- windup cible : 1,25 s ;
- récupération : 1,60 s ;
- `ImpactForce = 0.90` ;
- `TraumaValue = 0.63` ;
- `bReadableSevereCause = true` ;
- contact non défendu : peut produire **Traumatisme I** avec les seuils actuels ;
- blocage/parade : aucun traumatisme, conformément au pipeline commun.

## Fenêtre d'interruption

Au début d'une action, le Chirurgien ouvre une fenêtre d'environ **0,58 s**. Les dégâts reçus pendant cette fenêtre s'accumulent.

- seuil actuel : **115 dégâts** ;
- une attaque lourde joueur de base suffit donc à casser une préparation ;
- deux attaques légères rapides peuvent également atteindre le seuil ;
- une fois la fenêtre fermée, le geste est engagé et les dégâts ordinaires ne l'annulent plus ;
- interruption réussie : annule le montage/action en cours et impose environ **1,75 s** de récupération.

Cette règle prépare directement les trois voies de build : Corps pourra casser par pression/impact, Esprit par contrôle/état, Politique par Condamnation/Autorité/tempo quand leurs pouvoirs runtime seront branchés.

## Animation ↔ gameplay

Le mini-boss utilise `ULITD2AnimNotify_CombatCommit` :

- `GuardSurgeonIncision` ;
- `GuardSurgeonGrab` ;
- `GuardSurgeonSevereStrike`.

Les montages correspondants sont :

- `IncisionMontage` ;
- `GrabMontage` ;
- `SevereStrikeMontage` ;
- `InterruptedMontage` ;
- `HitReactionMontage` ;
- `DeathMontage`.

Sans montage assigné, le fallback C++ garde le mini-boss testable. Avec montage, le vrai frame d'impact est le notify : aucune seconde validation cachée ne doit doubler le coup.

## Blessure de saignement

`ULITD2CombatantComponent` possède désormais une blessure temporaire de saignement :

- `ApplyTemporaryBleed(DamagePerSecond, DurationSeconds)` ;
- `ClearTemporaryBleed()` ;
- `IsBleeding()` ;
- dégâts appliqués progressivement aux PV ;
- synchronisation des dégâts entiers avec le `RunDirector` quand le composant appartient au joueur ;
- le saignement ne crée jamais de traumatisme ;
- fontaine et potion ne suppriment pas implicitement cette blessure dans cette étape : la distinction Blessure / Traumatisme reste conservée.

## Sortie de rencontre

À sa mort, le mini-boss signale :

`SAREI_GUARD_SURGEON`

au `ULITD2EncounterDirectorSubsystem`, ce qui permet à Z5 de progresser sans logique spécifique codée dans le niveau.

## Critères de validation en Unreal Editor

1. l'incision ne saigne que si le coup est réellement encaissé ;
2. le saignement retire progressivement des PV sans condamner le maximum ;
3. blocage/parade empêchent le saignement ciblé ;
4. la saisie est clairement télégraphiée ;
5. une saisie non défendue bloque le mouvement environ 0,45 s mais laisse la caméra libre ;
6. blocage/parade empêchent le verrouillage ;
7. une lourde joueur pendant la fenêtre d'interruption annule l'action ;
8. après 0,58 s, la même pression ne doit plus annuler automatiquement l'action engagée ;
9. la frappe sévère non défendue produit Traumatisme I avec le tuning actuel ;
10. blocage/parade empêchent ce traumatisme ;
11. chaque montage applique son gameplay au bon notify ;
12. la mort du Chirurgien décrémente correctement `SAREI_GUARD_SURGEON` dans Z5.
