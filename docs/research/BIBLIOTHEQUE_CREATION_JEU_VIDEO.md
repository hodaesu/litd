# Bibliothèque LITD — création de jeu vidéo

Date de veille : 2026-09-08

## But

Cette bibliothèque sert de référence de production pour LITD Universe et, en priorité, **LITD : Les Veilleurs**. Elle ne remplace pas les bibles de gameplay, de lore ou d'art existantes : elle rassemble les méthodes de conception et de réalisation qui permettent de transformer ces intentions en un jeu testable, cohérent, performant et livrable.

Principe directeur : **concevoir l'expérience recherchée, tester les hypothèses tôt, produire seulement ce qui a été validé, mesurer ce qui peut l'être, puis itérer**.

---

## 1. Cycle de création recommandé

### 1. Vision / concept

Livrables minimaux :

- promesse joueur en une phrase ;
- public et plateformes cibles ;
- piliers de design ;
- boucle de jeu principale ;
- différenciation ;
- contraintes techniques et commerciales ;
- risques principaux ;
- critères permettant d'abandonner ou de modifier une idée.

Une fonctionnalité n'entre pas en production parce qu'elle est intéressante. Elle entre en production parce qu'elle sert un pilier, résout un problème joueur ou prouve une hypothèse.

### 2. Préproduction

Objectif : réduire les inconnues avant d'augmenter le coût de production.

À valider :

- plaisir et lisibilité de la boucle principale ;
- architecture technique ;
- direction artistique ;
- pipeline d'assets ;
- UX et contrôles ;
- budgets de performance ;
- méthode de sauvegarde ;
- localisation ;
- accessibilité ;
- capacité réelle à produire le volume de contenu prévu.

La préproduction doit livrer des **preuves**, pas seulement des documents : prototypes, tests, benchmarks et une verticale jouable.

### 3. Prototypes

Un prototype doit répondre à une question précise :

- le ciblage anatomique est-il compréhensible ?
- la Peur crée-t-elle des décisions intéressantes ?
- le combat reste-t-il lisible sur téléphone ?
- la capture d'une créature ajoute-t-elle un choix tactique ou seulement une couche de gestion ?

Le prototype peut être laid, incomplet et jetable. Son succès se mesure à la qualité de la réponse obtenue.

### 4. Vertical slice

Une verticale n'est pas un mini-jeu séparé. Elle doit prouver que les systèmes, le contenu et le pipeline fonctionnent ensemble à une qualité proche de la cible.

Elle valide notamment :

- boucle complète ;
- rendu représentatif ;
- UI/UX ;
- son ;
- sauvegarde ;
- performance ;
- production d'assets ;
- QA ;
- durée et charge de production ;
- capacité à répéter le procédé pour les chapitres suivants.

Pour les jeux systémiques, la verticale doit aussi prouver les **interactions entre systèmes**, pas seulement une courte séquence très polie.

### 5. Production

La production est une phase de répétition maîtrisée : construire du contenu avec des outils, contrats et standards déjà validés.

Règle : toute nouveauté qui modifie fortement le risque repasse temporairement en mode prototype.

### 6. Alpha

Le jeu est jouable de bout en bout avec les systèmes majeurs présents. Le contenu peut encore manquer de finition.

Priorité : intégration, bugs bloquants, rythme, économie, sauvegarde, cohérence globale.

### 7. Beta

Le périmètre est presque gelé. Les changements de fond deviennent exceptionnels.

Priorité : stabilité, performance, UX, accessibilité, compatibilité appareils, équilibrage, localisation, polish.

### 8. Release / post-release

Préparer :

- builds reproductibles ;
- conformité stores ;
- crash/ANR monitoring ;
- versioning ;
- notes de version ;
- sauvegardes compatibles ;
- plan de correctifs ;
- postmortem.

---

## 2. Game design : concevoir depuis l'expérience joueur

Le cadre MDA distingue :

- **Mechanics** : règles, données, algorithmes ;
- **Dynamics** : comportements qui émergent en jeu ;
- **Aesthetics** : expérience et émotions recherchées.

Pour LITD, une mécanique doit toujours être reliée à une dynamique observable et à un effet joueur attendu.

Exemple :

`blessure anatomique -> perte fonctionnelle et adaptation tactique -> vulnérabilité, tension, conséquence corporelle lisible`.

### Fiche obligatoire pour une nouvelle mécanique

- problème ou intention joueur ;
- pilier servi ;
- hypothèse ;
- mécanique ;
- dynamique attendue ;
- feedback visuel/sonore/haptique ;
- risques d'exploitation ou de frustration ;
- interactions avec les autres systèmes ;
- métrique ou observation de playtest ;
- critère d'acceptation ;
- critère de suppression.

---

## 3. Documentation : une source canonique, des contrats exécutables

Les documents doivent rester courts, vivants et reliés au jeu.

Hiérarchie recommandée :

1. vision et piliers ;
2. bibles spécialisées ;
3. fiches de systèmes ;
4. données structurées ;
5. contrats/audits ;
6. implémentation ;
7. tests ;
8. rapports.

Éviter les documents qui décrivent un état que le dépôt ne peut pas vérifier. Dès qu'une règle devient objectivable, la transformer en donnée ou en audit automatique.

---

## 4. Architecture Godot

Références officielles Godot : organisation de projet, scènes, scripts, autoloads, données, profilage, résolution multiple, internationalisation et audio.

Règles LITD :

- scènes réutilisables et autonomes ;
- dépendances explicites ;
- signaux/interfaces plutôt que chemins fragiles ;
- données séparées de la présentation ;
- autoloads limités aux services réellement globaux ;
- assets proches de leur domaine d'usage quand cela améliore la maintenance ;
- contenu tiers clairement isolé ;
- style GDScript uniforme ;
- aucune optimisation sans mesure ;
- profilage par scène et cas d'usage.

### Data-driven

Les héros, ennemis, compétences, blessures, loot, quêtes et paramètres d'équilibrage doivent être décrits par des données canoniques lorsque cela permet :

- validation automatique ;
- tests ;
- comparaison ;
- équilibrage ;
- localisation ;
- migration de sauvegarde ;
- génération d'outils.

---

## 5. Direction artistique

Une DA exploitable n'est pas seulement une collection d'images de référence. Elle définit un **langage visuel reproductible**.

La bible doit préciser :

- 3 à 5 piliers visuels ;
- formes dominantes ;
- silhouettes ;
- proportions ;
- valeurs clair/foncé ;
- palettes ;
- matériaux ;
- lumière ;
- niveau de détail ;
- règles de composition ;
- architecture ;
- costumes ;
- créatures ;
- UI ;
- VFX ;
- animation ;
- exemples « oui » / « non » ;
- budgets techniques par catégorie d'asset.

### Revue d'asset

Chaque asset final doit passer :

`référence -> intention -> silhouette -> valeur -> couleur -> matière -> intégration -> lecture mobile -> budget technique -> validation en jeu`.

L'asset n'est pas validé sur une planche seule. Il est validé dans la scène, à la distance et à la taille où le joueur le voit réellement.

---

## 6. UI/UX mobile

Principes :

- le toucher est l'entrée principale sur iPhone ;
- réduire les contrôles virtuels quand l'interaction directe est plus claire ;
- grandes zones tactiles et espacées ;
- état pressé visible même sous le doigt ;
- feedback multimodal : visuel + son + haptique lorsque pertinent ;
- ne jamais transmettre une information essentielle par la couleur seule ;
- tester les safe areas, découpes d'écran et ratios extrêmes ;
- utiliser anchors/containers pour la mise en page adaptative ;
- valider sur appareil réel, pas uniquement dans l'éditeur.

---

## 7. Accessibilité

Les Game Accessibility Guidelines et les Xbox Accessibility Guidelines sont utilisées comme grille de conception, même pour une sortie mobile.

Base à viser dès la préproduction :

- taille de texte lisible et réglable lorsque nécessaire ;
- contraste ;
- information non dépendante de la couleur seule ;
- sous-titres ;
- volumes séparés ;
- haptique désactivable ;
- contrôles simples, larges et reconfigurables quand applicable ;
- rythme de lecture contrôlé par le joueur ;
- sauvegarde des réglages ;
- rappel des objectifs et contrôles ;
- absence de clignotements dangereux ;
- playtests incluant des besoins d'accessibilité.

Le gore systémique doit rester mécaniquement lisible même si une option visuelle réduit son intensité.

---

## 8. Performance mobile

La performance est un budget de design.

Mesures minimales :

- FPS et frame time ;
- CPU ;
- GPU ;
- mémoire ;
- draw calls ;
- temps de chargement ;
- chauffe / throttling ;
- taille d'installation ;
- stabilité/crash/ANR.

Méthode :

`mesurer -> identifier CPU/GPU/mémoire -> corriger -> mesurer à nouveau -> tester sur appareils cibles`.

Godot rappelle que les GPU mobiles sont sensibles à l'overdraw et aux transparences superposées. Les effets plein écran, Viewports, shaders et post-traitements doivent donc être budgétés et testés tôt.

Pour LITD, conserver au minimum :

- un profil d'appareil faible/médian/cible ;
- un budget par scène ;
- un mode performance et un mode qualité seulement si les mesures montrent qu'ils sont utiles ;
- une scène de stress reproductible.

---

## 9. Audio

Pipeline :

`intention -> source -> édition -> normalisation/mix -> intégration bus -> ducking/effets -> test haut-parleur -> test casque -> budget CPU/mémoire`.

Buses recommandés :

- Master ;
- Musique ;
- Ambiance ;
- SFX ;
- UI ;
- Voix ;
- éventuellement Gore/Impact si le mix systémique le justifie.

Éviter le clipping et tester le mix sur les petits haut-parleurs de téléphone.

---

## 10. Narration et contenu

Pour un jeu systémique comme LITD, le récit doit être porté par plusieurs couches :

- action ;
- conséquence ;
- environnement ;
- texte ;
- animation ;
- audio ;
- réactions du Sanctuaire ;
- systèmes persistants.

Les révélations majeures ne doivent pas dépendre d'un seul texte ou d'une seule cinématique. La compréhension doit pouvoir émerger par recoupement.

---

## 11. Playtests

Trois familles :

### Test fonctionnel
Le système fait-il ce qui est prévu ?

### Test d'utilisabilité
Le joueur comprend-il quoi faire sans explication externe ?

### Test d'expérience
Le joueur ressent-il ce que le design cherche à produire ?

Le développeur ne doit pas expliquer pendant un test d'utilisabilité. Observer d'abord, interroger après.

Capturer :

- objectif du test ;
- profil du testeur ;
- première incompréhension ;
- hésitations ;
- erreurs ;
- temps par étape ;
- abandon ;
- commentaires spontanés ;
- ressenti après la session.

Corriger les problèmes récurrents, pas chaque préférence individuelle.

---

## 12. QA et intégration continue

Chaque changement doit être classé par risque :

- données ;
- gameplay ;
- UI ;
- sauvegarde ;
- performance ;
- rendu ;
- audio ;
- plateforme ;
- contenu narratif.

Chaque risque doit avoir un contrôle adapté : validation statique, test automatisé, smoke, test visuel ou test matériel.

Une CI verte ne signifie pas que le jeu est bon. Elle signifie que les régressions objectivables couvertes par la CI n'ont pas été détectées.

---

## 13. Localisation

Préparer la localisation avant la fin de production :

- IDs de chaînes stables ;
- aucun texte de gameplay durci dans les scènes quand il doit être traduit ;
- pseudolocalisation ;
- espaces réservés aux textes plus longs ;
- pluriels et variables contrôlés ;
- polices couvrant les langues cibles ;
- captures d'écran contextuelles pour les traducteurs.

Godot recommande l'approche par identifiants uniques pour les projets multilingues importants.

---

## 14. Production et gestion du périmètre

Toute tâche doit avoir :

- résultat attendu ;
- propriétaire ;
- dépendances ;
- risques ;
- critères d'acceptation ;
- test ;
- statut.

### Definition of Ready

Une tâche est prête si :

- elle sert un objectif clair ;
- les dépendances sont connues ;
- les assets/données nécessaires sont identifiés ;
- les critères d'acceptation existent ;
- le test est défini.

### Definition of Done

Une tâche est terminée si :

- intégrée en jeu ;
- testée ;
- documentation canonique mise à jour ;
- pas de régression connue critique ;
- performance vérifiée si concernée ;
- accessibilité/UX vérifiée si concernée ;
- sauvegarde/migration vérifiée si concernée ;
- rapport ou preuve disponible.

---

## 15. Sources de référence

### Design / production

- Hunicke, LeBlanc, Zubek — **MDA: A Formal Approach to Game Design and Game Research** : https://users.cs.northwestern.edu/~hunicke/MDA.pdf
- Game Developer — **What you should take out of Pre-Production** : https://www.gamedeveloper.com/game-platforms/what-you-should-take-out-of-pre-production
- Game Developer — **Building Simulations, Part 4 — The Connected Systems Playable** : https://www.gamedeveloper.com/production/building-simulations-part-4-the-connected-systems-playable
- Game Developer — postmortems et retours de production : https://www.gamedeveloper.com/

### Godot

- Best practices : https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html
- Project organization : https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html
- Profiler / performance : https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html
- Performance : https://docs.godotengine.org/en/stable/tutorials/performance/index.html
- Multiple resolutions : https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html
- Internationalization : https://docs.godotengine.org/en/stable/tutorials/i18n/index.html
- Audio : https://docs.godotengine.org/en/stable/tutorials/audio/index.html

### Mobile

- Apple Human Interface Guidelines — Games : https://developer.apple.com/design/human-interface-guidelines/designing-for-games
- Apple — Game controls : https://developer.apple.com/design/human-interface-guidelines/game-controls
- Apple — graphics performance : https://developer.apple.com/documentation/metal/improving-your-games-graphics-performance-and-settings
- Android — game performance : https://developer.android.com/games/optimize/gameperformance
- Android — game optimization : https://developer.android.com/games/optimize/overview
- Android — game quality guidelines : https://developer.android.com/games/guidelines

### Accessibilité

- Game Accessibility Guidelines : https://gameaccessibilityguidelines.com/
- Xbox Accessibility Guidelines : https://learn.microsoft.com/en-us/xbox/accessibility/guidelines

### Direction artistique

- Game Developer — **Who Needs An Art Bible? Game Art Direction From Indie To AAA** : https://www.gamedeveloper.com/design/who-needs-an-art-bible-game-art-direction-from-indie-to-aaa

---

## 16. Règle de veille

Cette bibliothèque est vivante. Toute nouvelle pratique adoptée doit répondre à trois questions :

1. Quel problème réel de LITD résout-elle ?
2. Comment la vérifier ?
3. Quel document, contrat, test ou outil devient la source canonique ?

Aucune « bonne pratique » n'est appliquée mécaniquement si elle n'améliore pas le jeu, le risque, la vitesse ou la qualité de production.
