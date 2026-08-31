# LITD 2 — Combat Core v1

## Règle d'architecture

**L'animation ne détermine jamais seule le gameplay.**

Le runtime C++ possède son propre temps d'action et décide des phases `Startup`, `Active`, `Recovery`, des fenêtres de cancel, du buffer d'input, de l'Équilibre, du ciblage, du démembrement et de l'éligibilité des finishers. Les Anim Montages sont une couche de présentation déclenchée par les événements du runtime.

Conséquence : remplacer une animation, modifier son play rate ou retoucher ses frames ne doit pas changer les règles de combat tant que les données de l'action ne sont pas volontairement modifiées.

## Vocabulaire de combat joueur

Le système volontairement simple repose sur cinq entrées seulement :

- **attaque légère** ;
- **attaque lourde** ;
- **parade** ;
- **esquive** ;
- **attaque de compétence**.

Il n'y a **aucun système de posture**, aucun changement de posture et aucun Combat Deck à quatre orientations.

Les enchaînements éventuels restent simples et data-driven : par exemple légère → légère, légère → lourde ou esquive → attaque de compétence, uniquement quand la fenêtre correspondante est ouverte.

## Armes

La partie armes est conservée et devient le principal moyen de différencier les styles de combat.

Chaque arme ou famille d'armes possède un `ULITDWeaponCombatData` pouvant fournir :

- sa propre attaque légère ;
- sa propre attaque lourde ;
- sa propre parade si nécessaire ;
- sa propre esquive si nécessaire ;
- éventuellement une attaque de compétence propre à l'arme ;
- ses actions, portées, timings, dégâts, dégâts d'Équilibre et propriétés de hit.

Équiper une arme ne change donc pas les commandes du joueur : cela change **la manière dont ces cinq commandes sont exécutées**.

Exemple :

| Entrée | Sabre | Masse | Lance |
|---|---|---|---|
| Légère | taille rapide | frappe courte | estoc rapide |
| Lourde | taille engagée | écrasement | estoc puissant |
| Parade | déviation | garde lourde | déviation du manche |
| Esquive | esquive standard | esquive plus lourde | retrait rapide |
| Compétence | coupe spéciale | choc au sol | charge/perforation |

## Influences conservées

- **Batman Arkham** : ciblage souple directionnel et transfert naturel entre adversaires, avec lock-on optionnel pour les duels.
- **Sekiro** : lecture de l'attaque, défense active, parade/esquive parfaite, pression sur l'Équilibre et ouverture de finisher.
- **LITD 2** : armes différenciées, attaques de compétences, gore systémique, démembrement localisé et finishers courts.

L'inspiration Absolver est limitée à une idée générale : **les armes doivent réellement changer le ressenti et les attaques**, pas à son système de postures ou de Combat Deck.

## Flux d'une action

1. L'input demande une action au `ULITDCombatRuntimeComponent`.
2. Si une arme est équipée, le runtime demande d'abord au `ULITDWeaponCombatData` quelle action correspond à l'entrée.
3. Si l'arme ne fournit pas cette action, le runtime utilise le registre global, notamment pour les compétences générales.
4. Le runtime démarre son chronomètre autoritaire.
5. `ULITDCombatAnimationBridgeComponent` écoute `OnActionStarted` et joue le Montage si celui-ci est chargé.
6. Le runtime ouvre/ferme les fenêtres (`Hit.Active`, `Cancel.Attack`, `Defense.Parry`, `Defense.Perfect`, `Dodge.Invulnerable`, etc.) d'après les secondes définies dans l'asset.
7. Les systèmes de dégâts/traces/VFX écoutent ces événements. Un AnimNotify peut synchroniser un son, une caméra ou un effet visuel, mais ne rend jamais une attaque légale.
8. À la fin du temps gameplay, le runtime termine l'action même si l'animation visuelle est différente.

## Composants installés

### `ULITDCombatRuntimeComponent`
- chronomètre autoritaire ;
- startup / active / recovery ;
- buffer d'input ;
- fenêtres nommées ;
- transitions simples ;
- registre d'actions global ;
- profil d'arme équipée.

### `ULITDWeaponCombatData`
Associe une arme aux cinq commandes de base sans introduire de posture. Les armes peuvent donc avoir des movesets très différents tout en gardant les mêmes contrôles.

### `ULITDCombatAnimationBridgeComponent`
Dépend du runtime dans un seul sens : **gameplay → animation**. Le runtime ne dépend jamais d'un AnimInstance, d'un Montage ou d'un Notify pour connaître la légalité d'une action.

### `ULITDTargetingComponent`
Base du freeflow : score direction du stick + caméra + distance. Le lock-on reste possible pour les élites et boss.

### `ULITDEquilibriumComponent`
Dégâts d'Équilibre, rupture, fenêtre vulnérable et récupération. La rupture est un état gameplay, pas une animation de stagger.

### `ULITDGoreComponent`
État logique par zone corporelle : tête, torse, bras gauche/droit, jambe gauche/droite. Le composant décide si un membre est sectionné selon le trauma et le type de dégâts. Le Blueprint de présentation masque le membre, lance Niagara, détache le mesh et applique l'impulsion.

### `ULITDFinisherComponent`
Éligibilité basée sur PV, rupture d'Équilibre, distance et tags de contexte. Les finishers ne sont pas une sixième commande permanente : ils sont déclenchés uniquement lorsqu'une ouverture contextuelle valide existe.

## Convention de fenêtres recommandée

- `Hit.Active` — traces de l'arme actives.
- `Cancel.Attack` — légère/lourde suivante autorisée.
- `Cancel.Dodge` — esquive autorisée.
- `Cancel.Parry` — parade autorisée.
- `Cancel.Skill` — attaque de compétence autorisée.
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
| Thrust | esquive latérale ou parade parfaite |
| Sweep | esquive/retrait |
| Grab | esquive, jamais garde normale |
| Supernatural | esquive ou réponse fournie par une compétence |

## Gore et finishers

Le hit fournit `DamageNature`, dommage santé, dommage d'Équilibre, force et zone touchée. Le gore logique décide : blessure, trauma, section possible. La présentation décide : sang, plaie, membre détaché, ragdoll/physical animation.

Un finisher standard demande par défaut : cible suffisamment affaiblie, Équilibre brisé, distance compatible et contexte requis présent. Il ne complexifie pas les commandes normales du joueur.

## Tests de non-régression

`LITD.Combat.Core.AnimationIndependentTiming` vérifie qu'un changement de `PresentationPlayRate` ne change pas une fenêtre gameplay.

`LITD.Combat.Core.WeaponProfileInputs` vérifie que le profil d'arme répond bien uniquement aux cinq entrées prévues : légère, lourde, parade, esquive et attaque de compétence.

Les autres tests couvrent défense, rupture d'Équilibre, seuil de démembrement et éligibilité de finisher.

## Étape d'intégration au projet de combat réel

- mapper uniquement les cinq inputs vers `ELITDCombatInput` ;
- créer un `ULITDWeaponCombatData` par arme ou famille d'armes ;
- créer les `ULITDCombatActionData` correspondantes ;
- brancher les traces/hitboxes sur `Hit.Active` ;
- brancher les Montages sur le bridge ;
- connecter les attaques de compétences au registre global ou au profil d'arme quand elles sont spécifiques à celle-ci ;
- garder Équilibre, gore, ciblage et finishers indépendants des animations.
