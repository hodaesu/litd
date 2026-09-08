# Benchmark roguelike / dungeon crawler — boucle de tension LITD

## Statut

Document de travail destiné à transformer l’étude de jeux comparables en décisions testables pour **Light in the Dark**.

Ce benchmark ne vise pas à copier des systèmes existants. Chaque observation doit produire une hypothèse LITD, un test et un critère de décision.

---

## 1. Question de départ

Comment faire en sorte que chaque portion d’expédition demande une décision réelle au joueur, sans surcharger l’interface mobile ?

Boucle cible :

**Lumière → exploration → risque → combat / événement → Folie / Espoir → butin → continuer ou extraire → conséquence au Sanctuaire.**

La priorité est la qualité de cette boucle avant l’ajout de nouvelles couches de contenu.

---

## 2. Grille d’observation commune

Pour chaque partie jouée, vidéo étudiée ou système documenté, relever :

- la première décision qui oblige réellement à réfléchir ;
- les moments où la tension monte avant qu’un combat commence ;
- les choix dont une option paraît systématiquement meilleure que les autres ;
- la cause précise des morts ou échecs ;
- les éléments qui créent de l’attachement à un personnage ou à une run ;
- les séquences qui deviennent répétitives ;
- le délai entre deux récompenses significatives ;
- la fréquence des décisions « continuer / se mettre en sécurité » ;
- la quantité de ressources visibles que le joueur accepte de mettre en danger ;
- le nombre de taps nécessaires pour comprendre puis exécuter une décision sur mobile ;
- les informations nécessaires au choix et celles qui arrivent trop tard.

Une observation n’est conservée que si elle débouche sur au moins une hypothèse testable pour LITD.

---

## 3. Darkest Dungeon — constats utiles

Sources de référence : wiki officiel communautaire Darkest Dungeon (Light Meter, Stress, Retreating, Expeditions).

### 3.1 La lumière n’est pas seulement une jauge

Dans Darkest Dungeon, une lumière élevée rend l’expédition plus prévisible et plus sûre ; une lumière basse augmente plusieurs dangers mais améliore aussi le potentiel de butin. Le joueur peut donc accepter volontairement plus de danger pour davantage de récompense.

**Constat de design :** une ressource devient intéressante lorsqu’elle modifie plusieurs systèmes en même temps et qu’aucune valeur n’est toujours optimale.

**Hypothèse LITD :** la Lumière doit être un multiplicateur transversal de sécurité, information, psychologie et récompense, pas uniquement une condition narrative ou visuelle.

### 3.2 Le stress relie les combats entre eux

Le stress persiste au-delà d’un affrontement et peut être aggravé par l’exploration, la faible lumière, certains événements et la perte d’un compagnon.

**Constat de design :** un combat gagne en poids lorsqu’il détériore une ressource qui influence les combats suivants.

**Hypothèse LITD :** Folie et Espoir doivent conserver la mémoire de la run. Un combat « gagné » peut quand même constituer une défaite stratégique si le groupe en ressort psychologiquement détruit.

### 3.3 La retraite est une décision de jeu

Darkest Dungeon autorise largement la retraite, mais elle a un coût. Elle transforme la survie en décision plutôt qu’en simple état d’échec.

**Constat de design :** l’abandon est intéressant lorsqu’il protège quelque chose de précieux mais fait renoncer à une autre valeur.

**Hypothèse LITD :** extraire doit sauver héros, objets sécurisables et informations, tout en faisant perdre une partie des opportunités non résolues de la run.

### 3.4 Les compétences sont contraintes par le contexte

La position dans la formation détermine quelles compétences peuvent être employées et quelles cibles peuvent être touchées.

**Constat de design :** la profondeur peut venir de contraintes sur peu d’actions visibles plutôt que d’un grand nombre de boutons simultanés.

**Hypothèse LITD :** conserver les arbres de progression riches, mais limiter la barre active d’expédition. La préparation du build est profonde ; l’exécution tactile reste lisible.

---

## 4. Shattered Pixel Dungeon — constats utiles

Sources de référence : documentation communautaire et dépôt open source de Shattered Pixel Dungeon.

### 4.1 La santé et la faim forment un budget commun

La nourriture n’est pas faite pour maintenir en permanence une jauge au maximum : le joueur arbitre entre satiété, régénération et conservation des ressources.

**Constat de design :** une ressource est plus intéressante quand le bon moment pour la consommer importe autant que sa quantité.

**Hypothèse LITD :** les moyens de restaurer Lumière, Espoir ou santé doivent posséder un coût d’opportunité. Les utiliser « dès que possible » ne doit pas être la stratégie optimale.

### 4.2 L’identification rend la connaissance précieuse

Certains objets sont trouvés sans que toutes leurs propriétés soient connues. Leur utilisation peut produire une récompense ou un risque.

**Constat de design :** l’information elle-même peut être une ressource de progression.

**Hypothèse LITD :** certaines reliques de l’ancienne civilisation peuvent être partiellement comprises. Le joueur choisit entre rapporter la relique pour l’étudier, la tester immédiatement ou la laisser.

### 4.3 La run transforme les petites dépenses en décisions futures

Les ressources consommées tôt manquent plus tard. La tension ne provient donc pas uniquement des ennemis mais de l’accumulation de petits choix.

**Constat de design :** l’attrition crée de la tension lorsque les pertes sont lisibles et que le joueur peut expliquer après coup pourquoi il s’est retrouvé en difficulté.

**Hypothèse LITD :** les coûts de déplacement, de Lumière, de soins et de récupération psychologique doivent être prévisibles suffisamment tôt pour éviter la sensation d’injustice.

---

## 5. Décisions LITD proposées

### 5.1 La Lumière devient la ressource de pression principale

La Lumière agit sur quatre axes :

1. **Information** — visibilité des menaces, indices, routes et intentions ennemies.
2. **Sécurité** — probabilité ou intensité des événements dangereux.
3. **Psychologie** — vitesse d’augmentation de Peur/Folie et capacité à entretenir l’Espoir.
4. **Récompense** — qualité ou rareté de certaines trouvailles lorsque le joueur accepte l’obscurité.

Le jeu ne doit pas enseigner « garde toujours la Lumière au maximum ». Il doit enseigner « choisis ce que tu es prêt à risquer ».

### 5.2 Paliers de pression à prototyper

Ces paliers sont des valeurs de prototype, pas de l’équilibrage final :

- **76–100 — Lueur stable** : meilleure information, faible pression, récompenses normales.
- **51–75 — Veille** : état neutre, premiers compromis.
- **26–50 — Cendre** : hausse mesurée de Folie / Peur, meilleures opportunités de butin et d’événements rares.
- **1–25 — Pénombre** : menaces renforcées, information incomplète, butin nettement plus tentant.
- **0 — Nuit de Cendre** : état exceptionnel ; événements rares et très dangereux, jamais requis pour terminer l’histoire principale.

Aucun bonus ne doit rendre l’obscurité obligatoire pour jouer « correctement ».

### 5.3 Continuer ou extraire

Après chaque jalon significatif de run, le joueur doit pouvoir comprendre trois informations :

- ce qu’il a déjà sécurisé ;
- ce qu’il perd ou met en danger s’il continue ;
- ce qu’il pourrait encore gagner.

Dans les donjons rejouables, proposer régulièrement une décision claire :

**Continuer**
- conserve le multiplicateur de risque actuel ;
- ouvre les opportunités rares ;
- expose davantage les héros et le butin non sécurisé.

**Extraire**
- ramène les survivants ;
- sécurise les récompenses prévues comme extractibles ;
- conserve les informations et conséquences déjà acquises ;
- abandonne les opportunités restantes ;
- peut appliquer un coût narratif ou économique selon le contexte, mais ne doit pas être présenté comme un échec automatique.

Pour les séquences narratives obligatoires, les points d’extraction peuvent être scénarisés ou limités sans supprimer la logique de risque.

### 5.4 Folie et Espoir gardent la mémoire de la run

Événements à relier explicitement aux jauges :

- voir un compagnon tomber ;
- retrouver un cadavre persistant ;
- découvrir une archive porteuse d’espoir ou de désespoir ;
- sauver un survivant ;
- renoncer à un survivant ;
- combattre longtemps dans l’obscurité ;
- réussir une action extrêmement risquée ;
- extraire avec un héros proche de la rupture ;
- stabiliser ou recruter une créature plutôt que la tuer.

Le système doit permettre qu’un événement grave augmente la Folie de certains personnages tout en renforçant l’Espoir ou la détermination d’autres profils. Les réponses psychologiques uniformes sont à éviter.

### 5.5 Le butin doit devenir « émotionnellement possédé » avant l’extraction

Un objet intéressant trouvé au milieu d’une run doit être visible et mémorable immédiatement. Le joueur doit savoir qu’il le met en danger en poursuivant l’expédition.

But recherché : créer la phrase mentale « j’ai trouvé quelque chose que je ne veux pas perdre » avant la proposition d’extraction.

---

## 6. Budget d’interaction mobile

Objectif de prototype :

- une décision d’exploration courante doit être compréhensible sans ouvrir un menu secondaire ;
- une action de combat fréquente doit rester exécutable en quelques taps ;
- la confirmation supplémentaire est réservée aux décisions irréversibles ou coûteuses ;
- les arbres riches restent dans la préparation et la progression, pas intégralement à l’écran pendant le tour ;
- viser une barre active d’environ **5 à 6 capacités** par personnage pour les premiers tests, sans remettre en cause les 45 compétences de progression ;
- l’appui long ou une fiche contextuelle fournit le détail sans polluer la vue principale.

La valeur exacte du nombre de capacités actives doit être validée par playtest mobile.

---

## 7. Métriques de playtest à ajouter

Pour chaque run :

- `meaningful_decisions_count` — décisions pour lesquelles le joueur hésite réellement entre au moins deux options ;
- `trivial_choice_count` — décisions où une option domine immédiatement ;
- `continue_extract_offers` — nombre de fois où le choix poursuivre / extraire est présenté ;
- `continue_extract_decision_time_s` — temps de décision ;
- `light_at_major_decision` — lumière au moment des choix importants ;
- `light_at_extraction` ;
- `folie_delta_run` ;
- `espoir_delta_run` ;
- `unsecured_loot_value_peak` — valeur maximale consciemment mise en danger ;
- `loot_secured_value` ;
- `run_end_reason` — extraction volontaire, objectif rempli, mort, fuite forcée, autre ;
- `death_or_failure_cause` — cause comprise par le testeur ;
- `taps_per_meaningful_action` ;
- `first_confusion_timestamp` ;
- `most_tense_moment` — annotation qualitative ;
- `what_made_you_continue` — réponse qualitative ;
- `what_made_you_extract` — réponse qualitative.

Les métriques servent à éclairer les décisions de design, pas à remplacer l’observation humaine.

---

## 8. Critères de réussite de la boucle

La boucle est considérée prometteuse lorsque, sur plusieurs sessions :

1. le joueur peut expliquer avec ses mots pourquoi une faible Lumière est à la fois tentante et dangereuse ;
2. la majorité des offres « continuer / extraire » ne produisent pas une réponse instantanément évidente ;
3. le joueur peut identifier la chaîne de décisions qui a mené à une défaite ;
4. une victoire de combat peut être perçue comme coûteuse sans sembler arbitraire ;
5. le joueur ressent de l’attachement à au moins un héros, une créature, un objet ou une information rapportée ;
6. l’interface mobile ne devient pas le principal facteur d’hésitation ;
7. le joueur désire volontairement faire « encore une salle » au moins une fois ;
8. l’extraction anticipée est parfois choisie et ressentie comme une décision intelligente plutôt qu’une punition.

---

## 9. Ordre de prototype recommandé

1. rendre la Lumière visible dans une run de test ;
2. connecter Lumière → danger / information / psychologie / récompense ;
3. ajouter un premier point continuer / extraire ;
4. rendre le butin non sécurisé explicitement visible ;
5. connecter Folie / Espoir aux événements d’exploration ;
6. instrumenter les métriques ci-dessus ;
7. tester sur écran mobile ;
8. seulement ensuite ajuster la quantité de contenu, les taux de loot et les valeurs numériques.

---

## 10. Règle de benchmark pour la suite

Pour chaque jeu étudié :

**Observation → pourquoi cela crée une décision → risque de copie / incompatibilité → adaptation LITD → test → décision.**

Une mécanique n’est jamais ajoutée parce qu’elle existe dans un jeu de référence. Elle n’entre dans LITD que si elle renforce l’identité propre du jeu et la boucle de tension définie ici.
