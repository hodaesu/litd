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

## 4. Résultat quantifié

Le registre final contient **19 anomalies ou questions de cohérence** :

- **3 BLOCKING** ;
- **11 MAJOR** ;
- **2 MINOR** ;
- **3 OPEN_QUESTION**.

État final :

- `BLOCKING` ouverts : **0** ;
- `MAJOR` ouverts : **0** ;
- `MINOR` ouverts : **0** ;
- `OPEN_QUESTION` non résolues : **0**.

Toutes les entrées possèdent désormais un problème explicite, une résolution et une liste de fichiers concernés.

## 5. Corrections structurelles majeures

### 5.1 LITD 2 — mort, Rémanence et runs

L'ancien modèle pouvait faire coexister des cadavres réels avec un retour au même instant historique. Cette contradiction est supprimée.

Une run est désormais une **fenêtre d'opération historique réelle**. Une mort produit un corps réel, la Rémanence reconstruit le protagoniste après un délai mesurable, puis une nouvelle tentative a lieu plus tard dans la même fenêtre d'opération. Le temps ne remonte jamais.

La mort ne valide pas à elle seule un jalon de guerre. En revanche, les conséquences locales proportionnées au temps écoulé peuvent évoluer.

### 5.2 LITD 2 — Nuit de Sarn et Premier Pacte

La **Nuit de Sarn** est la finale jouable. Les Longues Assemblées et le Premier Pacte appartiennent à l'après-Sarn, dans l'épilogue historique ou le postgame.

Les Trois Éveils ne sont pas inventés soudainement à Sarn : la nuit les cristallise après un long processus.

### 5.3 LITD 1 — révélation de la conspiration

La cinématique d'ouverture et certains textes du chapitre I révélaient trop tôt l'implication étrangère et des modèles du Voile normalement établis plus tard.

Le prologue peut montrer la Chute, mais pas en expliquer les auteurs. Le chapitre I montre des indices et contradictions. Le chapitre II établit une préparation volontaire. Le chapitre III documente le Projet Seuil et ses responsables.

La quête **Trois vérités pour une borne** ne conclut plus que l'objet change de fonction selon son observateur : Meira Sen constate seulement que trois sources se contredisent et refuse de transformer cette contradiction en théorie prouvée.

### 5.4 Veyra Oss

Le canon est unifié : Veyra participe longuement au Projet Seuil, poursuit les essais après des alertes graves, puis tente **tardivement de limiter l'emballement et de renforcer ce qui peut encore être stabilisé**.

Cette mitigation ne l'innocente pas et ne la transforme pas rétroactivement en héroïne secrète.

### 5.5 Voile — limites et anthropomorphisme

Le Voile ne peut pas servir de solution universelle. Il ne crée pas librement n'importe quel objet ou événement, ne réécrit pas l'histoire établie et doit respecter le corpus de limites canonique.

**La Frontière qui marche** n'est plus décrite comme un phénomène conscient ou auto-protecteur. Elle possède des contre-effets reproductibles, mais aucune donnée ne permet d'affirmer qu'elle choisit, veut, perçoit ou se défend. Même l'option de résonance est un test physique et non une « négociation » avec une volonté supposée.

### 5.6 Edras Nhal

L'ancienne « expérience limitée » créait un trou narratif permettant de refaire le Projet Seuil sous un autre nom.

Elle devient une **observation instrumentale confinée** : phénomène déjà présent uniquement, aucune nouvelle ouverture, aucun sujet vivant exposé, aucun relais du Projet Seuil réactivé, arrêt automatique au premier dépassement et aucun contrôle du protocole par Edras.

### 5.7 Meira Sen

`Meira Saan` était une variante obsolète. L'identité canonique active est **Meira Sen**.

### 5.8 Psychologie et Folie du Voile

La **Folie du Voile** est un phénomène surnaturel spécifique. Elle n'est ni une maladie mentale réelle ni un diagnostic psychiatrique.

Peur, souvenirs de stress, habitudes de protection et autres traces humaines restent des vécus variables et non des étiquettes diagnostiques automatiques. Le canon interdit explicitement les équivalences maladie mentale = violence, mal, perception surnaturelle ou destin inévitable.

Certaines clés techniques historiques nommées `madness` peuvent subsister temporairement pour compatibilité, mais leur sens canonique est désormais explicitement limité à la Folie du Voile.

### 5.9 Nouveau Cycle+

Le NG+ ne change plus deux règles identitaires de LITD 1 :

- choisir un arbre verrouille toujours les deux autres, dans **tous les cycles** ;
- les boss et mini-boss ne deviennent pas des créatures capturables en NG+.

Capture de créature, arrestation d'une personne, jugement et coopération volontaire sont des systèmes distincts.

Le runtime, l'UI, les données et les tests ont été alignés. Les anciennes sauvegardes contenant des `boss_recruit` issus de la règle abandonnée sont nettoyées au chargement au lieu de perpétuer silencieusement la contradiction.

### 5.10 Civilisations anciennes

Les périodes runtime sont alignées avec les dossiers canoniques. Les sept civilisations possèdent désormais une histoire propre qui ne se résume pas à fournir chacune une révélation parfaitement utile sur le Voile.

Leurs erreurs, échanges, économies, institutions et déclins existent indépendamment de la fonction qu'elles remplissent dans l'enquête du joueur.

## 6. Propagation système ↔ narration

L'audit a également corrigé des divergences où la documentation était bonne mais le jeu aurait pu raconter autre chose :

- dialogues legacy encore chargés ;
- roster prototype pouvant être pris pour le roster canonique ;
- données de compétences réduisant incorrectement le modèle ennemi ;
- NG+ runtime qui réouvrait les arbres malgré le canon ;
- capture de boss encore activable dans le code ;
- textes du chapitre VI attribuant encore une volonté à la Frontière ;
- données jouables du chapitre VII portant encore l'ancienne version de Veyra et d'Edras.

La règle est désormais : **une décision de canon n'est pas considérée propagée tant que les sources runtime et les tests qui la représentent ne sont pas alignés.**

## 7. Garde-fous ajoutés

`tests/python/test_narrative_consistency_registry.py` protège désormais le registre lui-même :

- total des entrées recalculé ;
- comptage par gravité recalculé ;
- IDs uniques ;
- problème, résolution et fichiers obligatoires ;
- impossibilité de déclarer `READY_FOR_REVIEW` avec un `BLOCKING` ou `MAJOR` non résolu.

Les tests NG+, chapitre VI, chapitre VII et psychologie protègent également les corrections correspondantes.

## 8. Points à surveiller dans les futurs ajouts

Ils ne constituent pas des incohérences ouvertes, mais doivent rester des règles de production :

1. toute nouvelle capacité du Voile doit être comparée aux limites canoniques avant écriture ;
2. toute nouvelle capacité de Rémanence doit conserver délai, coût, matière, mémoire et absence de voyage temporel ;
3. les clés techniques legacy `madness` devront idéalement être renommées lors d'une migration d'ingénierie dédiée, sans changer leur sémantique actuelle ;
4. les noms et lignées du roster prototype ne deviennent pas canon par simple réutilisation d'asset ;
5. une nouvelle vérité majeure doit être étayée par plusieurs sources ou par une observation reproductible ;
6. un phénomène réactif n'est jamais automatiquement une conscience ;
7. une exception de gameplay ne doit jamais annuler silencieusement une règle identitaire du canon.

## 9. Conclusion

À l'issue de cette passe, **aucune incohérence narrative `BLOCKING` ou `MAJOR` connue ne reste ouverte dans le corpus audité**.

La branche peut passer en revue et en CI. Cela ne signifie pas que toute future écriture sera automatiquement cohérente : cela signifie que le canon actuel possède désormais des règles explicites, des corrections propagées jusqu'au runtime et des tests capables de détecter plusieurs classes de régression.

La fusion reste une décision séparée et ne doit pas être effectuée automatiquement.
