# LITD 2 — Combat jouable du vertical slice

> Statut : **RUNTIME FOUNDATION / SAREI**  
> Portée : **LITD 2 uniquement**.

## Objectif

Cette fondation transforme le vertical slice de Sarei en boucle de combat contrôlable dans Unreal : déplacement troisième personne, caméra, endurance, attaque légère, attaque lourde, esquive avec courte fenêtre d'invulnérabilité, parade/blocage, potion, dégâts localisés et premier ennemi jouable.

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
- utilisation d'une potion synchronisée avec l'état de run.

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

Un traumatisme ne peut jamais apparaître via un jet aléatoire. Il exige explicitement `bReadableSevereCause = true` et un `TraumaValue` suffisant.

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

L'Errant cendré de base n'inflige volontairement aucun traumatisme : les premières attaques traumatiques appartiennent aux ennemis lourds lisibles comme le Briseur de ligne.

## Présentation encore à produire dans Unreal Editor

Le runtime est volontairement séparé des assets binaires. Restent notamment à fabriquer/importer :

- squelette/mesh définitif du personnage ;
- animations locomotion, attaques, esquive, parade et réactions ;
- montages et fenêtres d'attaque ;
- mesh/animations de l'Errant cendré ;
- VFX d'impact et gore ;
- démembrement visuel et contraintes de squelette ;
- sons d'armes, impacts, pas et réactions ;
- HUD PV/endurance/trauma/potions ;
- tuning à la manette et migration Enhanced Input si retenue.

## Critères du prochain test en éditeur

1. le joueur peut se déplacer et orienter la caméra sans conflit ;
2. attaque légère/lourde touchent un Errant cendré dans leur volume ;
3. l'endurance empêche le spam infini ;
4. l'esquive évite réellement une attaque pendant sa fenêtre ;
5. une parade annule les dégâts de l'Errant et augmente sa récupération ;
6. le blocage réduit les dégâts sans les annuler ;
7. la mort de l'Errant décrémente la rencontre Z1 ;
8. une fontaine ne supprime jamais les PV condamnés ;
9. une potion efface bien tous les traumatismes ;
10. aucun traumatisme ne peut être déclenché aléatoirement.
