# Gouvernance de la bibliothèque vivante LITD

## Statut

Cette politique formalise la séparation stricte entre connaissances générales réutilisables et décisions spécifiques à LITD. Elle s'applique à la bibliothèque vivante, au Core / Development Intelligence System, au Trieur et à toute future intégration avec VEILLEUR V2.

## Principe fondamental

Une information ne doit pas être rangée dans la bibliothèque LITD simplement parce qu'elle a été découverte pendant le développement de LITD.

Le système distingue toujours :

1. **Connaissance générale** — réutilisable dans d'autres projets.
2. **Connaissance LITD** — contextualisation ou conséquence propre au jeu.
3. **Décision LITD** — choix validé qui modifie la conception, l'architecture ou la production du jeu.
4. **Preuve** — source, test, mesure ou observation qui soutient une connaissance ou une décision.
5. **Information ambiguë** — contenu non classable avec assez de confiance ; elle est mise en quarantaine.

## Bibliothèques générales

Les connaissances générales doivent rester dans leurs bibliothèques de domaine, par exemple :

- programmation et génie logiciel ;
- Godot / GDScript ;
- game design ;
- UX / UI ;
- génération procédurale ;
- performance et optimisation ;
- Blender / 3D / pipeline artistique ;
- audio ;
- tests, QA et CI ;
- cybersécurité ;
- IA et automatisation ;
- recherche vidéoludique ;
- accessibilité ;
- architecture logicielle.

Ces connaissances peuvent être référencées par LITD mais ne doivent pas être copiées comme si elles étaient des règles propres au jeu.

## Bibliothèque projet LITD

La bibliothèque projet ne conserve que ce qui est spécifique à LITD, notamment :

- décisions de game design ;
- règles de combat et progression ;
- direction artistique ;
- lore, narration et monde ;
- personnages, ennemis et factions ;
- règles d'expédition, lumière, extraction et mort permanente ;
- structure des niveaux et Vertical Slices ;
- choix d'architecture propres au dépôt ;
- décisions UX propres au jeu ;
- calibrages et métriques validés ;
- incidents, corrections et enseignements propres à LITD ;
- preuves de tests et mesures ;
- historique des décisions et raisons de changement.

## Règle de source canonique unique

Chaque connaissance possède une seule source canonique.

Exemple : une bonne pratique générale de navigation mobile appartient à la bibliothèque UX/UI générale. Si LITD décide de l'utiliser, la bibliothèque LITD conserve uniquement la référence vers cette connaissance et la décision d'application à LITD.

Le même contenu ne doit pas être dupliqué dans plusieurs bibliothèques.

## Routage

Pour toute nouvelle information :

`Découverte → Qualification → Domaine général ou spécifique LITD → Vérification → Routage → Référence croisée éventuelle → Intégration`

Questions obligatoires :

1. Cette information resterait-elle vraie ou utile hors de LITD ?
2. Est-ce une connaissance, une preuve ou une décision ?
3. Quel est son domaine primaire ?
4. Existe-t-il déjà une source canonique ?
5. Son application à LITD a-t-elle été réellement décidée ou est-elle seulement candidate ?

## Exemples

### Nouvelle version de Godot

- bibliothèque primaire : programmation / Godot ;
- bibliothèque LITD : référence seulement si la version est pertinente pour le projet ;
- si migration décidée : création d'une décision LITD avec tests, risques et preuves.

### Technique de génération procédurale

- connaissance générale : bibliothèque game design / programmation ;
- adaptation au rythme d'expédition LITD : bibliothèque LITD ;
- paramètres réellement retenus : décision LITD.

### Étude sur la lisibilité des interfaces mobiles

- connaissance générale : UX/UI ;
- impact potentiel : candidat LITD ;
- changement du HUD : uniquement après décision et test LITD.

### Correction d'un bug propre au dépôt

- cause générale réutilisable : bibliothèque programmation si pertinente ;
- bug, correctif, commit et test de non-régression : bibliothèque LITD.

## Quarantaine

Toute information ambiguë, contradictoire, insuffisamment sourcée ou difficile à classer reçoit le statut :

`À_CLASSIFIER / QUARANTINED`

Elle ne peut ni modifier le Core, ni devenir une règle LITD tant que sa classification et sa qualité ne sont pas établies.

## Passage vers le Core

La bibliothèque ne modifie jamais directement le Core.

Cycle obligatoire :

`DISCOVERED → VERIFIED → RELEVANT → LITD_CHANGE_CANDIDATE → TESTED → APPROVED → APPLIED → MEASURED`

Une connaissance générale peut donc rester indéfiniment dans sa bibliothèque sans produire de changement dans LITD.

## Obsolescence

Toute connaissance ou décision peut devenir obsolète lorsque les technologies, contraintes ou objectifs changent.

Cycle :

`ACTIVE → À_REVALIDER → SUPERSEDED → OBSOLETE → ARCHIVED`

Lorsqu'une connaissance générale référencée par LITD change, le système doit réévaluer les décisions LITD qui en dépendent plutôt que les modifier automatiquement.

## Invariant de gouvernance

**Le savoir général explique le monde ; la bibliothèque LITD explique le jeu ; le Core décide ce que le jeu devient ; Git et les tests prouvent ce qui a réellement été appliqué.**
