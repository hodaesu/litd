# LITD Universe — Audit narratif intégral

> Statut : **audit de cohérence terminé ; renforcement narratif du cycle initial en cours de validation**
>
> Portée : LITD 1, LITD 2 et continuité LITD Universe
>
> Priorité actuelle : **LITD 1 — cycle initial avant toute nouvelle extension narrative NG+**
>
> Registre machine : `data/litd_universe_narrative_inconsistencies.json`

## 1. Objectif

Cet audit vérifie que les textes, dialogues, scénarios, documents de lore et données réellement consommées par le jeu racontent le **même canon**.

Il ne suffit pas que la bible soit cohérente : une ancienne ligne encore chargée par le runtime, une donnée de niveau obsolète ou un test qui protège une règle abandonnée peuvent réintroduire une contradiction dans le jeu. L'audit traite donc documentation, contenu jouable et contrats système comme une seule chaîne narrative.

La règle directrice reste :

> **Rien n'arrive parce que le scénario l'exige. Tout arrive parce que le monde, les personnages et les règles déjà établies le permettent.**

La passe actuelle ajoute une deuxième exigence :

> **Chaque chapitre doit pouvoir être résumé par une question humaine, pas seulement par une information de lore.**

## 2. Corpus contrôlé

La passe couvre notamment :

- bible générale et chronologie ;
- dix chapitres de LITD 1 ;
- quêtes, dialogues, journaux et textes environnementaux ;
- cinématique d'ouverture ;
- données runtime des chapitres VI et VII ;
- civilisations anciennes et mondes extérieurs ;
- Projet Seuil, responsables et Pacte de l'Horizon Fermé ;
- Voile, Lumière, Folie du Voile et Absents ;
- création de personnages et roster prototype ;
- arbres de compétences ;
- capture, personnes humaines, boss, mini-boss et Ange ;
- postgame et Nouveau Cycle+ ;
- psychologie, Peur, Espoir et traces humaines ;
- structure historique de LITD 2 ;
- Sahra Khen, Ilyan Sorei, Tala Veyr et Nuit de Sarn ;
- Rémanence, mort, reconstruction, corps persistants, traumatismes et potions ;
- continuité LITD 2 → Concorde → LITD 1.

## 3. Méthode

Chaque élément important est confronté aux contrôles suivants :

1. **Chronologie** — le fait peut-il arriver à cette date ?
2. **Causalité** — possède-t-il une cause suffisante déjà présente ?
3. **Connaissance** — le personnage peut-il réellement savoir ce qu'il affirme ?
4. **Motivation** — son comportement découle-t-il de son histoire, de ses valeurs et de la situation ?
5. **Révélation** — le joueur apprend-il une vérité au bon moment et avec assez de sources ?
6. **Règles surnaturelles** — Voile et Rémanence respectent-ils conditions, limites et coûts ?
7. **Conséquences** — les effets immédiats et durables restent-ils visibles ?
8. **Systèmes** — les règles de gameplay racontent-elles la même chose que le canon ?
9. **Runtime** — les données réellement chargées n'utilisent-elles pas une ancienne version ?
10. **Inter-jeux** — un fait de LITD 2 laisse-t-il une trace plausible dans LITD 1 ?
11. **Question humaine** — que vit réellement le joueur au-delà de la révélation de lore ?
12. **Après-coup** — quelle trace perceptible reste après une scène ou un choix ?

Les problèmes ont été classés `BLOCKING`, `MAJOR`, `MINOR` ou `OPEN_QUESTION`. Aucune validation n'est autorisée lorsqu'un `BLOCKING` ou `MAJOR` reste non résolu.

## 4. Résultat de cohérence

Le registre contient **19 anomalies ou questions de cohérence** :

- **3 BLOCKING** ;
- **11 MAJOR** ;
- **2 MINOR** ;
- **3 OPEN_QUESTION**.

État :

- `BLOCKING` ouverts : **0** ;
- `MAJOR` ouverts : **0** ;
- `MINOR` ouverts : **0** ;
- `OPEN_QUESTION` non résolues : **0**.

Deux anciennes alertes liées au NG+ sont désormais explicitement classées comme **exceptions de gameplay intentionnelles** : multi-arbres à partir du Premier retour et recrutement des boss/miniboss définis par le catalogue NG+.

## 5. Renforcement narratif du cycle initial

La campagne de référence possède désormais un contrat dédié :

- `docs/LITD1_NARRATION_CYCLE_INITIAL.md` ;
- `data/narrative/base_game_story_contract.json` ;
- `data/narrative/base_game_narrator.json` ;
- `data/narrative/base_game_key_scenes.json` ;
- `scripts/core/base_game_narrative_director.gd`.

Chaque chapitre définit désormais :

- une question humaine ;
- un arc émotionnel de départ, bascule et arrivée ;
- ce que le joueur sait au début et à la fin ;
- les révélations interdites à ce stade ;
- le rôle du narrateur ;
- les personnages sous tension et ce qu'ils ne doivent pas devenir ;
- au moins quatre éléments de narration environnementale ;
- les conséquences à rappeler ;
- la transition causale vers le chapitre suivant.

En plus de cette charpente, **trois scènes-clés minimum par chapitre** sont authored avec : action du joueur, conflit humain, indices environnementaux, dialogues et après-coup.

Le `BaseGameNarrativeDirector` charge ces données et déclenche les ouvertures/fermetures de chapitres du cycle initial. La voix de narration est extradiégétique limitée, non surnaturelle et incapable de révéler une causalité encore inconnue.

## 6. Questions humaines des dix chapitres

1. **Survivre aux Terres de Cendre** — Que sommes-nous prêts à devenir pour survivre sans perdre ce qui rend la survie digne d'être vécue ?
2. **Les traces d'avant la Chute** — Que fait-on d'une vérité qui détruit le récit rassurant d'un accident ?
3. **Le Projet Seuil** — Comment juger une catastrophe collective sans prétendre que tous ceux qui y ont participé ont voulu la même chose ?
4. **La Première Rupture** — Que devient notre recherche de vérité quand l'outil utilisé pour comprendre le monde commence lui-même à le déranger ?
5. **Or-Silex et la Grande Fermeture** — Peut-on sauver le plus grand nombre en condamnant volontairement ceux qu'on ne peut plus atteindre ?
6. **Les Absents** — Avons-nous des devoirs envers des êtres dont nous ne pouvons même pas définir avec certitude la manière d'exister ?
7. **Les responsables vivants** — À quoi sert la justice quand rien ne peut réparer ce qui a été détruit ?
8. **Le monde extérieur** — Peut-on condamner un régime sans condamner tous ceux qui ont vécu sous lui ?
9. **Ce qu'est réellement le Voile** — Que faisons-nous lorsque nous comprenons assez pour agir, mais jamais assez pour être certains ?
10. **La lumière mérite d'être défendue** — Quel monde voulons-nous rendre possible ensemble, sachant qu'aucune solution n'effacera toutes les pertes ?

## 7. Corrections structurelles majeures

### LITD 2 — mort, Rémanence et runs

Une run est une **fenêtre d'opération historique réelle**. Une mort produit un corps réel, la Rémanence reconstruit le protagoniste après un délai mesurable, puis une nouvelle tentative a lieu plus tard dans la même fenêtre d'opération. Le temps ne remonte jamais.

### LITD 2 — Nuit de Sarn et Premier Pacte

La **Nuit de Sarn** est la finale jouable. Les Longues Assemblées et le Premier Pacte appartiennent à l'après-Sarn.

### LITD 1 — révélation de la conspiration

Le prologue peut montrer la Chute, mais pas en expliquer les auteurs. Le chapitre I montre des indices et contradictions. Le chapitre II établit une préparation volontaire. Le chapitre III documente le Projet Seuil et ses responsables.

### Veyra Oss

Veyra participe au Projet Seuil, poursuit les essais malgré des alertes graves, puis tente tardivement de limiter l'emballement. Cette mitigation compte sans l'innocenter.

### Voile — limites et anthropomorphisme

Le Voile ne peut pas servir de solution universelle. La Frontière qui marche reste un phénomène réactif sans intention démontrée.

### Edras Nhal

Toute recherche autorisée est confinée à l'observation de phénomènes déjà présents : aucune nouvelle ouverture, aucun sujet vivant, aucun relais du Projet Seuil réactivé.

### Psychologie et Folie du Voile

La **Folie du Voile** est un phénomène surnaturel spécifique et non un diagnostic psychiatrique réel.

### Civilisations anciennes

Les sept civilisations possèdent une histoire indépendante du Voile et leurs données runtime sont alignées avec leurs dossiers canoniques.

## 8. NG+ — priorité gelée, gameplay conservé

Le gameplay NG+ validé reste en place, notamment :

- multi-arbres à partir du Premier retour ;
- recrutement des boss/miniboss explicitement listés ;
- infrastructure de variations de monde, donjons et ennemis déjà créée.

**Aucune nouvelle extension narrative NG+ ne doit être produite pendant la passe actuelle.**

Le cycle initial reste la référence historique et narrative. Le chantier NG+ reprendra seulement après validation du jeu de base.

## 9. Garde-fous

Les tests vérifient désormais :

- couverture des dix chapitres ;
- présence de la question humaine et de l'arc émotionnel ;
- limites de révélation ;
- narration environnementale ;
- pressions de personnages ;
- scènes-clés authored ;
- voix du narrateur limitée ;
- absence des tics omniscients interdits ;
- chargement runtime du directeur narratif ;
- gel de l'extension narrative NG+ pendant cette passe.

## 10. Critère final

Pour chaque chapitre :

> **Si l'on retirait toutes les phrases expliquant le lore, resterait-il une histoire humaine forte à jouer ?**

Si la réponse est non, le chapitre n'est pas encore terminé.

La fusion reste une décision séparée et ne doit pas être effectuée automatiquement.
