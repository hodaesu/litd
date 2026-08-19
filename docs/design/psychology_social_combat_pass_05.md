# Psychologie sociale du combat — Pass 05

## Intention

Le système psychologique ne s'arrête plus au héros. Les ennemis, les compagnons et certains boss lisent maintenant les signes visibles de peur et adaptent leur comportement. La Peur reste la seule jauge psychologique immédiate ; les réactions sociales et tactiques passent par des choix d'IA, des interventions et des lignes contextuelles.

## Ennemis

Les ennemis ne choisissent plus tous leur cible au hasard. La sélection par défaut reste disponible dans le moteur, mais la couche v17 peut la remplacer par un score psychologique. Le score tient compte de la Peur, du seuil Terrifié, de la Panique, des PV manquants et des traumatismes durables.

Les adversaires générant beaucoup de Peur deviennent des prédateurs : ils cherchent plus volontiers les héros déjà fragilisés. Les boss disposent d'un multiplicateur et peuvent recevoir des règles dédiées.

## Pression psychologique

Après une attaque, un ennemi suffisamment terrifiant peut ajouter une faible pression de Peur lorsque sa cible est déjà Terrifiée. Cette pression augmente près de la Panique et face à un boss. Elle ne crée aucune nouvelle valeur cachée : elle agit directement sur la Peur existante et est donc intégrée aux traces et crises du pass précédent.

## Compagnons capturés

Trois comportements initiaux servent de référence :

- **Goule** : garde féroce lorsque la Peur devient extrême ;
- **Oni** : protecteur, réduit la Peur et couvre un allié Terrifié ;
- **Jorōgumo** : ancre sociale, réduit l'isolement et peut provoquer une manifestation d'Espoir.

Une intervention ne remplace pas l'attaque normale du compagnon et ne peut se produire qu'une fois par round.

## Témoin des Cendres

Le boss du chapitre I reçoit une règle psychologique dédiée. Il favorise davantage la cible déjà fragilisée et ajoute une pression supérieure. Sa ligne contextuelle rappelle son identité : il ne cherche pas seulement à faire des dégâts, mais à reproduire devant la cible quelque chose qui ressemble trop à un souvenir.

## Interface

La couche `main_v17.gd` ajoute seulement une indication courte **MENACE** lorsqu'un ennemi est actuellement susceptible de choisir le héros actif à cause de son état. Aucune jauge supplémentaire n'est ajoutée.

## Architecture

`main_v2.gd` expose désormais trois hooks neutres : sélection de cible ennemie, intervention avant le tour du compagnon, réaction après une attaque ennemie. Leur comportement par défaut conserve le prototype historique. `main_v17.gd` branche ces hooks sur `PsychologyCombatDirector`, ce qui évite de dupliquer toute la boucle de combat.

## Validation

Le pass est couvert par le smoke Godot de psychologie, un audit QA dédié, des contrats Python et la CI stricte existante.
