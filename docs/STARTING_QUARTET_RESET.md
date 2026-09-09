# LITD : Les Veilleurs — Reset canonique du quatuor de départ

Date : 2026-09-09
Statut : **RESET COMPLET — AUCUN QUATUOR DE DÉPART CANONIQUE ATTRIBUÉ**

## Décision

Toutes les compositions historiques du quatuor de départ sont invalidées comme canon de départ.

Compositions invalidées :

1. Nayra Orun / Tarek Senn / Aïsha Maren / Idris Vael
2. Sahen Varo / Mira Sen / Narem Osh / Ysra Nahal
3. Aurélien / Malvor / Lysandra / Darius

Aucun membre de ces anciennes compositions n'est automatiquement repris dans le futur quatuor.

## Ce qui est effacé du canon de départ

Le futur quatuor ne doit hériter automatiquement d'aucun élément des anciennes versions :

- nom ;
- visage ;
- silhouette ;
- origine ou ethnie ;
- classe ;
- race ;
- rôle tactique ;
- arme ;
- équipement ;
- statistiques ;
- compétences ;
- personnalité ;
- relations ;
- histoire personnelle ;
- model sheet / planche DA ;
- statut de protagoniste de départ.

Les anciennes planches de Mira Sen et Sahen Varo ne sont donc plus des références du futur quatuor de départ.

## Important : personnages individuels hors quatuor

Cette décision invalide leur **statut de quatuor de départ**. Elle n'impose pas de supprimer rétroactivement tout personnage individuel de l'univers LITD. Un ancien personnage ne pourra revenir dans le jeu ou le lore que par une décision canonique explicite ultérieure et ne récupérera jamais son ancien statut par héritage.

## État runtime pendant le redesign

Le projet conserve quatre emplacements purement techniques :

- `starter_slot_01`
- `starter_slot_02`
- `starter_slot_03`
- `starter_slot_04`

Ils servent uniquement à maintenir les tests, le chargement des systèmes et le développement pendant que le nouveau quatuor est conçu.

Ils ne représentent aucun personnage canonique.

## Contraintes du futur quatuor

Le nouveau quatuor repart d'une feuille blanche, tout en respectant le monde déjà verrouillé :

- LITD est cosmopolite ;
- la culture visuelle et architecturale possède une forte base asiatique, principalement chinoise ;
- les humains du monde appartiennent à des ethnies diverses ;
- les quatre protagonistes doivent avoir des identités visuelles et humaines réellement distinctes ;
- leur diversité ne doit pas être un simple changement de visage : culture personnelle, parcours, position sociale et rapport au monde doivent être individualisés ;
- aucune ancienne classe ou fonction tactique n'est automatiquement conservée ;
- la composition du groupe doit être redéfinie à partir des besoins narratifs, systémiques et émotionnels du nouveau départ.

## Règle de production

Tant que le nouveau quatuor n'est pas validé :

- aucune planche de personnage ne passe en `approved/final` comme héros de départ ;
- aucune fiche 3D de héros de départ ne devient canonique ;
- aucun ancien nom ne doit apparaître comme membre du groupe initial dans une interface joueur ;
- les quatre slots techniques doivent rester explicitement `unassigned`.

## Condition de sortie du reset

Le statut `RESET COMPLET` ne peut être levé que lorsqu'une nouvelle composition de quatre personnages est explicitement validée et inscrite dans `data/veilleurs/canonical_roster.json`.
