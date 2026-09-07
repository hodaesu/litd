# LITD : Les Veilleurs — Mémoire de combat et matrice IA v1

## Objectif

Raccorder les événements réellement vécus en combat à la Rémanence des ennemis de **LITD : Les Veilleurs**, puis permettre à cette mémoire de modifier leurs décisions futures sans leur donner de connaissance omnisciente ni de compétence qu'ils ne possèdent pas.

## Source d'événements

Le système ne crée pas un deuxième détecteur de combat. `VeilleursCombatMemoryAdapter` écoute les événements déjà enregistrés par `RemanenceCombatBridge` via `RemanenceRuntime.event_recorded` et les traduit vers le vocabulaire canonique des Veilleurs.

Correspondances actuellement branchées :

- `major_mutilation` → `mutilation` ;
- `killed_watcher` → `watcher_kill` ;
- `capture_escaped` → `failed_capture` ;
- `forced_retreat` → `forced_retreat` ;
- `survived_combat` → `survival`, uniquement après preuve d'un échange significatif ;
- `reencountered` → `repeated_encounter` ;
- `relic_taken` → `important_item_taken_or_recovered`.

Une sortie réelle du combat ne doit jamais être confondue avec une technique de repositionnement. Tant que le moteur n'émet pas encore un événement générique d'évasion individuelle, la machine d'état appelle explicitement `note_actual_enemy_escape(...)` sur le coordinateur.

## Preuves et garde-fous

Les événements transmis contiennent autant que possible : identité persistante, espèce, état vivant, Veilleurs reconnus, zone corporelle, méthode de capture, axe de sortie, terrain, objet, auteur ou adversaire connu et source de preuve.

Les événements qui exigent un individu vivant — survie, meurtre d'un Veilleur, mutilation, fuite, capture échouée et retraite provoquée — sont rejetés si la preuve indique que l'entité est morte.

Une simple présence dans une rencontre ne suffit pas à valider `survival`. L'adaptateur exige au moins un événement significatif déjà observé pour cet individu dans l'affrontement.

## Mémoire persistante

`VeilleursRuntimeCoordinator` synchronise l'état canonique de `VeilleursRemanencePolicy` dans la fiche persistante déjà gérée par `RemanenceRuntime` :

- `veilleurs_memory_state` ;
- `veilleurs_memory_rank`.

Au chargement ou lors d'un changement global de Rémanence, le coordinateur peut réhydrater la politique locale à partir de ces données. Le système n'introduit donc pas un second fichier de sauvegarde concurrent.

## Matrice IA

`VeilleursEnemyDecisionMatrix` reçoit explicitement une liste `owned_skills`. Cette liste constitue une frontière de sécurité absolue.

La matrice peut :

- retirer une compétence explicitement déclarée inutilisable ;
- retirer une compétence dont une fonction corporelle déclarée nécessaire est perdue ;
- réordonner les compétences restantes à partir des souvenirs vécus ;
- fournir un indice de cible uniquement si une relation précise a réellement été mémorisée.

Elle ne peut pas :

- créer une compétence ;
- rechercher une compétence hors de `owned_skills` ;
- lire le build global du joueur ;
- lire la liste des compétences non observées du joueur ;
- inventer une immunité ;
- compenser une mutilation par une capacité absente de l'arbre de l'ennemi.

Les clés de contexte acceptées sont limitées à l'état corporel fonctionnel, la position courante, une cible effectivement observée, le fait qu'il s'agisse d'une rencontre ultérieure et une graine déterministe. Les autres clés sont déclarées ignorées dans le résultat.

## Intensité par rang

- Normal : aucune adaptation mémorielle ;
- Mémoriel : petit biais d'essai permettant de tester un enseignement vécu lors d'une rencontre ultérieure ;
- Vétéran : adaptation tactique limitée plus nette ;
- Élite : adaptation renforcée, toujours à l'intérieur de son propre kit ;
- Némésis : combinaison plus forte des souvenirs bornés, sans compétence supplémentaire ni bonus de PV artificiel.

Quand un Mémoriel choisit réellement une autre compétence à cause d'un souvenir vécu et que cette décision est exécutée, `commit_enemy_skill_choice(...)` enregistre l'application de l'enseignement. C'est cette preuve qui autorise la promotion vers Vétéran.

## Réponses tactiques bornées

La mémoire d'une famille de menace ne donne pas le contre parfait. Elle augmente seulement le poids de familles de réponses plausibles déjà présentes dans les compétences possédées. Par exemple, une expérience marquante d'Assaut peut favoriser Défense, Contrôle ou Repositionnement si — et seulement si — l'ennemi possède déjà une technique correspondante.

La mémoire de position favorise Repositionnement, Défense ou Chasse/Embuscade ; une capture ratée peut favoriser Défense, Repositionnement ou Contrôle. La mémoire relationnelle ne crée pas une compétence : elle peut seulement fournir un indice de cible reconnue.

## Validation

Le smoke `veilleurs_combat_memory_ai_smoke.tscn` vérifie notamment :

- mutilation réelle → mémoire de menace et relation ;
- mémoire Mémorielle → choix différent parmi les compétences possédées ;
- décision réellement modifiée → promotion Vétéran ;
- perte d'une fonction corporelle → technique dépendante écartée ;
- données `player_build` et compétences globales du joueur ignorées ;
- capture ratée → mémoire de la méthode ;
- meurtre d'un Veilleur → mémoire relationnelle ;
- fuite réelle → mémoire d'axe ;
- retraite provoquée et objet important → hooks canoniques ;
- état canonique recopié dans la Rémanence persistante ;
- sérialisation/désérialisation de la politique sans perte de rang.
