# LITD 2 — Bible d'animation du build Politique

## Intention

Politique ne doit jamais être animé comme une classe de soutien. Son fantasme de jeu est celui d'un **Juge / Législateur / Tyran capable d'imposer une règle au combat puis de punir ceux qui la subissent**.

La lecture visuelle doit fonctionner même sans HUD :

1. **Autorité** — le personnage prend le contrôle de l'espace.
2. **Condamnation** — il désigne clairement une cible et accumule une faute.
3. **Commandement / Loi** — il impose une contrainte.
4. **Sentence** — il transforme cette contrainte en dégâts.
5. **Tyrannie** — il force le système au-delà de ses limites.

Les gestes restent courts et compatibles avec un roguelite nerveux.

## Les six grammaires visuelles

### Autorité

Silhouette : verticale, stable, peu de mouvements inutiles.

Motifs :
- paume vers le bas = pression ;
- deux doigts levés = interruption / ordre bref ;
- main ramenée au sternum puis projetée = concentration d'Autorité ;
- pas mesuré = zone dominée ;
- arme tenue comme une ligne de commandement, jamais agitée.

L'Autorité doit sembler puissante **par économie de mouvement**.

### Condamnation

Silhouette : cible clairement suivie par la tête, la main ou la pointe de l'arme.

Motifs :
- index / pointe = désignation ;
- trait vertical = marque ;
- comptage des doigts = accumulation de charges ;
- cadre des deux mains = preuve / point faible ;
- fermeture du poing = seuil de Condamnation atteint.

La Condamnation doit toujours indiquer **qui** est jugé.

### Commandements

Silhouette : gestes vectoriels très lisibles.

Correspondances :
- paume vers le bas = `À genoux` ;
- paume vers l'avant = `Recule` ;
- doigts crochetés vers le torse = `Approche` ;
- bras descendant = `Tombe` ;
- paume verticale = `Cesse` ;
- doigt aux lèvres puis coupe horizontale = `Silence`.

Le joueur doit comprendre la direction de l'effet avant le VFX.

### Lois

Silhouette : gestes plus géométriques et légèrement plus engagés.

Motifs :
- cercle = frontière d'une Loi ;
- deux marques reliées = rétribution ;
- fermeture des deux mains = suppression / silence ;
- deux sceaux latéraux = deux Lois actives ;
- frappe vers le sol = loi de poids / territoire ;
- chiffre ou comptage = loi liée au nombre de cibles.

Une Loi n'est pas un sort explosif : son animation annonce **une règle qui persiste**.

### Sentences

Silhouette : préparation minimale, conclusion brutale.

Motifs :
- désignation puis coupe verticale = `Châtiment` ;
- saisie du vide ramenée au torse = `Confiscation` ;
- rejet latéral = `Exil` ;
- pointage après parade parfaite = `Verdict` ;
- ligne d'arme ou de main = `Exécution`.

Une Sentence doit être plus courte qu'une Loi : c'est la conséquence, pas la déclaration.

### Tyrannie

Tyrannie reprend les mêmes signes mais les déforme :

- plus de fermeture du poing ;
- gestes plus directs et asymétriques ;
- déplacement vers l'ennemi plutôt que recul ;
- moins de préparation ;
- impacts plus violents ;
- maintien du regard sur la cible ;
- autorité vocale plus dure.

Elle ne doit pas devenir une magie différente : **c'est Politique lorsqu'il n'accepte plus la limite**.

## Adaptation aux armes

Politique ne remplace jamais le profil de l'arme.

### Sabre / épée
- pointe pour désigner ;
- garde horizontale comme limite d'une Loi ;
- coupe verticale pour Sentence ;
- pommeau / garde pour gestes de magistrat courts.

### Lance / naginata
- pointe très lisible pour Condamnation ;
- hampe abaissée pour `À genoux` ;
- cercle de pointe pour Loi de zone ;
- planté au sol pour Décret.

### Masse
- masse tenue comme un marteau de jugement ;
- frappe au sol pour Loi ;
- impact lourd pour Peine aggravée ;
- excellente identité pour Sentence/Tyrannie.

### Dagues / doubles lames
- gestes plus courts ;
- désignation par lame secondaire ;
- Lois dessinées en croisements ;
- Sentences très rapides après esquive.

### Mains nues
- index, paumes, poings et position du buste portent tout le langage ;
- aucun gestuel de mage flottant ;
- la force semble provenir de la volonté et de la règle, pas d'une incantation classique.

## Intégration aux cinq inputs

### Light
Peut appliquer/renforcer Condamnation ou Autorité sans interrompre le combo.

### Heavy
Peut devenir une Peine, une rupture d'Équilibre ou l'application physique d'une Loi.

### Parry
Est une source majeure de `Verdict`, `Refus` et contre-condamnation.

### Dodge
Reste une esquive réelle ; Politique lui ajoute une lecture de domination ou de désignation sans rallonger sa durée.

### SkillAttack
Déclenche Commandements, Lois, Sentences, génération d'Autorité et Tyrannie.

Les finishers restent contextuels et ne deviennent pas une sixième commande.

## Lisibilité VFX / son

- **Autorité** : onde basse, air comprimé, accent sonore bref.
- **Condamnation** : sceau net sur cible, son sec de marque.
- **Commandement** : effet directionnel immédiatement aligné au geste.
- **Loi** : frontière persistante et sobre, son de proclamation plus grave.
- **Sentence** : impact unique, contraste sonore fort.
- **Tyrannie** : même vocabulaire mais distordu, plus sombre et plus agressif.

La voix peut renforcer un Commandement, mais le gameplay doit rester lisible sans elle.

## Caméra

Pas de cut cinématique pour les Commandements ordinaires.

Autorisé :
- micro-impulsion caméra sur Sentence importante ;
- très léger resserrement sur `Exécution` contextuelle ;
- accent plus fort sur boss burst ;
- jamais de caméra qui retire le contrôle pendant une Loi standard.

## Règle de viabilité solo

Pour valider une animation Politique, elle doit servir au moins une des fonctions suivantes :

- dégâts directs ;
- dégâts de zone ;
- Condamnation ;
- génération / dépense d'Autorité ;
- rupture d'Équilibre ;
- parade / contre ;
- esquive / repositionnement ;
- contrôle offensif ;
- Sentence / burst boss ;
- finisher.

Une animation purement décorative ou destinée à renforcer un compagnon n'entre pas dans le pool de combat.

## Références de direction

La bibliothèque utilise uniquement des **principes de mise en scène** :
- `Dune` : présence, autorité vocale et économie de mouvement ;
- `Control` : forces directionnelles lisibles ;
- cinéma de samouraïs : retenue, regard, décision ;
- `Sekiro` et `Sifu` : réponses défensives nettes et courtes ;
- cinéma judiciaire / cérémoniel : désignation, proclamation, verdict ;
- jeux d'action fantasy : lisibilité des zones et du burst.

Aucune animation finale ne doit reproduire une chorégraphie ou un geste signature image par image.
