# Pass 09 — Monde réactif : survivants, ressources et retours

## Intention

Le pass 08 a donné une mémoire aux choix de terrain. Le pass 09 fait maintenant exister ces choix dans l'espace d'exploration et leur donne une suite visible plusieurs chapitres plus tard.

Le principe reste inchangé : le moteur n'étiquette jamais une décision comme « bonne » ou « mauvaise ». Il conserve ce qui a été fait, qui l'a vu, ce que cela a coûté et ce que le monde est devenu ensuite. Les héros réinterprètent ces faits selon leurs convictions et leurs relations.

## Première rencontre jouable — Les trois sous la charpente

Dans `zone_02_village_ravage`, Mara, Yoren et Iven apparaissent comme une rencontre `Area3D` réellement interactive. Le blockout affiche trois silhouettes et une poutre effondrée afin que la scène soit testable avant la production Blender définitive.

Le joueur peut :

- partager 2 nourriture, 2 eau et 1 médicament ;
- dépenser 2 bandages et 1 médicament pour les stabiliser sans sacrifier les vivres ;
- conserver toutes les réserves.

Les coûts sont prélevés directement dans `ExpeditionManager`. Une option impossible à payer est désactivée et aucune consommation partielle n'a lieu.

Le choix crée simultanément :

1. un état global persistant de la rencontre ;
2. une mémoire de terrain individuelle pour chaque héros vivant présent ;
3. une trace du chapitre, de la zone et des témoins directs.

## Retour au chapitre III

Le monde ne suppose pas qu'une personne laissée derrière meurt automatiquement.

Si les trois survivants ont reçu une aide complète, ils peuvent établir un petit relais qui rend plus tard nourriture, eau et lumière à la compagnie. S'ils ont seulement été stabilisés, ils survivent également mais leur installation est plus pauvre et leur retour fournit moins de ressources.

S'ils n'ont reçu aucune aide, ils peuvent malgré tout réapparaître : ils ont trouvé leur propre solution. Ce retour n'annule pas le choix passé. Il retire simplement au joueur et aux héros la possibilité de raconter une conséquence qui n'a pas eu lieu.

Chaque retour réévalue la mémoire initiale au lieu de remplacer son score ou d'effacer artificiellement une tension.

## Retour d'un ennemi épargné

Le Témoin des Cendres constitue le premier exemple concret de continuité post-boss. S'il a été épargné au chapitre I, une rencontre du chapitre III peut le faire réapparaître au Poste Diplomatique Effondré. Il ne rejoint pas automatiquement la compagnie : il indique un passage sûr et fournit une aide limitée, puis disparaît.

Cette apparition déclenche la conséquence différée `spared_enemy_helped`, déjà compatible avec la mémoire de terrain. Si le Témoin a été achevé, cette rencontre n'existe pas.

## Architecture

`FieldEncounterRuntime` possède l'état global des rencontres, contrôle les coûts, les choix, les retours, les témoins et la sérialisation. `FieldEncounterInjector` place les rencontres compatibles dans le `GeneratedBlockout` lorsque la zone est chargée. `FieldEncounterTrigger` fournit l'`Area3D`, le collider, le blockout visuel et l'interaction. Le contrôleur d'exploration existant appelle déjà `interact()` sur les zones visées : aucun second système d'interaction n'est créé.

Les décisions restent liées à `FieldMemoryRuntime` pour leur interprétation psychologique et relationnelle. La sauvegarde passe en version 0.32 et stocke explicitement l'état global `field_encounters`, tandis que les souvenirs individuels continuent de vivre dans `GameState.party`.

## Interface

La rencontre suspend le mouvement de la compagnie et ouvre un panneau contextuel au-dessus de l'exploration. Le joueur voit :

- la situation en prose ;
- les réserves disponibles ;
- les choix et leur coût concret ;
- les options impossibles à payer désactivées.

Aucune jauge morale, de réputation ou d'alignement n'est ajoutée.

## QA

Le smoke Godot vérifie la consommation exacte des ressources, la création des souvenirs, l'impossibilité de rejouer une décision, la sérialisation, la restauration, le retour des survivants, la réévaluation de la mémoire, le retour conditionnel du Témoin épargné et l'atomicité d'un choix impossible à payer.

L'audit Python contrôle également le contrat 3D, les conditions de retour, la compatibilité avec l'inventaire d'expédition, les autoloads et la sauvegarde.

## Suite prévue

La prochaine extension naturelle est de transformer ce premier contrat en bibliothèque de rencontres réactives réutilisable : blessés transportables ou non, familles séparées, prisonniers, réfugiés, créatures conscientes et anciens soldats. Certains survivants pourront ensuite atteindre le Sanctuaire, ouvrir des quêtes secondaires ou modifier physiquement un lieu revisité.
