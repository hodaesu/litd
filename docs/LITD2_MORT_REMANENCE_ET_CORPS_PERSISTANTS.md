# LITD 2 — Mort, recommencement de run et corps persistants

> Statut : canon narratif et systémique prioritaire pour la mort du joueur dans LITD 2
> Portée : défaite, recommencement de run, chronologie, corps persistants, récupération d'équipement et continuité avec LITD 1
> Priorité : ce document remplace toute formulation antérieure laissant entendre qu'une mort fait avancer la guerre, fait perdre une quête secondaire ou reprend la partie depuis un checkpoint.

## 1. Règle fondamentale

Dans LITD 2, **mourir fait recommencer la run entière**.

Le joueur ne réapparaît pas :

- à un checkpoint ;
- à la dernière salle ;
- au dernier combat ;
- à un point de sauvegarde intermédiaire.

La tentative est terminée.

La prochaine tentative recommence depuis le **point de départ historique de cette run**.

Formule canonique :

**Départ de run → progression → mort → corps persistant → reconstruction / retour → nouvelle tentative depuis le début de la run.**

## 2. La mort ne fait pas avancer la guerre

Une mort de gameplay ne valide aucun événement historique.

Elle ne peut pas :

- faire tomber une ville hors écran ;
- faire gagner ou perdre définitivement une bataille ;
- supprimer une quête secondaire ;
- tuer automatiquement un PNJ narratif ;
- fermer une route narrative importante ;
- faire passer le jeu à la période de guerre suivante.

La chronologie avance uniquement lorsqu'un **jalon historique est effectivement accompli** ou lorsque le joueur choisit explicitement de quitter une période après avoir rempli ses conditions.

Une mort représente donc une tentative qui n'a pas produit le résultat historique retenu par la chronologie.

Le jeu ne doit jamais punir l'apprentissage mécanique par une perte de contenu narratif.

## 3. Les quêtes secondaires restent disponibles

Une quête secondaire découverte n'expire jamais simplement parce que le joueur est mort.

Si une quête a été révélée pendant une tentative puis que le joueur meurt, elle reste connue et peut réapparaître dans une tentative suivante lorsque sa zone ou ses conditions sont à nouveau accessibles.

Les pertes narratives permanentes viennent de **décisions volontaires du joueur**, pas de sa mort.

Exemples de conséquences permanentes valides :

- choisir de remettre un prisonnier à une faction plutôt qu'à une autre ;
- détruire volontairement une archive ;
- refuser une demande ;
- prendre parti dans un conflit ;
- sacrifier une ressource ou une opportunité après un choix explicite.

Exemples de conséquences permanentes interdites :

- perdre une quête parce qu'un boss a tué le joueur ;
- manquer une scène parce qu'une run a échoué ;
- voir la guerre se terminer pendant une reconstruction après la mort.

## 4. Le corps reste dans le monde

Chaque mort produit un **corps persistant du protagoniste**.

Ce corps appartient au monde physique : la reconstruction du joueur ne téléporte pas son ancien cadavre et ne l'efface pas.

Le corps peut conserver :

- l'équipement porté au moment de la mort ;
- l'arme utilisée ;
- certains objets de run ;
- le lieu ou secteur de la mort ;
- la cause de mort ;
- les blessures visibles pertinentes ;
- les Éveils choisis pendant cette tentative ;
- le niveau de Lumière, Folie ou autres états narrativement utiles ;
- la date / période historique de la tentative.

Le corps persistant est une signature de LITD Universe et doit rappeler le système de cadavres de LITD 1 sans être une copie mécanique exacte.

## 5. Retrouver son propre cadavre

Lors d'une tentative suivante de la même opération, le joueur peut retrouver son ancien corps.

Le corps ne doit pas dépendre d'une coordonnée procédurale exacte qui pourrait disparaître lorsque la run est recomposée.

Il est enregistré sur un **ancrage historique de zone** : secteur, type de salle, embranchement, objectif local ou nœud de rencontre.

Lors de la génération suivante, le système réserve un emplacement compatible et y réinjecte le cadavre.

Ainsi, la géométrie précise peut varier alors que la fiction reste cohérente :

> « Je suis mort dans les souterrains du quartier Est » reste vrai même si le couloir exact n'est pas identique à la tentative précédente.

## 6. Ce qui peut arriver au cadavre

Le cadavre ne doit pas toujours attendre passivement au même endroit.

Selon la zone et les systèmes de run, il peut être :

- intact ;
- partiellement dépouillé ;
- déplacé de quelques mètres par des combattants ou des créatures ;
- recouvert ou enterré sommairement par des civils ;
- utilisé comme avertissement par un groupe ennemi ;
- contaminé par un phénomène surnaturel ;
- entouré des traces du combat qui l'a tué.

Ces variations ne doivent jamais supprimer arbitrairement une quête ou un objet narratif irremplaçable.

## 7. Récupération de l'équipement

Une partie de l'intérêt de retrouver son corps vient de la récupération.

Le principe retenu est :

- les éléments méta et les déblocages permanents ne sont jamais perdus ;
- les Éveils de la run précédente ne sont pas restaurés comme build actif : la nouvelle run reconstruit son propre build ;
- l'équipement physique abandonné peut être récupéré sur le cadavre selon les règles d'inventaire définitives ;
- aucun objet indispensable au scénario principal ne peut être perdu définitivement sur un corps inaccessible.

Le corps est donc un risque et une mémoire de la tentative précédente, pas un mécanisme capable de casser une sauvegarde.

## 8. Plusieurs morts dans une même run historique

Le joueur peut mourir plusieurs fois avant de réussir une opération.

Chaque mort peut laisser une trace distincte.

Le système doit conserver au minimum les informations logiques de chaque cadavre : lieu, cause, équipement et état.

Pour des raisons de lisibilité et de performance, l'affichage simultané de très nombreux anciens corps pourra être limité ou regroupé visuellement, mais le canon ne doit pas prétendre que les morts précédentes n'ont jamais existé.

Les cadavres les plus récents, les plus significatifs ou ceux contenant encore un équipement récupérable sont prioritaires pour une représentation physique complète.

## 9. Relation avec le Vestige / la Rémanence

La piste de conception privilégiée reste celle d'un protagoniste capable d'être reconstruit grâce à un phénomène ou un vestige ancien lié à une civilisation antérieure et au Voile.

Cette origine exacte reste à développer et n'est pas entièrement verrouillée par le présent document.

En revanche, une règle est déjà canonique :

**la reconstruction produit un nouveau corps sans faire disparaître l'ancien.**

Il ne s'agit donc ni d'un voyage temporel ni d'un simple réveil après inconscience.

Le personnage a réellement été tué.

Un nouveau corps revient ensuite à l'existence par le mécanisme de Rémanence encore à définir.

## 10. Conséquence philosophique

Le fait que les anciens corps demeurent rend la reconstruction beaucoup plus troublante.

Sahra peut questionner la relation du protagoniste à une chair qu'il sait remplaçable.

Ilyan peut chercher à comprendre où se trouve l'identité lorsque plusieurs corps biologiquement authentiques du même individu existent successivement.

Tala peut s'interroger sur les conséquences politiques d'un individu que la mort n'écarte pas durablement du pouvoir ou de la guerre.

Ces interrogations peuvent participer aux affinités avec les trois fondateurs sans transformer le protagoniste en quatrième fondateur.

## 11. Une mort ne réinitialise pas tout

Recommencer la run ne signifie pas effacer toute progression du joueur.

Restent persistants selon les systèmes déjà définis ou à préciser :

- connaissance des quêtes déjà découvertes ;
- affinités Sahra / Ilyan / Tala déjà gagnées hors récompenses explicitement conditionnées à la réussite de la run ;
- déblocages horizontaux ;
- entrées de codex et connaissances ;
- informations apprises sur les ennemis ;
- progression méta autorisée ;
- corps laissés par les tentatives précédentes.

En revanche, la nouvelle tentative recrée :

- le build temporaire Corps / Esprit / Politique ;
- les Éveils de run ;
- une partie des ressources temporaires ;
- l'agencement procédural autorisé ;
- les rencontres non historiques variables.

## 12. La guerre avance après la réussite, pas après la mort

Une période historique peut contenir autant de tentatives que nécessaire.

Quand une opération majeure est accomplie, son résultat entre dans la chronologie et peut ouvrir l'opération ou la période suivante.

Le rythme narratif devient donc :

**choisir une opération → tenter la run → mourir éventuellement → recommencer → réussir → enregistrer le fait historique → retour au hub / camp → poursuivre la guerre.**

La guerre semble progresser, mais elle ne vole jamais une partie du jeu au joueur pendant qu'il apprend.

## 13. Nuit de Sarn

La Nuit de Sarn obéit à la même règle.

Elle est la dernière run de LITD 2, mais une mort à Sarn fait **recommencer Sarn depuis le début**.

Elle ne déclenche pas automatiquement une mauvaise fin permanente, ne détruit pas la sauvegarde et ne fait pas avancer l'Histoire sans le joueur.

La victoire à Sarn reste un événement que le joueur doit réellement accomplir.

## 14. Règles verrouillées

1. Aucun checkpoint intermédiaire après la mort.
2. Toute mort termine la tentative en cours.
3. La prochaine tentative reprend au début de la run.
4. La mort ne fait pas avancer la chronologie historique.
5. La mort ne fait perdre aucune quête secondaire importante.
6. Les conséquences narratives permanentes proviennent de décisions volontaires, pas de l'échec mécanique.
7. Chaque mort laisse un corps persistant dans le monde.
8. Le corps peut être retrouvé dans une tentative suivante grâce à un ancrage de zone compatible avec la génération procédurale.
9. Le corps peut conserver équipement, cause de mort et état de la tentative.
10. La reconstruction ne fait pas disparaître l'ancien corps.
11. Une nouvelle run reconstruit son build temporaire au lieu de restaurer celui du cadavre.
12. La Nuit de Sarn suit exactement ces règles.

## 15. Formule directrice

**La mort efface la tentative, pas l'Histoire. Le corps reste. Le joueur repart depuis le début de la run.**
