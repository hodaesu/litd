# Pass 10–13 — Sanctuaire vivant, mémoire collective et quêtes émergentes

## Intention

Le monde réactif du pass 09 ne doit pas s'arrêter à la rencontre qui revient. Les personnes qui survivent peuvent maintenant continuer leur trajectoire, entrer dans le réseau du Sanctuaire, transporter des récits et provoquer des quêtes qui n'existent pas dans toutes les campagnes.

Le système ne crée aucune jauge morale globale. Une réputation n'est pas un score : ce sont des faits connus par des communautés précises, racontés avec une origine et une fiabilité différentes.

## Population persistante

Mara, Yoren et Iven sont les premiers habitants persistants issus directement d'une rencontre de terrain.

Après `c01_village_survivors`, leur état conserve le fait qu'ils sont vivants et leur localisation narrative. Leur retour du chapitre III peut ensuite les relier au Sanctuaire :

- Mara devient liaison du relais aux trois traits et tient un registre de ravitaillement ;
- Yoren devient guide des routes d'expédition ;
- Iven devient éclaireur en formation et peut proposer des demandes propres.

S'ils ont survécu sans aide, ils ne sont pas artificiellement absorbés par le Sanctuaire : leur relais reste indépendant. Leur existence continue néanmoins d'alimenter la mémoire collective.

## Sanctuaire vivant

`SanctuaryState` compose désormais ses cues politiques historiques avec ceux des personnes réellement présentes. Des cartes corrigées, le registre aux trois traits et des marques de cuivre apparaissent dans les descriptions du lieu seulement si ces personnes ont rejoint son réseau.

`main_v21.gd` ajoute un écran **Communauté** accessible depuis le Sanctuaire et la Taverne. Il montre les personnes présentes et leur rôle, les récits qui circulent, puis les quêtes réellement produites par cette histoire.

## Rumeurs et mémoire collective

`CommunityRuntime` garde deux structures distinctes :

- les rumeurs, qui sont des formulations circulant entre voyageurs ou habitants et peuvent être directes, confirmées, variables ou simplement rapportées ;
- les faits collectifs, qui enregistrent ce qu'un groupe donné sait effectivement de l'histoire de la compagnie.

Un recrutement de créature peut ainsi produire une rumeur ambiguë, tandis que le retour physique d'un survivant produit un fait confirmé. Le sort d'un boss peut également devenir un récit de voyageurs lorsque la mémoire individuelle des héros en conserve la trace.

La Taverne écoute en priorité ces rumeurs vivantes avant de revenir aux rumeurs génériques de quête principale.

## Quêtes émergentes

Deux premières quêtes démontrent le contrat :

### Les cartes que le relais n'a jamais reçues

Iven ne peut proposer cette quête que si le relais aux trois traits existe et si lui-même a réellement rejoint le réseau du Sanctuaire. L'objectif utilise une preuve déjà existante du chapitre III : `ev_korem_redaction`. La quête ne crée donc pas un faux objectif parallèle au monde réel.

### Une ligne sûre dans le Seuil

Yoren demande de confirmer physiquement la route vers `c03_threshold_complex`. La découverte de cette zone par une quête active accomplit la demande.

Les récompenses sont de petites ressources d'expédition. Elles représentent l'amélioration concrète d'un réseau de survivants et restent secondaires par rapport à la progression principale.

## Sauvegarde et migration

Le schéma historique reste en version `0.31` afin de préserver les contrats existants. La clé `community` est additive et optionnelle. Une ancienne sauvegarde sans cette clé initialise une communauté vide puis continue normalement.

L'état sauvegardé contient : population, rumeurs, mémoire collective et états des quêtes émergentes.

## QA

Le smoke Godot couvre la chaîne complète : aide aux survivants → retour au chapitre III → présence dans le Sanctuaire → apparition de quêtes → acceptation → accomplissement via un objectif existant → récompense → sérialisation → restauration → reset de nouvelle partie.

L'audit Python vérifie aussi l'absence de jauge morale, la route `main_v21`, les cues dynamiques du Sanctuaire, l'autoload et la compatibilité de sauvegarde.

## Suite

Ce contrat peut maintenant accueillir des familles séparées, blessés transportables, prisonniers, réfugiés, anciens soldats et créatures conscientes. Les mêmes structures permettent aussi de faire varier des gardes, marchands, accès et dialogues en fonction des faits connus localement, sans réduire la campagne à un score unique de réputation.
