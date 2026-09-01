# LITD Universe — Audit narratif intégral

> Statut : **audit de bout en bout terminé — prêt pour revue**
>
> Portée : LITD 1, LITD 2 et continuité LITD Universe
>
> Registre machine : `data/litd_universe_narrative_inconsistencies.json`

## 1. Objectif

Cet audit vérifie que les textes, dialogues, scénarios, documents de lore et données réellement consommées par le jeu racontent le **même canon**.

Il ne suffit pas que la bible soit cohérente : une ancienne ligne encore chargée par le runtime, une donnée de niveau obsolète ou un test qui protège une règle abandonnée peuvent réintroduire une contradiction dans le jeu. L'audit traite donc documentation, contenu jouable et contrats système comme une seule chaîne narrative.

La règle directrice reste :

> **Rien n'arrive parce que le scénario l'exige. Tout arrive parce que le monde, les personnages et les règles déjà établies le permettent.**

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

Chaque élément important a été confronté aux contrôles suivants :

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

Les problèmes ont été classés `BLOCKING`, `MAJOR`, `MINOR` ou `OPEN_QUESTION`. Aucune validation n'est autorisée lorsqu'un `BLOCKING` ou `MAJOR` reste non résolu.

Une précision importante a été ajoutée pendant la revue : **une exception volontaire de gameplay n'est pas une incohérence si son statut est explicitement défini et si elle n'est pas présentée comme un fait historique littéral**. C'est le cas de certaines récompenses du NG+.

## 4. Résultat quantifié

Le registre final contient **19 anomalies ou questions auditées** :

- **3 BLOCKING** ;
- **11 MAJOR** ;
- **2 MINOR** ;
- **3 OPEN_QUESTION**.

Deux entrées NG+ conservent leur gravité historique parce qu'elles ont révélé une ambiguïté de contrat pendant l'audit, mais leur résolution est désormais classée **`INTENTIONAL_GAMEPLAY_EXCEPTION`** : l'audit avait pris à tort des mécaniques NG+ voulues pour des violations du cycle initial.

État final :

- `BLOCKING` ouverts : **0** ;
- `MAJOR` ouverts : **0** ;
- `MINOR` ouverts : **0** ;
- `OPEN_QUESTION` non résolues : **0**.

## 5. Corrections structurelles majeures

### 5.1 LITD 2 — mort, Rémanence et runs

Une run est une **fenêtre d'opération historique réelle**. Une mort produit un corps réel, la Rémanence reconstruit le protagoniste après un délai mesurable, puis une nouvelle tentative a lieu plus tard dans la même fenêtre d'opération. Le temps ne remonte jamais.

La mort ne valide pas à elle seule un jalon de guerre. Les conséquences locales proportionnées au temps écoulé peuvent évoluer.

### 5.2 LITD 2 — Nuit de Sarn et Premier Pacte

La **Nuit de Sarn** est la finale jouable. Les Longues Assemblées et le Premier Pacte appartiennent à l'après-Sarn, dans l'épilogue historique ou le postgame.

### 5.3 LITD 1 — révélation de la conspiration

Le prologue peut montrer la Chute, mais pas en expliquer les auteurs. Le chapitre I montre des indices et contradictions. Le chapitre II établit une préparation volontaire. Le chapitre III documente le Projet Seuil et ses responsables.

La quête **Trois vérités pour une borne** ne conclut plus que l'objet change de fonction selon son observateur : Meira Sen constate seulement que trois sources se contredisent et refuse de transformer cette contradiction en théorie prouvée.

### 5.4 Veyra Oss

Veyra participe longuement au Projet Seuil, poursuit les essais après des alertes graves, puis tente **tardivement de limiter l'emballement et de renforcer ce qui peut encore être stabilisé**. Cette mitigation ne l'innocente pas.

### 5.5 Voile — limites et anthropomorphisme

Le Voile ne peut pas servir de solution universelle. Il ne crée pas librement n'importe quel objet ou événement et ne réécrit pas l'histoire établie.

**La Frontière qui marche** possède des contre-effets reproductibles, mais aucune donnée ne permet d'affirmer qu'elle choisit, veut, perçoit ou se défend consciemment.

### 5.6 Edras Nhal

Toute recherche autorisée devient une **observation instrumentale confinée** : phénomène déjà présent uniquement, aucune nouvelle ouverture, aucun sujet vivant exposé, aucun relais du Projet Seuil réactivé, arrêt automatique au premier dépassement et aucun contrôle du protocole par Edras.

### 5.7 Meira Sen

`Meira Saan` était une variante obsolète. L'identité canonique active est **Meira Sen**.

### 5.8 Psychologie et Folie du Voile

La **Folie du Voile** est un phénomène surnaturel spécifique. Elle n'est ni une maladie mentale réelle ni un diagnostic psychiatrique.

Peur, souvenirs de stress, habitudes de protection et autres traces humaines restent des vécus variables et non des étiquettes diagnostiques automatiques.

### 5.9 Nouveau Cycle+ — correction de l'audit

L'audit avait initialement traité deux mécaniques du NG+ comme des contradictions. Cette interprétation était incorrecte : **elles font volontairement partie du gameplay de rejouabilité**.

Le contrat réel est désormais explicite :

#### Cycle initial

- le premier arbre choisi verrouille les deux autres ;
- les règles ordinaires de capture s'appliquent ;
- le cycle initial reste l'histoire de référence.

#### À partir du Premier retour

- **les trois arbres s'ouvrent** : le joueur peut répartir ses points entre offense, défense et spécial tout en respectant coûts, niveaux et prérequis internes ;
- **les boss et mini-boss explicitement présents dans `ngplus_boss_recruits.json` deviennent recrutables** ;
- leur version de compagnon conserve identité, signature et archétype mais n'hérite pas de la puissance brute de la version boss ;
- ces privilèges sont des abstractions de replay et ne signifient pas que le cycle initial s'est historiquement déroulé autrement.

L'Ange n'est pas actuellement dans le catalogue NG+ et reste hors de ce système.

### 5.10 Nouveau Cycle+ — contrat de rejouabilité « wahou »

Le NG+ ne doit pas être un simple multiplicateur de PV et dégâts.

Une différence forte doit être perceptible **dans les quinze premières minutes** et chaque cycle doit agir sur quatre couches :

1. **monde** — routes, refuges, patrouilles, quartiers ou traces ;
2. **donjons** — recomposition contrôlée de salles authored, secrets et dangers ;
3. **ennemis** — contre-mesures et comportements tactiques propres aux cycles ;
4. **narration** — nouvelles couches de contexte qui approfondissent sans réécrire les faits.

Les profils actuels sont :

- Premier retour — **Le monde se décale** ;
- Deuxième veille — **Les ennemis apprennent** ;
- Troisième mémoire — **Les couches profondes** ;
- Cycle profond — **La Concorde des possibles**.

Le générateur hybride conserve les géométries fabriquées à la main. Le NG+ change leur sélection, les branches optionnelles, les dangers compatibles et la seed ; les scènes marquées immuables restent intactes.

### 5.11 Civilisations anciennes

Les périodes runtime sont alignées avec les dossiers canoniques. Les sept civilisations possèdent une histoire propre qui ne se résume pas à fournir chacune une révélation parfaitement utile sur le Voile.

## 6. Propagation système ↔ narration

L'audit a corrigé des divergences où la documentation était bonne mais le jeu aurait pu raconter autre chose : dialogues legacy, roster prototype ambigu, progression ennemie incomplète, anciennes formulations du chapitre VI, ou données du chapitre VII portant une ancienne version de Veyra et Edras.

Pour le NG+, la propagation fonctionne désormais dans l'autre sens : les tests protègent explicitement les **exceptions de replay voulues** — multi-arbres et catalogue de boss recrutables — afin qu'un futur audit ne les supprime plus par erreur.

La règle est : **une décision de canon ou de gameplay verrouillée n'est pas considérée propagée tant que documentation, runtime et tests ne sont pas alignés.**

## 7. Garde-fous ajoutés

`tests/python/test_narrative_consistency_registry.py` protège le registre : total, gravités, IDs, problème/résolution/fichiers et absence de BLOCKING/MAJOR ouverts.

`tests/python/test_ngplus_cycle_variants.py` protège désormais aussi le contrat de rejouabilité :

- NG+ multi-arbres à partir du cycle 1 ;
- recrutement des boss/miniboss NG+ ;
- quatre couches de variation ;
- profils couvrant Premier retour, Deuxième veille, Troisième mémoire et cycles profonds ;
- branchement du directeur NG+ sur Godot, les donjons et les comportements ennemis ;
- interdiction de présenter le NG+ comme une boucle temporelle ou une réécriture de l'histoire.

## 8. Points à surveiller dans les futurs ajouts

1. toute nouvelle capacité du Voile doit être comparée aux limites canoniques ;
2. toute nouvelle capacité de Rémanence doit conserver délai, coût, matière, mémoire et absence de voyage temporel ;
3. les clés techniques legacy `madness` devront idéalement être renommées lors d'une migration dédiée ;
4. les noms et lignées du roster prototype ne deviennent pas canon par réutilisation d'asset ;
5. une nouvelle vérité majeure doit être étayée ;
6. un phénomène réactif n'est jamais automatiquement une conscience ;
7. une exception NG+ doit être explicitement définie comme **gameplay de replay** lorsqu'elle dépasse les possibilités du cycle initial ;
8. une exception NG+ ne peut jamais être utilisée pour réécrire rétroactivement les faits du premier cycle.

## 9. Conclusion

À l'issue de cette passe, **aucune incohérence narrative `BLOCKING` ou `MAJOR` connue ne reste ouverte dans le corpus audité**.

Le NG+ conserve ses deux récompenses de gameplay voulues — multi-arbres et recrutement de boss/miniboss — et possède désormais une architecture destinée à rendre chaque nouveau cycle immédiatement différent par le monde, les donjons, les ennemis et la narration.

La fusion reste une décision séparée et ne doit pas être effectuée automatiquement.
