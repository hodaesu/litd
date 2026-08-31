# LITD 2 — Combat Core v1

## Règle d'architecture

**L'animation ne détermine jamais seule le gameplay.**

Le runtime C++ possède son propre temps d'action et décide des phases `Startup`, `Active`, `Recovery`, des fenêtres de cancel, du buffer d'input, des transitions de combo, de l'Équilibre, du ciblage, du démembrement et de l'éligibilité des finishers. Les Anim Montages sont une couche de présentation déclenchée par les événements du runtime.

Conséquence : remplacer une animation, modifier son play rate ou retoucher ses frames ne doit pas changer les règles de combat tant que les données de l'action ne sont pas volontairement modifiées.

## Influence de gameplay

- **Absolver** : grammaire d'attaques, transitions et profils distincts mains nues / armes. Les combos sont des graphes de données, pas des chaînes codées dans les animations.
- **Batman Arkham** : ciblage souple directionnel et transfert naturel entre adversaires, avec lock-on optionnel pour les duels.
- **Sekiro** : lecture de l'attaque, défense active, parade/esquive parfaite, pression sur l'Équilibre et ouverture de finisher.
- **LITD 2** : gore systémique, démembrement localisé, finishers courts, et transformations de run Corps / Esprit / Politique.

## Flux d'une action

1. L'input demande une action au `ULITDCombatRuntimeComponent`.
2. Le runtime choisit l'action data et démarre son chronomètre autoritaire.
3. `ULITDCombatAnimationBridgeComponent` écoute `OnActionStarted` et joue le Montage si celui-ci est chargé.
4. Le runtime ouvre/ferme les fenêtres (`Hit.Active`, `Cancel.Combo`, `Defense.Parry`, `Defense.Perfect`, `Dodge.Invulnerable`, etc.) d'après les secondes définies dans l'asset.
5. Les systèmes de dégâts/traces/VFX écoutent ces événements. Un AnimNotify peut servir à synchroniser un son, une caméra ou un effet visuel, mais ne rend jamais une attaque légale.
6. À la fin du temps gameplay, le runtime termine l'action même si l'animation visuelle est différente.

## Composants installés

### `ULITDCombatRuntimeComponent`
- chronomètre autoritaire ;
- startup / active / recovery ;
- buffer d'input ;
- fenêtres nommées ;
- transitions de combo ;
- registre d'actions data-driven.

### `ULITDCombatAnimationBridgeComponent`
Dépend du runtime dans un seul sens : **gameplay → animation**. Le runtime ne dépend jamais d'un AnimInstance, d'un Montage ou d'un Notify pour connaître la légalité d'une action.

### `ULITDTargetingComponent`
Base du freeflow : score direction du stick + caméra + distance. Le lock-on reste possible pour les élites et boss.

### `ULITDEquilibriumComponent`
Ressource de défense inspirée du principe de posture : dégâts d'Équilibre, rupture, fenêtre vulnérable et récupération. La rupture est un état gameplay, pas une animation de stagger.

### `ULITDGoreComponent`
État logique par zone corporelle : tête, torse, bras gauche/droit, jambe gauche/droite. Le composant décide si un membre est sectionné selon le trauma et le type de dégâts. Le Blueprint de présentation masque le membre, lance Niagara, détache le mesh et applique l'impulsion.

### `ULITDFinisherComponent`
Éligibilité basée sur PV, rupture d'Équilibre, distance et tags de contexte. Les Montages/Motion Warping sont exécutés après validation ; ils ne décident jamais si le finisher est disponible.

## Convention de fenêtres recommandée

- `Hit.Active` — traces de l'arme / poing actives.
- `Cancel.Combo` — transition vers le coup suivant.
- `Cancel.Dodge` — esquive autorisée.
- `Cancel.Parry` — parade autorisée.
- `Defense.Block` — garde normale.
- `Defense.Perfect` — fenêtre très courte de parade parfaite.
- `Dodge.Invulnerable` — invulnérabilité d'esquive.
- `Dodge.Perfect` — fenêtre d'esquive parfaite.
- `Target.Transfer` — changement de cible fluide autorisé.
- `Finisher.Commit` — verrouillage après validation logique du finisher.

## Réponses défensives prévues

| Menace | Réponse principale |
|---|---|
| Normal | parade ou esquive |
| Heavy | esquive ou parade coûteuse en Équilibre |
| Thrust | esquive latérale / déviation spécialisée |
| Sweep | retrait, saut ou franchissement selon le profil |
| Grab | déplacement, jamais garde normale |
| Supernatural | réponse définie par le pouvoir / build |

## Gore et finishers

Le hit fournit `DamageNature`, dommage santé, dommage d'Équilibre, force et zone touchée. Le gore logique décide : blessure, trauma, section possible. La présentation décide : sang, plaie, membre détaché, ragdoll/physical animation.

Un finisher standard demande par défaut :
- cible à moins de 25 % de PV ;
- Équilibre brisé ;
- distance compatible ;
- contexte requis présent.

Cela évite le spam : le joueur doit d'abord gagner l'ouverture par le combat.

## Tests de non-régression

`LITD.Combat.Core.AnimationIndependentTiming` vérifie explicitement que modifier le `PresentationPlayRate` ne change pas une fenêtre de cancel. D'autres tests couvrent rupture d'Équilibre, seuil de démembrement et éligibilité de finisher.

## Étape d'intégration au projet de combat réel

Ce noyau est volontairement indépendant des assets. Quand le projet de combat existant est raccordé :
- mapper ses inputs vers `ELITDCombatInput` ;
- créer les `ULITDCombatActionData` pour mains nues et chaque famille d'arme ;
- brancher ses traces/hitboxes sur `Hit.Active` ;
- brancher ses Montages sur le bridge ;
- brancher Motion Warping uniquement après validation d'un finisher ;
- connecter ensuite les Éveils Corps / Esprit / Politique aux événements gameplay, sans modifier les Montages de base.
