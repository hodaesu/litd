# LITD 1 — Conséquences différées, relations et filiation des rumeurs V2

> Statut : extension d'implémentation du canon déjà posé par les ramifications, croisements systémiques et Rémanences.  
> Cette passe n'ajoute ni nouvelle jauge, ni nouveau jugement moral, ni nouvelle vérité cosmologique.

## 1. Pourquoi une V2

La première couche différée faisait déjà trois choses essentielles : un **écho** au chapitre suivant, une **Rémanence** plus tardive et une structure explicite **SOURCE → TRANSMISSION → RÉMANENCE**.

La V2 ajoute ce qui manquait pour que plusieurs conséquences vécues finissent réellement par peser ensemble :

- les échos relationnels qualitatifs peuvent désormais alimenter les **relations existantes** entre personnages ;
- plusieurs conséquences distinctes s'accumulent dans l'historique de la relation au lieu d'écraser la précédente ;
- une rumeur transformée garde une **filiation lisible** depuis sa source jusqu'à sa forme de Rémanence ;
- la déformation elle-même reçoit un type descriptif, sans devenir une mesure de vérité.

## 2. Relations : accumulation sans jauge supplémentaire

L'objet narratif d'un écho reste non numérique : il conserve un tag comme `responsabilite_partagee`, `desaccord_persistant`, `deuil_sans_verdict` ou `memoire_commune`.

Le runtime traduit ensuite ce sens dans le **RelationshipRuntime déjà existant**. Les valeurs internes `trust`, `admiration`, `mistrust` et `resentment` restent les mécanismes techniques existants ; aucune nouvelle statistique n'est affichée au joueur.

### Responsabilité partagée

Deux personnages présents peuvent gagner à la fois confiance et admiration parce qu'ils ont dû porter ensemble une conséquence imparfaite. Ce n'est jamais une approbation morale du choix initial.

### Désaccord persistant

La relation peut gagner simultanément un peu de confiance et de méfiance. Deux personnes peuvent mieux se connaître tout en découvrant un désaccord plus profond. Le système évite ainsi le modèle binaire « ami / ennemi ».

### Deuil sans verdict

Si les deux personnages sont vivants, un deuil peut simultanément rapprocher et tendre leur relation. Si l'un est mort, **seul le vivant** peut voir sa relation mémorielle évoluer ; le mort ne reçoit jamais de nouveau sentiment réciproque.

Si un lien antérieur était très fort, la mémoire peut renforcer confiance ou admiration. Si la relation était déjà très tendue, le ressentiment peut s'approfondir. Dans une relation encore indéterminée, le système peut se contenter d'ajouter l'événement à l'historique sans imposer une émotion.

### Mémoire commune

Certains événements n'imposent aucune variation numérique. Ils ajoutent seulement une référence partagée à l'historique de la relation.

## 3. Présence réelle des Sept

Les profils narratifs peuvent prévoir des échanges pour les Sept, mais le runtime ne crée jamais un personnage absent pour satisfaire une scène ou un test.

- héros absent de la compagnie : effet relationnel en attente ;
- héros présent plus tard : l'effet peut être appliqué une seule fois ;
- héros mort : aucune réciprocité nouvelle ne lui est attribuée ;
- deux héros morts : aucune évolution relationnelle nouvelle n'est fabriquée.

Cette règle protège à la fois la création de personnages, la mortalité réelle et la cohérence de la compagnie.

## 4. Idempotence et accumulation

Chaque effet différé utilise un identifiant stable `systemic_afterlife:<source>` dans l'historique relationnel.

Le même écho ne peut donc jamais augmenter plusieurs fois une relation parce qu'un écran est rouvert, qu'une sauvegarde est rechargée ou qu'un signal de campagne est réémis.

En revanche, **deux sources différentes** peuvent produire deux entrées différentes. C'est cette accumulation qui permet aux seuils relationnels déjà existants de devenir significatifs plus tard : confiance solide, tension élevée, interposition en combat, conversation au Sanctuaire, peur liée à la perte, etc.

## 5. Filiation d'une rumeur

Une rumeur différée n'est plus seulement un texte ajouté à la Table des rumeurs. La source systémique conserve désormais une chaîne en trois étapes.

### SOURCE

La source garde :

- l'identifiant du croisement ou de la cascade ;
- le chapitre d'origine ;
- le fait documenté ;
- les rumeurs initiales et leur fiabilité.

### ÉCHO

L'écho garde :

- son lien vers la source ;
- le chapitre où la nouvelle version apparaît ;
- le texte transformé ;
- sa fiabilité ;
- un `distortion_kind` décrivant **comment** le récit s'est modifié.

### RÉMANENCE

La Rémanence garde :

- son lien vers l'écho ;
- la même origine ;
- la forme de déformation ;
- la trace matérielle ou institutionnelle ;
- la possibilité d'une interprétation future.

Le fait d'origine reste séparé et n'est jamais remplacé par la version qui circule le mieux.

## 6. Familles de déformation

Les types servent à expliquer le mécanisme historique, pas à noter la vérité sur une échelle.

- nourriture / logistique : **simplification en plan unique** ;
- mort / identité / Mémorial : **effacement des marqueurs de certitude** ;
- migration / refuge : **mouvement reconstruit en plan** ;
- preuve / témoignage : **perte du niveau de confiance** ;
- consentement non humain : **précédent transformé en essence** ;
- site draconique : **sacralisation et Pacte inventé** ;
- deuil : **personne transformée en symbole**.

Les cascades ont également leur propre forme : cause unique inventée, méthode devenue doctrine, protocole devenu règle d'espèce, pratique récente devenue tradition ancienne.

Le terme **Pacte inventé** reste explicitement une déformation possible. Il ne confirme ni Vharren, ni Pacte ancestral, ni ascendance draconique, ni langue draconique, ni relation du site au Voile.

## 7. Chronologie inter-jeux

Chaque Rémanence issue d'une décision de LITD 1 enregistre :

- `future_target = post_litd1` ;
- `backward_causation = false`.

Une pratique, une fausse tradition ou une archive déformée née dans LITD 1 peut donc servir de source à un récit **postérieur**. Elle ne peut jamais expliquer rétroactivement LITD 2 ou Les Veilleurs.

## 8. Mise en scène

L'ordre de priorité reste :

1. conséquence immédiate au Sanctuaire ;
2. écho différé sur un retour ultérieur ;
3. Rémanence sur un autre retour.

Une seule unité narrative différée est présentée par entrée lorsque aucune scène immédiate n'a priorité. Les relations et la filiation historique progressent en arrière-plan sans créer un écran supplémentaire.

## 9. Validation des neuf piliers

- **P1 — Création de personnages :** aucun héros absent n'est fabriqué ; la composition réelle de la compagnie reste souveraine.
- **P2 — Gore et conséquences corporelles :** une mort ou une séquelle reste matériellement vraie et peut transformer les relations et les rites sans être réduite à un score.
- **P3 — Philosophie / psychologie :** confiance et désaccord peuvent coexister ; la mémoire n'est ni purement objective ni arbitraire.
- **P4 — Profondeur humaine :** les relations évoluent à partir d'événements vécus et non de cadeaux d'affinité abstraits.
- **P5 — Narration forte :** une décision peut revenir plusieurs chapitres plus tard puis s'accumuler avec une autre.
- **P6 — Interconnexion :** les traces de LITD 1 ne causent que l'après-LITD 1.
- **P7 — Rémanence :** la chaîne source, transmission, transformation est désormais directement inspectable.
- **P8 — Dialogues / mise en scène :** les échos restent courts, conditionnels et subordonnés aux scènes immédiates.
- **P9 — Simple à comprendre, profond à maîtriser :** aucune jauge nouvelle ; la profondeur vient de l'interaction entre relations, mémoire, rumeurs et conséquences déjà existantes.
