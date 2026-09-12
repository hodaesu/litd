# LITD : Les Veilleurs — protocole de playtest continu

## But

Le playtest sert à vérifier ce que le joueur **comprend, fait et ressent**, et pas à confirmer ce que l'équipe espère déjà.

Chaque session doit commencer par une question précise et produire une décision exploitable.

---

## 1. Types de tests

### Fonctionnel

Le système fonctionne-t-il sans bug et respecte-t-il ses règles ?

### Utilisabilité

Le joueur comprend-il quoi faire, où regarder et comment agir ?

### Expérience

La scène produit-elle la tension, la peur, l'attachement, la curiosité ou la satisfaction recherchée ?

### Équilibrage

Les choix sont-ils réellement compétitifs ? Existe-t-il une stratégie dominante ?

### Accessibilité

Le jeu reste-t-il compréhensible et utilisable avec différents besoins moteurs, visuels, auditifs ou cognitifs ?

### Endurance mobile

Le jeu reste-t-il stable, lisible, confortable et performant après une session prolongée ?

---

## 2. Fiche de session

```text
Build / commit :
Appareil :
Profil testeur :
Expérience du genre :
Question principale :
Scénario :
Durée prévue :
Ce que le testeur sait avant de commencer :
Métriques/observations :
Résultat :
Décision :
Actions :
```

---

## 3. Règles d'observation

Pendant un test d'utilisabilité :

- ne pas guider sauf blocage total ;
- noter le premier point d'hésitation ;
- noter ce que le joueur tente avant de trouver la bonne action ;
- observer le regard et la main ;
- distinguer erreur du joueur et ambiguïté de l'interface ;
- noter les commentaires spontanés ;
- ne pas défendre le design pendant le test.

Après la session, poser des questions ouvertes avant les questions dirigées.

---

## 4. Questions post-session

- Quel était ton objectif à ce moment-là ?
- Qu'est-ce qui t'a semblé important ?
- Qu'est-ce que tu n'as pas compris ?
- Quelle décision t'a demandé le plus de réflexion ?
- À quel moment as-tu ressenti le plus de tension ?
- Qu'est-ce qui t'a semblé injuste ?
- Qu'est-ce qui t'a donné envie de continuer ?
- Quelle information aurais-tu voulu avoir plus tôt ?

Éviter : « Tu as aimé ? » comme seule mesure.

---

## 5. Gravité des problèmes

### P0 — Bloquant

Impossible de continuer, perte de sauvegarde, crash, soft-lock majeur.

### P1 — Critique

Le joueur peut continuer mais comprend mal une règle centrale ou rencontre une frustration majeure.

### P2 — Important

Friction répétée, lisibilité insuffisante, rythme ou feedback à corriger.

### P3 — Mineur

Polish, préférence ou problème local sans impact fort.

---

## 6. Tests prioritaires Les Veilleurs

### Combat

Observer :

- compréhension de l'ordre des tours ;
- lecture des rangs ;
- compréhension du ciblage anatomique ;
- anticipation des conséquences d'une blessure ;
- lecture de Peur/Folie ;
- perception des synergies ;
- différence entre tuer, neutraliser et capturer ;
- compréhension des ultimes ;
- durée perçue des animations.

### UI tactile

Observer :

- erreurs de tap ;
- éléments cachés par le doigt ;
- distance entre actions ;
- retour visuel d'un appui ;
- besoin d'utiliser deux mains ;
- confort sur petit écran ;
- lisibilité des jauges et états.

### Exploration

Observer :

- orientation ;
- découverte des interactions ;
- compréhension de ce qui est facultatif ;
- rythme combat/repos/enquête ;
- capacité à relier environnement et narration.

### Sanctuaire

Observer :

- compréhension des bâtiments ;
- conséquence des choix ;
- gestion du roster ;
- équipement ;
- progression ;
- charge cognitive.

---

## 7. Tests de première expérience

Le premier contact doit être testé séparément.

Mesurer :

- temps avant première action significative ;
- nombre d'écrans avant gameplay ;
- première incompréhension ;
- première décision tactique ;
- première conséquence ;
- capacité à expliquer la boucle avec ses propres mots après la session.

---

## 8. Tests de rétention qualitative

Sans transformer LITD en jeu piloté uniquement par des métriques, demander après une session :

- qu'aimerais-tu faire ensuite ?
- qu'est-ce que tu veux comprendre ?
- quel personnage/créature/système veux-tu revoir ?
- quelle conséquence t'intéresse ?

Le but est d'identifier les **promesses naturelles** que le jeu crée chez le joueur.

---

## 9. Test de stress mobile

Sur chaque profil d'appareil disponible :

- session longue ;
- combat avec maximum d'effets raisonnables ;
- transitions répétées ;
- ouverture/fermeture de menus ;
- background/foreground ;
- rotation si supportée ;
- faible batterie si possible ;
- reprise après verrouillage écran ;
- écouteurs / haut-parleur ;
- notifications système ;
- montée en température.

Tracer : FPS, frame time, mémoire, chauffe, crash et comportement de reprise.

---

## 10. Accessibilité

Inclure progressivement des tests portant sur :

- contraste ;
- taille du texte ;
- perception sans couleur ;
- compréhension sans son ;
- sous-titres ;
- haptique désactivée ;
- contrôles simplifiés ;
- vitesse de lecture ;
- fatigue visuelle ;
- effets clignotants ;
- réduction du gore tout en conservant les informations tactiques.

---

## 11. Décision après playtest

Chaque problème observé reçoit l'une de ces décisions :

- corriger maintenant ;
- mesurer davantage ;
- accepter ;
- différer ;
- supprimer la fonctionnalité ;
- revoir l'hypothèse.

Aucun playtest ne doit se terminer par une liste de remarques sans décision.

---

## 12. Cadence recommandée

- prototype : dès qu'une hypothèse devient jouable ;
- UI : après chaque changement de parcours important ;
- verticale : tests fréquents avec nouveaux joueurs ;
- alpha : tests de bout en bout ;
- beta : compatibilité, accessibilité, équilibre et endurance ;
- avant release : test complet sur appareils cibles et reprise de sauvegarde.

Le jeu doit être testé tôt, souvent et en contexte réel. Les tests automatiques protègent la cohérence ; les joueurs valident l'expérience.

---

## 13. Test de la boucle de tension d'expédition

Référence de benchmark : `docs/research/ROGUELIKE_DUNGEON_CRAWLER_BENCHMARK.md`.

Question centrale : **la boucle Lumière → exploration → risque → combat/événement → Folie/Espoir → butin → continuer/extraire crée-t-elle des décisions non triviales ?**

### À relever pendant la run

- première décision qui provoque une hésitation réelle ;
- nombre de choix où une option domine immédiatement ;
- niveau de Lumière lors des décisions importantes ;
- valeur ou importance du butin que le joueur pense mettre en danger ;
- moment où il commence à envisager l'extraction avant que l'interface ne la propose ;
- raison exacte de continuer ;
- raison exacte d'extraire ;
- cause perçue d'un échec ou d'une mort ;
- variation de Folie/Espoir entre deux jalons ;
- nombre de taps pour une action significative sur mobile ;
- moment de tension maximal et événement déclencheur.

### Métriques recommandées

```text
meaningful_decisions_count:
trivial_choice_count:
continue_extract_offers:
continue_extract_decision_time_s:
light_at_major_decisions:
light_at_extraction:
folie_delta_run:
espoir_delta_run:
unsecured_loot_value_peak:
loot_secured_value:
run_end_reason:
death_or_failure_cause:
taps_per_meaningful_action:
first_confusion_timestamp:
most_tense_moment:
what_made_you_continue:
what_made_you_extract:
```

### Questions post-session spécifiques

- À quel moment as-tu commencé à craindre de perdre ce que tu avais trouvé ?
- Pourquoi as-tu continué alors que tu pouvais te mettre en sécurité ?
- Pourquoi as-tu choisi d'extraire ?
- La faible Lumière t'a-t-elle semblé seulement punitive ou également tentante ?
- Peux-tu expliquer la chaîne de décisions qui a conduit à ton meilleur ou pire moment ?
- Quelle information aurait changé ta décision ?

### Signaux d'alerte

- le joueur veut toujours maximiser la Lumière ;
- le joueur veut toujours la réduire pour optimiser le butin ;
- poursuivre ou extraire est évident presque à chaque fois ;
- une mort semble provenir d'une règle invisible plutôt que d'une décision identifiable ;
- le joueur ne sait pas ce qu'il risque de perdre ;
- l'interface tactile crée davantage d'hésitation que la décision de jeu ;
- Folie/Espoir sont perçus comme des jauges décoratives sans influence sur le comportement de la run.

Le test est réussi lorsque le joueur peut expliquer le compromis qu'il a choisi, ressent la tentation de faire « encore une salle » et considère parfois l'extraction anticipée comme une décision intelligente plutôt qu'un échec.
