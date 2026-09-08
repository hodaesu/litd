# LITD : Les Veilleurs — premier playtest du Chapitre I

## Objectif

Le premier playtest ne sert pas à prouver que le jeu est « fini ». Il sert à faire passer les systèmes prioritaires du niveau **2/5 — testé techniquement** vers le niveau **3/5 — compris par le joueur**.

Le verrou de focus actif est décrit dans `docs/veilleurs/VERTICAL_SLICE_FOCUS_LOCK.md` : jusqu'à validation de la verticale, les nouvelles demandes doivent être classées **utile à la verticale**, **correction issue d'un playtest**, **maintenance nécessaire** ou **à mettre en réserve**.

Les premières preuves recherchées sont :

1. `combat_decision_readability` ;
2. `anatomy_causality` ;
3. `fear_madness_clarity` ;
4. `exploration_route_clarity` ;
5. `sanctuary_consequence_loop` ;
6. `first_session_onboarding`.

La DA en contexte peut être observée sur PC, mais sa validation finale et `real_mobile_interaction` restent liées aux tests sur appareils réels.

## Ce qui est déjà prouvé avant le playtest

Le dépôt possède déjà des preuves techniques pour le combat, les règles de tours, l'anatomie, les blessures, Peur/Folie, la boucle du Chapitre I, les smokes Godot, les six donjons, les régressions tactiles logiques et l'export Android.

Le playtest ne doit donc pas répéter les audits machine. Il doit observer ce que les audits ne peuvent pas savoir : **ce que comprend réellement une personne devant le jeu**.

## Lancement Windows recommandé

Depuis la racine du dépôt, le chemin le plus simple est :

```bat
tools\workstation\LITD_VEILLEURS_FIRST_PLAYTEST.cmd
```

Pour identifier un testeur :

```bat
tools\workstation\LITD_VEILLEURS_FIRST_PLAYTEST.cmd testeur-01
```

Le lanceur :

1. exécute le préflight Godot 4.7.x ;
2. exécute les tests rapides requis ;
3. crée `local/playtests/<session>/` ;
4. copie le modèle de rapport avec le commit réellement testé ;
5. crée une fiche d'observation ;
6. exporte une build Windows debug ;
7. lance la build.

Le jeu est exporté vers :

`build/playtest/windows/LightInTheDark_Playtest.exe`

Les rapports de session sont locaux et ne sont pas committés automatiquement.

## Règle absolue

Le lanceur **ne valide aucun gate**.

Une session fraîche commence avec tous les gates à `NOT_RUN`. Les statuts `PASS`, `FAIL` ou `BLOCKED` ne sont saisis qu'après un test effectivement observé.

Une session développeur (`developer-selftest`) permet de repérer des problèmes et de préparer le protocole, mais **ne remplace pas les testeurs naïfs** exigés pour verrouiller l'onboarding.

## Comment observer

Pendant une mesure de compréhension :

- ne pas expliquer où cliquer ;
- ne pas nommer la bonne stratégie ;
- ne pas corriger une interprétation immédiatement ;
- noter le premier geste tenté ;
- noter la première hésitation ;
- noter les informations cherchées ;
- noter la phrase avec laquelle le joueur explique ce qu'il croit avoir compris.

Une aide orale n'est donnée qu'en cas de blocage total, et cette aide doit être consignée.

## Séquence de test minimale

### 1. Entrée dans la partie

Observer si le joueur comprend spontanément :

- son objectif immédiat ;
- comment progresser ;
- où se trouve l'information nécessaire ;
- comment accéder au premier combat.

### 2. Premier combat représentatif

Observer :

- qui le joueur pense devoir faire agir ;
- comment il choisit une compétence ;
- comment il choisit une cible ;
- s'il comprend les rangs ;
- s'il anticipe le résultat ;
- s'il comprend ensuite pourquoi le résultat réel s'est produit.

### 3. Anatomie

Observer si le joueur comprend que viser une partie du corps sert à modifier une fonction tactique, et pas uniquement à produire un effet gore.

### 4. Peur / Folie

Observer si le joueur :

- identifie la cause d'un changement ;
- comprend son effet ;
- cherche un contre-jeu cohérent.

### 5. Exploration

Observer si l'incertitude est perçue comme exploration plutôt que comme interface cachée ou blocage arbitraire.

### 6. Retour au Sanctuaire

Demander au joueur ce qui, selon lui, a changé à cause de l'expédition. Sa réponse doit permettre de mesurer la perception de la conséquence persistante.

## Après la session

Le rapport principal est :

`local/playtests/<session>/player_validation.json`

Les notes libres sont :

`local/playtests/<session>/observer_notes.md`

Valider la structure d'un rapport encore incomplet :

```bash
python -m tools.qa.veilleurs_player_validation_report local/playtests/<session>/player_validation.json --allow-incomplete
```

Le validateur final sans `--allow-incomplete` doit rester rouge tant que les preuves exigées ne sont pas réunies.

## Conditions du passage combat 2/5 → 3/5

Le combat ne passe au niveau 3 que lorsque les rapports versionnés montrent réellement que les décisions, cibles, causes et conséquences sont comprises sans coaching indu.

Une seule session développeur ne suffit pas à verrouiller la première expérience. Le gate d'onboarding final exige au moins **5 testeurs naïfs distincts**.

## Ce qui reste ensuite pour le niveau 4/5

Après validation joueur :

- vrai iPhone et Android ;
- confort au pouce ;
- safe areas ;
- lisibilité à taille réelle ;
- performance FPS/mémoire/chauffe ;
- haptique ;
- audio réel ;
- sauvegarde/reprise ;
- build iOS signée.

Le niveau 4 n'est jamais accordé sur la seule base d'une simulation tactile ou d'un navigateur desktop.

## Accès Web/iPhone

Le workflow `LITD Web Playtest PWA` exporte le projet sous Godot 4.7.2 et GitHub Pages est désormais activé pour le dépôt. Le playtest Web public est disponible à l'adresse :

`https://hodaesu.github.io/litd/`

Cette version est utile pour vérifier rapidement la première expérience sur iPhone et partager une build, mais elle ne remplace pas la validation mobile native sur appareil réel ni la future build iOS signée.
