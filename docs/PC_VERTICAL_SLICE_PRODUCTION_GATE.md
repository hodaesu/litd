# LITD — Gate de production de la verticale PC

Date : 2026-09-09

## Objet

Ce document transforme le Chapitre I déjà défini en un périmètre PC testable, suffisamment petit pour être joué de bout en bout et suffisamment complet pour vérifier la signature de LITD avant d'étendre la production.

Le but n'est pas de représenter tout le jeu. Le but est de vérifier que la boucle fondamentale est compréhensible, distincte et rejouable.

## Boucle cible du slice

**Sanctuaire → préparation → exploration courte → 3 à 4 combats distincts → événement/récupération → élite → boss → conséquence → retour au Sanctuaire.**

Le retour au Sanctuaire est obligatoire : une session qui s'arrête au boss ne valide pas la boucle LITD.

## Périmètre jouable verrouillé

### Groupe joueur

- 4 Veilleurs jouables maximum dans cette verticale.
- Un rôle lisible par Veilleur dès les premières minutes.
- Les différences doivent être visibles dans les actions disponibles, la position, la résistance, les blessures et la gestion du risque ; pas seulement dans les statistiques.

### Ennemis

Cible : **5 à 6 archétypes maximum** dans le slice.

La sélection doit couvrir au minimum :

1. un ennemi de mêlée simple ;
2. un ennemi à pression de position ou de portée ;
3. un ennemi qui met en jeu Peur/Folie ;
4. une créature permettant de tester coexistence/capture ;
5. une élite ;
6. le boss du Chapitre I lorsque celui-ci est inclus dans le build.

Les variantes de statistiques ne comptent pas comme des archétypes supplémentaires.

## Systèmes indispensables

Le build de test doit permettre d'observer réellement les systèmes suivants :

- préparation au Sanctuaire ;
- équipement de début de partie ;
- progression minimale utile à la session ;
- positionnement en combat ;
- anatomie et états corporels ;
- blessures avec conséquences perceptibles ;
- Peur et Folie ;
- Lumière lorsqu'elle modifie une décision ;
- capture ou coexistence avec une créature ;
- Rémanence lorsque la mort, les traces ou les conséquences d'une expédition l'exigent ;
- conséquence post-boss ou post-expédition ;
- retour au Sanctuaire et lecture de cette conséquence.

Un système n'est considéré comme présent que si un testeur peut le rencontrer et en constater l'effet sans explication extérieure.

## Séquence de test recommandée

### 1. Sanctuaire — préparation

Le joueur doit pouvoir :

- identifier son groupe ;
- comprendre où préparer l'expédition ;
- équiper ou vérifier au moins un élément utile ;
- lancer la sortie sans tutoriel oral.

### 2. Exploration courte

Objectifs :

- apprendre le déplacement ;
- comprendre où se trouve l'information contextuelle ;
- introduire un premier choix de risque/récompense.

### 3. Combat A — lecture de base

Valide :

- ordre de tour ;
- ciblage ;
- position ;
- actions principales ;
- fin de combat.

### 4. Combat B — pression mentale

Valide :

- Peur ;
- Folie ou montée vers un état critique ;
- choix entre vitesse, sécurité et ressources.

### 5. Événement / récupération

Le joueur doit rencontrer un moment sans combat qui l'oblige à interpréter l'état de son groupe et à préparer la suite.

### 6. Combat C — anatomie / blessures

Valide :

- blessure localisée ou conséquence corporelle ;
- différence entre simple perte de points et dégradation fonctionnelle ;
- changement de décision dû à l'état d'un membre.

### 7. Rencontre créature — capture / coexistence

Le test doit proposer au moins une situation où tuer n'est pas la seule résolution mécanique pertinente.

### 8. Élite

L'élite doit exiger l'utilisation d'au moins deux systèmes déjà rencontrés, plutôt qu'une simple hausse de PV.

### 9. Boss

Le boss doit raconter quelque chose par ses mécaniques et forcer une décision qui ne se réduit pas à infliger davantage de dégâts.

### 10. Conséquence et retour

La session se termine uniquement après :

- une conséquence lisible ;
- le retour au Sanctuaire ;
- une modification ou information persistante visible par le joueur.

## Ce qui reste hors périmètre

Pour le premier gate PC, ne pas bloquer la validation sur :

- la totalité des archives du chapitre ;
- l'ensemble des équipements ;
- tous les héros et ennemis prévus pour la version finale ;
- la totalité des trois arbres de 15 compétences de chaque personnage ;
- les animations finales ;
- les assets finaux ;
- la localisation complète ;
- l'équilibrage fin de campagne.

Les placeholders de développement sont acceptables tant qu'ils restent conformes aux règles de provenance et ne sont pas considérés comme des assets de release.

## Gate fonctionnel

La verticale PC passe au playtest naïf uniquement si :

- [ ] le build démarre sans manipulation de développeur ;
- [ ] la boucle Sanctuaire → expédition → retour est jouable de bout en bout ;
- [ ] au moins 3 combats ont des intentions différentes ;
- [ ] Peur/Folie est rencontrable ;
- [ ] une blessure ou un état anatomique modifie une décision ;
- [ ] la capture/coexistence est testable ;
- [ ] une conséquence persiste après l'expédition ;
- [ ] aucun blocage empêche un joueur naïf de poursuivre ;
- [ ] les erreurs critiques sont visibles dans les logs et ne sont pas masquées.

## Gate de lisibilité

Avant les cinq playtests, un observateur interne doit pouvoir répondre oui aux questions suivantes :

- l'objectif immédiat est-il visible sans texte explicatif hors jeu ?
- le joueur peut-il identifier ce qui est cliquable ou sélectionnable ?
- l'état des quatre Veilleurs est-il lisible avant une décision ?
- les conséquences d'une blessure sont-elles visibles ?
- Peur/Folie est-elle distinguable de la santé physique ?
- les informations critiques sont-elles accessibles sans HUD permanent inutile ?
- le retour au Sanctuaire montre-t-il clairement qu'une conséquence a été enregistrée ?

## Sortie de ce gate

Quand toutes les cases fonctionnelles sont validées, utiliser `docs/PLAYTEST_5_NAIVE_TESTERS_PROTOCOL.md` sans expliquer les systèmes aux participants. Les corrections issues des cinq sessions priment ensuite sur l'ajout de nouveau contenu non indispensable au slice.
