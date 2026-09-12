# Observations de runs enregistrés — conséquences pour LITD

## Statut

Complément au benchmark roguelike/dungeon crawler. Cette note distingue les règles documentées des comportements observables dans des runs enregistrés et transforme ces constats en priorités de prototype.

Les références principales de cette passe sont :

- **Darkest Dungeon** — runs Stygian / torchless enregistrés, recoupés avec les règles de Lumière, Stress, Surprise et Retraite ;
- **Shattered Pixel Dungeon** — runs avancés / challenges, recoupés avec la gestion de faim, PV, identification, ressources et exploration ;
- compléments de conception : **Battle Brothers** (blessures / moral), **Iratus** (états mentaux positifs ou négatifs) et **Into the Breach** (télégraphie des intentions ennemies).

L’objectif n’est pas de copier ces jeux, mais d’identifier les moments où un joueur accepte consciemment un risque.

---

## 1. Constat majeur — le danger intéressant est volontaire

Dans les runs torchless de Darkest Dungeon, la faible Lumière n’est pas seulement un handicap subi : un joueur expérimenté accepte volontairement davantage d’incertitude, de Stress et de danger parce que le potentiel de récompense augmente.

### Conséquence LITD

La Nuit ne doit jamais être seulement une version punitive de la Lumière.

À chaque baisse importante de Lumière, le joueur doit percevoir simultanément :

- ce qui devient plus dangereux ;
- ce qui devient moins certain ;
- ce qu’il peut gagner de plus rare ;
- ce qu’il risque désormais de perdre.

### Test

Si tous les testeurs restaurent la Lumière dès qu’ils le peuvent, l’avantage de l’obscurité est trop faible ou mal communiqué.

Si tous les testeurs recherchent systématiquement l’obscurité, l’avantage est trop fort.

Le bon réglage produit des stratégies différentes selon le butin possédé, l’état de l’équipe et la personnalité du joueur.

---

## 2. Constat — le timing d’une ressource compte plus que son remplissage

Dans Shattered Pixel Dungeon, conserver une ration, une potion, un parchemin ou accepter temporairement de ne pas être à pleine santé peut être meilleur que consommer immédiatement la ressource. Une dépense confortable maintenant peut devenir une erreur plusieurs étages plus tard.

### Conséquence LITD

Les ressources de survie doivent créer des arbitrages temporels.

Premiers candidats :

- recharge de Lumière ;
- soin ;
- réduction de Folie ;
- restauration d’Espoir ;
- identification d’une relique ;
- sécurisation exceptionnelle d’un objet avant extraction.

Le bouton « utiliser dès que la jauge baisse » ne doit pas être une stratégie optimale universelle.

### Test

À la fin d’une run, demander au joueur quelle ressource il regrette d’avoir dépensée trop tôt ou trop tard. Si la réponse est systématiquement « aucune », l’attrition manque probablement de décisions.

---

## 3. Constat — le butin crée la peur de continuer

Une décision d’extraction devient intéressante seulement lorsque le joueur considère déjà certaines trouvailles comme siennes.

### Conséquence LITD

Le butin non sécurisé doit être visible immédiatement dans l’interface d’expédition.

Le joueur doit pouvoir penser :

> « J’ai trouvé ça. Si je continue et que tout s’effondre, je peux le perdre. »

À un point Continuer / Extraire, afficher au minimum :

- les héros / créatures actuellement exposés ;
- les objets non sécurisés ;
- l’Essence non sécurisée ;
- les archives / informations rares ;
- l’état de Lumière ;
- l’état Folie / Espoir ;
- un indice compréhensible sur l’opportunité suivante, sans révéler exactement sa récompense.

---

## 4. Constat — l’information est une ressource

Darkest Dungeon utilise la Lumière et le scouting pour modifier la prévisibilité de l’expédition. Shattered Pixel Dungeon rend certains objets, dangers et possibilités partiellement inconnus jusqu’à ce que le joueur investisse de l’information ou accepte de tester.

### Conséquence LITD

Faire de la Lumière un système d’information autant qu’un système de difficulté.

Prototype recommandé :

- **Lueur stable** : intention ennemie précise, indices de pièges clairs, meilleure lecture de la salle suivante ;
- **Veille** : informations normales ;
- **Cendre** : intention ennemie indiquée par catégorie plutôt que par valeur exacte ;
- **Pénombre** : indices incomplets, certaines intentions deviennent ambiguës ;
- **Nuit de Cendre** : phénomènes exceptionnels et information minimale, mais jamais du pur hasard incompréhensible.

L’incertitude doit rester lisible : le joueur doit savoir qu’il lui manque une information, et pourquoi.

---

## 5. Constat — enlever le contrôle crée du drame mais peut casser la tactique

Darkest Dungeon produit des histoires fortes avec les afflictions, mais le refus d’action, les déplacements forcés ou l’auto-sabotage peuvent aussi transformer une décision tactique en résultat subi.

Iratus montre qu’un seuil mental peut également produire des réactions positives.

### Conséquence LITD

Folie et Espoir doivent déclencher des **crises lisibles et propres aux personnages**, sans reposer principalement sur la perte aléatoire d’un tour.

Préférer :

- changement temporaire du coût d’une compétence ;
- impulsion vers une cible ou une position, mais avec possibilité de résistance / choix ;
- capacité spéciale risquée disponible uniquement en crise ;
- réaction différente selon le profil du héros ;
- poussée rare d’Espoir après une situation catastrophique ;
- choix narratif ou tactique bref lors d’un seuil majeur.

Éviter que « Folie » signifie principalement « le jeu joue à ma place ».

---

## 6. Constat — peu d’actions visibles peuvent produire beaucoup de profondeur

Darkest Dungeon contraint fortement l’usage des compétences par la position et l’équipement de capacités. Les runs deviennent profonds par interaction entre formation, cible, timing et état du groupe plutôt que par présence de dizaines de boutons simultanés.

### Conséquence LITD

Ne pas réduire les **3 arbres × 15 compétences**.

En revanche, prototyper **5 à 6 compétences actives équipées par personnage pour une expédition**.

Les 45 compétences servent à :

- construire une spécialisation ;
- créer des builds ;
- préparer une expédition ;
- différencier les héros / créatures ;
- faire évoluer le style de jeu.

La barre active sert à rendre le combat lisible sur mobile.

### Test mobile

Une action de combat fréquente devrait généralement demander :

1. un tap sur la capacité ;
2. un tap sur la cible si nécessaire.

Les menus secondaires ne doivent pas être nécessaires pour une action de routine.

---

## 7. Constat — la télégraphie augmente la profondeur tactique

Into the Breach démontre qu’un danger connu peut être plus tactique qu’un danger caché : le joueur réfléchit à la manière de résoudre un problème plutôt qu’à deviner si le jeu va le punir.

### Conséquence LITD

Connecter directement la télégraphie ennemie à la Lumière.

Exemple de prototype :

- lumière haute : attaque, cible et effet secondaire visibles ;
- lumière moyenne : type d’action et cible visibles, valeur exacte masquée ;
- lumière faible : intention générale visible, cible parfois incertaine ;
- Nuit de Cendre : certaines intentions déformées ou retardées, signalées comme telles.

Cela donne à la Lumière une valeur tactique immédiate sans ajouter une nouvelle jauge.

---

## 8. Constat — survivre à une catastrophe peut créer plus d’attachement que gagner proprement

Battle Brothers utilise les blessures et séquelles pour transformer les survivants en histoires persistantes.

### Conséquence LITD

La mort permanente reste la règle. Un héros mort n’est pas ressuscité par ce système.

Proposition distincte : lorsqu’un héros **survit** à un état critique ou à une extraction catastrophique, il peut rarement recevoir une **Cicatrice des Cendres** permanente.

Une Cicatrice peut :

- apporter un coût ;
- modifier une interaction de Folie / Espoir ;
- débloquer un texte ou une réaction ;
- très rarement donner un avantage contextuel.

Les cadavres des héros réellement morts restent persistants selon la règle déjà prévue de LITD.

Cette proposition reste à valider avant implémentation.

---

# Priorités d’implémentation

## P0 — indispensable pour tester la boucle

### A. Une seule source d’état d’expédition

Créer ou centraliser un `ExpeditionState` unique contenant au minimum :

- `light` : 0–100 ;
- `depth` / progression courante ;
- `unsecured_loot_value` ;
- `unsecured_essence` ;
- références aux objets / archives non sécurisés ;
- état Folie / Espoir du groupe ;
- disponibilité d’extraction ;
- niveau de pression / palier de Lumière courant.

Ne pas créer de gestionnaire parallèle si un système existant peut devenir cette source de vérité.

### B. Relier la Lumière à quatre axes

À chaque palier :

1. information ;
2. pression de combat / exploration ;
3. Folie / Espoir ;
4. potentiel de récompense.

Aucun axe ne doit fonctionner isolément.

### C. Ajouter des checkpoints Continuer / Extraire

Pas après chaque salle : seulement aux moments où le joueur possède quelque chose à perdre ou aperçoit quelque chose à gagner.

### D. Rendre le butin non sécurisé visible

L’interface doit faire naître l’attachement au butin **avant** la décision d’extraction.

### E. Instrumenter le test

Journaliser au minimum :

- Lumière au choix ;
- butin exposé ;
- décision Continuer / Extraire ;
- temps de décision ;
- cause de fin de run ;
- cause de mort comprise ;
- variation Folie / Espoir ;
- taps nécessaires pour les actions courantes.

---

## P1 — dès que P0 est jouable

1. intentions ennemies dont la précision dépend de la Lumière ;
2. reliques anciennes partiellement identifiées ;
3. 5–6 compétences actives équipables pour l’expédition ;
4. événements de seuil Folie / Espoir centrés sur le personnage et le choix ;
5. salles / opportunités de tentation rares favorisées par la faible Lumière.

---

## P2 — après validation du plaisir de la boucle

1. Cicatrices des Cendres pour les survivants de situations critiques ;
2. phénomènes propres à la Nuit de Cendre ;
3. familles ennemies capables d’attaquer la Lumière ou de manipuler l’information ;
4. récompenses / textes uniques associés à des prises de risque extrêmes ;
5. équilibrage fin des multiplicateurs de récompense et de danger.

---

# Critères d’acceptation du premier prototype

Sur une run de test d’environ **8 à 12 salles** :

- au moins **3 décisions non triviales** de gestion de ressource / poursuite ;
- au moins une situation où un testeur **choisit volontairement** de continuer à `light <= 25` pour une récompense ou une information convoitée ;
- au moins une situation où extraire tôt est perçu comme une bonne décision ;
- le joueur peut expliquer après une mort la chaîne de décisions qui l’a conduit à cette mort ;
- le joueur peut nommer ce qu’il avait peur de perdre ;
- la faible Lumière n’est ni toujours optimale ni toujours évitée ;
- les actions de combat courantes ne demandent pas de naviguer dans des menus imbriqués ;
- l’hésitation vient du choix tactique, pas de l’incompréhension de l’interface.

## Signaux d’échec

- tout le monde remplit immédiatement la Lumière : récompense obscure trop faible ou mal communiquée ;
- tout le monde cherche en permanence la Nuit : récompense trop forte / coût trop faible ;
- le joueur ne sait pas pourquoi il est mort : information insuffisante ou causalité trop opaque ;
- le joueur n’a rien qu’il craint de perdre : butin / survivants pas assez émotionnellement possédés ;
- les testeurs hésitent surtout parce qu’ils ne trouvent pas l’action dans l’UI : surcharge tactile ;
- Folie est décrite comme « le jeu m’empêche de jouer » : trop de perte de contrôle.

---

# Décision recommandée

Avant d’ajouter de nouvelles familles de monstres, compétences, armes ou salles, construire un **slice de 8–12 salles** qui ne teste presque que cette chaîne :

**voir une opportunité → accepter de perdre de la Lumière → obtenir quelque chose de précieux → subir une conséquence → décider de continuer ou d’extraire.**

Si cette boucle fonctionne avec peu de contenu, le contenu déjà prévu pour LITD l’amplifiera. Si elle ne fonctionne pas, davantage de contenu masquera seulement le problème.