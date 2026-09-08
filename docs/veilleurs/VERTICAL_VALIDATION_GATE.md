# LITD : Les Veilleurs — gate de validation verticale

## But

Ce gate empêche la production de masse de masquer des problèmes fondamentaux d'expérience joueur.

La règle est :

**intention joueur → hypothèse → prototype → playtest → décision → production → intégration → QA → validation appareil → verrouillage**.

Le Chapitre I sert de référence. Tant que sa boucle représentative n'est pas validée par des preuves joueur et techniques, la priorité n'est pas d'augmenter le nombre de donjons, de compétences, de créatures ou de variantes.

## Ce qui reste autorisé pendant le verrou

Le verrou ne signifie pas arrêt du projet. Restent prioritaires et autorisés :

- correction de bugs ;
- amélioration de lisibilité et UX ;
- instrumentation, QA, CI et outils ;
- préparation d'assets nécessaires au vertical slice ;
- optimisation et profiling ;
- équilibrage du contenu déjà présent ;
- documentation et nettoyage technique ;
- préparation des tests sur appareil ;
- recherche et prototypage ciblé lorsqu'une hypothèse reste ouverte.

Ce qui doit être évité tant que le gate n'est pas vert :

- ajout massif de nouveaux donjons ;
- multiplication des compétences non testées ;
- nouveaux systèmes majeurs sans hypothèse/prototype ;
- expansion du bestiaire qui ne sert pas directement la verticale ;
- polish de contenu qui pourrait être remis en cause par un problème d'UX ou de boucle.

## Contrat machine

Source : `data/veilleurs/player_validation_contract.json`.

Audit CI :

```bash
python -m tools.qa.veilleurs_player_validation_audit
```

Modèle de rapport :

`reports/veilleurs_player_validation_template.json`

La CI valide la structure du contrat et la cohérence des dépendances. Elle ne transforme jamais un `NOT_RUN` en `PASS`.

## Les huit gates joueur

### 1. Combat — lisibilité de la décision

Le joueur doit comprendre :

- qui agit ;
- quelles cibles sont possibles ;
- ce que l'action devrait provoquer ;
- pourquoi le résultat s'est produit.

### 2. Anatomie — causalité tactique

Le joueur doit percevoir le ciblage anatomique comme une décision fonctionnelle et non comme du gore aléatoire.

### 3. Peur et Folie — compréhension et adaptation

Le joueur doit comprendre la cause des changements psychologiques et identifier une forme de contre-jeu lorsqu'elle existe.

### 4. Exploration — clarté de la route

L'incertitude et la découverte sont souhaitées, mais le joueur ne doit pas être bloqué par une interaction invisible ou arbitraire.

### 5. Sanctuaire — conséquence persistante

Le joueur doit pouvoir relier une décision d'expédition à au moins une conséquence observable au Sanctuaire ou dans le monde.

### 6. Première session — onboarding

Un testeur naïf doit pouvoir accomplir la première boucle représentative sans coaching oral du développeur.

### 7. DA en contexte — lisibilité

La direction artistique doit rester forte tout en laissant visibles cibles, silhouettes, états, interactions et informations tactiques.

### 8. Interaction mobile réelle

Le ciblage, la sélection anatomique, les compétences, le Sanctuaire et la sauvegarde/reprise doivent être utilisables confortablement sur téléphone réel.

## Preuves nécessaires

Pour verrouiller la verticale, chaque gate doit disposer d'un rapport de session relié à :

- un commit/build précis ;
- un testeur identifié de manière non sensible ;
- une plateforme/appareil ;
- des observations concrètes ;
- le nombre de problèmes bloquants ;
- une décision : `PASS`, `FAIL` ou `BLOCKED`.

Le verrou final demande au moins **5 testeurs naïfs** pour la première expérience et aucun problème bloquant ouvert sur les gates requis.

## Ce qui peut être validé sans PC

Le dépôt peut déjà vérifier automatiquement :

- cohérence des contrats ;
- règles de combat ;
- données ;
- sauvegarde ;
- références Godot ;
- budgets visuels ;
- smokes ;
- régressions ;
- cohérence des parcours et systèmes ;
- préparation des rapports et scénarios de test.

Cela réduit fortement les inconnues avant la première session matérielle.

## Ce qui exige un PC ou un appareil réel

Restent nécessairement humains/matériels :

- compréhension réelle d'un nouveau joueur ;
- qualité du rythme et de la tension ;
- confort tactile ;
- lisibilité à taille réelle ;
- DA réellement intégrée ;
- FPS, mémoire, chauffe et throttling ;
- audio sur haut-parleur/casque ;
- haptique ;
- build iOS signé sur iPhone.

Les gates matériels sont définis dans `data/veilleurs/hardware_validation_contract.json` et reliés aux gates joueur lorsque nécessaire.

## Condition de montée en volume

La production de contenu peut accélérer lorsque :

1. les huit gates joueur sont `PASS` ;
2. les gates matériels liés sont `PASS` sur la ou les plateformes cibles concernées ;
3. aucun problème bloquant n'est ouvert ;
4. le vertical slice reste vert en CI ;
5. le procédé de création d'un contenu représentatif est reproductible.

À ce moment-là, le Chapitre I devient réellement notre **moule de production** pour les autres donjons et chapitres.
