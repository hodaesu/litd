# LITD : Les Veilleurs — verrou de focus Chapitre I

## Décision de production

Jusqu'à validation de la verticale du Chapitre I, le jalon prioritaire absolu de **LITD : Les Veilleurs** est :

**verticale PC Chapitre I → 5 playtests naïfs → triage → corrections → nouveau playtest → validation joueur.**

Le projet ne doit pas confondre activité de production, volume de contenu ou CI verte avec progression vers un jeu validé par des joueurs.

## Question centrale

La verticale doit répondre à une question simple :

> Un nouveau joueur comprend-il les décisions essentielles de LITD, leurs causes et leurs conséquences, et a-t-il envie de repartir en expédition ?

Tant que cette question n'a pas de réponse suffisamment positive et documentée, l'expansion du contenu n'est pas prioritaire.

## Boucle représentative à valider

La verticale de référence doit rester centrée sur une boucle courte et complète :

**Sanctuaire → préparation → exploration courte → combats représentatifs → repos/événement → élite ou mini-boss → boss → conséquence → retour au Sanctuaire.**

Elle doit exposer uniquement les systèmes nécessaires pour juger le cœur du jeu :

- quatre Veilleurs canoniques ;
- ordre des tours et ciblage ;
- positionnement avec coût d'action ;
- petit ensemble de compétences réellement lisibles ;
- anatomie/blessures comme décision fonctionnelle ;
- Peur/Folie et contre-jeu ;
- équipement de début de partie limité ;
- capture ou neutralisation lorsqu'elle sert une vraie décision ;
- conséquence persistante au Sanctuaire ;
- sauvegarde/reprise ;
- un boss représentatif.

## Ce qui est autorisé pendant le verrou

Une tâche est prioritaire si elle améliore directement la verticale ou la qualité des preuves joueur :

- bug bloquant ou régression ;
- lisibilité du combat ;
- ciblage, positionnement et prévisualisation des conséquences ;
- onboarding ;
- rythme de la première expédition ;
- exploration du Chapitre I ;
- retour et conséquences au Sanctuaire ;
- instrumentation de playtest ;
- correction issue d'une observation humaine ;
- stabilité, sauvegarde, performance et contrôles PC ;
- préparation ou intégration d'un asset strictement nécessaire au slice ;
- nettoyage empêchant le test ou faussant ses résultats.

## Ce qui est différé

Sauf dépendance directe du slice, mettre en réserve :

- nouveau héros ;
- nouveau donjon ;
- nouveau chapitre ;
- extension massive du bestiaire ;
- nouveaux arbres ou volumes de compétences ;
- nouveau système majeur ;
- nouveaux modes de jeu ;
- postgame/NG+ supplémentaire ;
- nouveaux boss non nécessaires à la verticale ;
- polish d'un contenu qui n'est pas visible pendant le playtest ;
- expansion narrative qui n'améliore pas la première boucle.

Une idée différée n'est pas rejetée. Elle est conservée dans le backlog jusqu'à sortie du verrou.

## Filtre avant chaque nouvelle tâche

Toute nouvelle demande doit être classée avant production :

1. **UTILE À LA VERTICALE** — elle réduit un risque ou améliore directement le test ;
2. **CORRECTION ISSUE D'UN PLAYTEST** — priorité maximale selon gravité/fréquence ;
3. **MAINTENANCE NÉCESSAIRE** — autorisée si elle protège la build testée ;
4. **À METTRE EN RÉSERVE** — bonne idée mais sans effet direct sur le jalon ;
5. **À SUPPRIMER/FUSIONNER** — complexité sans décision joueur suffisante.

Si une tâche de catégorie 4 ou 5 est proposée avant validation, le projet doit explicitement rappeler le jalon prioritaire avant de l'accepter.

## Critères de sortie du verrou

Le verrou ne peut être levé que lorsque :

- 5 testeurs naïfs distincts ont joué la première boucle sans coaching indu ;
- aucun P0 n'est ouvert ;
- les P1 récurrents sur combat, anatomie, Peur/Folie, exploration et Sanctuaire sont corrigés ou explicitement acceptés ;
- `combat_decision_readability` est validé ;
- `anatomy_causality` est validé ;
- `fear_madness_clarity` est validé ;
- `exploration_route_clarity` est validé ;
- `sanctuary_consequence_loop` est validé ;
- `first_session_onboarding` est validé ;
- la verticale reste verte dans la CI technique ;
- une deuxième passe confirme que les corrections n'ont pas créé de régression majeure.

## Ordre de travail immédiat

1. lancer un auto-test développeur de la verticale PC pour éliminer les blocages évidents ;
2. figer la build candidate de premier playtest ;
3. faire jouer `naive-01` sans explication ;
4. trier et corriger les P0/P1 observés ;
5. répéter avec de nouveaux testeurs jusqu'à `naive-05` ;
6. refaire une passe de confirmation sur la build corrigée ;
7. seulement ensuite décider quelles parties du contenu déjà conçu méritent d'entrer en production de masse.

## Règle de décision

Pour le cœur de LITD, chaque système doit répondre à :

> Quelle décision intéressante crée-t-il, et quelle conséquence le joueur accepte-t-il en la prenant ?

S'il n'existe pas de réponse claire, le système doit être simplifié, fusionné, différé ou supprimé du slice.
