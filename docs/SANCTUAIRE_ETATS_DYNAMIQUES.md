# Sanctuaire du Premier Voile — états dynamiques

> Statut : système narratif et visuel de référence

## Principe

Le Sanctuaire n'est pas un simple menu central. Il doit rendre visibles les conséquences des décisions du joueur dès son retour d'expédition.

La règle de conception est :

> **Le joueur doit pouvoir sentir qu'il a changé le Sanctuaire avant même d'ouvrir un journal de quêtes.**

Le système évite de créer une scène différente pour chaque combinaison. Il utilise des **couches d'état combinables** appliquées à un état de base stable.

## États disponibles

- **Stable** : fonctionnement normal du Sanctuaire.
- **Accueillant** : réfugiés, couchages supplémentaires, tables communes et pression sur les ressources.
- **Tendu** : groupes séparés, armes visibles, patrouilles et conversations plus courtes.
- **Militarisé** : barricades, postes de contrôle, gardes nombreux, entraînement audible.
- **Appauvri** : étals vides, portions réduites, activité marchande faible, files d'attente.
- **Coexistence** : habitat de créature, zone d'observation et réactions contrastées des habitants.
- **Reconstruction civique** : assemblées, archives, panneaux publics, réparations collectives.
- **Fragmenté** : espaces communs désertés, inscriptions hostiles, groupes refermés sur eux-mêmes.

## Composition

Le Sanctuaire garde toujours la couche `stable` et peut activer jusqu'à trois couches majeures supplémentaires. Les états les plus prioritaires gagnent en cas de conflit.

Exemples :

- Stable + Accueillant + Tendu
- Stable + Appauvri + Reconstruction civique
- Stable + Coexistence + Tendu + Militarisé

## Déclencheurs

Les couches sont calculées depuis :

- confiance ;
- tension ;
- vivres ;
- Corps ;
- Cité ;
- décisions politiques persistantes ;
- accueil ou refus de réfugiés ;
- présence d'une créature consciente au Sanctuaire.

## Dimensions modifiées

Chaque état peut modifier quatre catégories :

1. **Décor** — barricades, couchages, étals, archives, inscriptions, habitats.
2. **Population** — réfugiés, gardes, médiateurs, curieux, marchands, habitants isolés.
3. **Ambiance sonore** — conversations, silences, disputes, activité des ateliers, ordres militaires.
4. **Gameplay** — densité sociale, présence des gardes, activité du marché, activité civique et visibilité de certains services.

## Retour d'expédition

L'écran du Sanctuaire affiche immédiatement l'état combiné actuel et quelques signes majeurs : éléments visibles, populations présentes et ambiance sonore attendue.

Ce retour doit devenir progressivement plus visuel lorsque les assets définitifs seront produits : les mêmes états servent alors de contrat à Blender/Godot pour activer ou masquer les éléments de décor correspondants.

## Objectif narratif

Le Sanctuaire devient une mémoire vivante de la campagne. Les choix du joueur ne changent pas seulement des nombres : ils changent la manière dont les habitants vivent ensemble, ce qu'ils voient, ce qu'ils entendent et les espaces qu'ils partagent.
