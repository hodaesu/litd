# LITD : Les Veilleurs — Bible de direction artistique de production

## Rôle

Cette bible transforme les références artistiques de LITD en règles suffisamment précises pour produire, comparer et valider des assets cohérents.

Elle complète `docs/BIBLIOTHEQUE_ARTISTIQUE_MONDE.md` : la bibliothèque explique **où chercher** ; ce document explique **comment décider**.

---

## 1. Piliers visuels

### 1. Beauté survivante

Le monde est détruit mais n'a pas perdu toute culture. Les ruines doivent laisser percevoir une civilisation qui avait une pensée esthétique, civique et artisanale développée.

### 2. Matière et conséquence

Pierre, peau, tissu, métal, cendre, sang, cicatrices et réparations doivent sembler avoir une histoire. Les dégâts ne sont pas seulement décoratifs : ils racontent l'usage et la conséquence.

### 3. Sacré sans copie

La sensation de rituel, de seuil, de mémoire et de monumentalité peut être nourrie par plusieurs traditions historiques, mais aucune iconographie sacrée réelle ne doit devenir un simple motif LITD reconnaissable.

### 4. Lisibilité tactique

La beauté ne doit jamais empêcher le joueur de lire : personnage, ennemi, rang, état, cible, blessure, danger, interaction et priorité.

---

## 2. Palette canonique

La référence actuelle de l'interface Les Veilleurs repose sur :

- noir / charbon ;
- os / ivoire ;
- métal ;
- rouge sang ;
- ocre / or ;
- bleu froid ;
- vert désaturé ;
- violet.

Règle : ces familles ne sont pas toutes utilisées avec la même intensité. Les tons sombres et os/métal structurent la base ; les accents portent l'information et l'émotion.

Les valeurs hexadécimales finales doivent être extraites de l'atlas UI canonique et stockées comme tokens partagés plutôt que recopiées manuellement dans plusieurs scènes.

### Rôles sémantiques recommandés

- **rouge sang** : blessure, danger corporel, hostilité, rupture ;
- **ocre/or** : valeur, rareté, héritage, décision importante ;
- **bleu froid** : contrôle, stabilité, information mentale ou systémique selon contexte ;
- **vert désaturé** : récupération, viable, organique, coexistence selon contexte ;
- **violet** : altération, Voile, étrangeté, effet non ordinaire ;
- **os/ivoire** : texte principal, structure, éléments lisibles sur fond sombre.

Aucune information critique ne doit dépendre de la couleur seule.

---

## 3. Valeurs et contraste

Avant la couleur, toute scène ou UI importante doit rester compréhensible en niveaux de gris.

Checklist :

- silhouette du personnage détachable du fond ;
- cible active immédiatement visible ;
- texte lisible ;
- plans séparés ;
- danger identifiable ;
- éléments interactifs distincts du décor ;
- VFX ne masquant pas l'anatomie ou la cible.

---

## 4. Formes et silhouettes

Chaque famille doit avoir une signature lisible à petite taille.

Pour chaque héros/ennemi :

- masse principale ;
- direction dominante ;
- largeur/hauteur ;
- rythme des volumes ;
- asymétrie éventuelle ;
- équipement distinctif ;
- lecture avant détail.

Deux personnages dont la silhouette se confond à la taille de jeu doivent être différenciés avant d'ajouter davantage de texture.

---

## 5. Matériaux

Les matériaux doivent raconter trois choses :

1. origine ;
2. usage ;
3. état actuel.

Exemple : un métal de Sanctuaire réparé plusieurs fois doit avoir une logique de fabrication et de maintenance différente d'un vestige intact pré-Chute.

Éviter le bruit uniforme. Les zones de forte information visuelle doivent être limitées et dirigées.

---

## 6. Environnements

Chaque environnement doit définir :

- histoire du lieu avant la Chute ;
- événement ou transformation ;
- activité actuelle ;
- palette secondaire ;
- matériau dominant ;
- forme architecturale dominante ;
- niveau de destruction ;
- éléments de navigation ;
- éléments interactifs ;
- point focal ;
- contraste combat/exploration.

La narration environnementale doit rester compréhensible sans texte lorsque c'est possible.

---

## 7. Personnages

Pour chaque personnage :

- rôle ;
- origine sociale/culturelle ;
- silhouette ;
- posture ;
- centre de gravité ;
- langage gestuel ;
- matériaux ;
- palette secondaire ;
- signes d'usure ;
- éléments qui changent avec progression/blessure ;
- limites à ne pas franchir pour conserver l'identité.

La diversité humaine ne doit pas être obtenue par simple variation de teinte : morphologie, cheveux, traits, vêtements, culture matérielle et histoire doivent être pensés avec cohérence.

---

## 8. Créatures et gore systémique

Le gore doit servir la lecture fonctionnelle :

- quelle partie est touchée ?
- quelle fonction est perdue ?
- quel danger persiste ?
- quel état est irréversible ?

Les variantes de blessure doivent être produites à partir de contrats anatomiques cohérents et non comme une collection d'effets indépendants.

Une option de réduction visuelle du gore ne doit jamais supprimer l'information tactique : icône, silhouette, animation et état UI doivent maintenir la compréhension.

---

## 9. UI

L'UI doit ressembler au même monde que les environnements sans devenir un décor illisible.

Priorité :

1. hiérarchie ;
2. interaction ;
3. état ;
4. feedback ;
5. ornement.

Les jauges et indicateurs utilisent la palette canonique harmonisée. Les styles ne doivent pas dériver écran par écran.

Créer des composants réutilisables :

- jauge ;
- bouton ;
- onglet ;
- carte ;
- tooltip ;
- panneau contextuel ;
- état sélectionné ;
- état désactivé ;
- danger ;
- rareté.

---

## 10. VFX

Tout VFX doit avoir :

- rôle gameplay ;
- durée ;
- priorité ;
- couleur principale ;
- valeur ;
- budget particules/transparence ;
- version réduite si performance ;
- test de lisibilité avec plusieurs effets simultanés.

Sur mobile, limiter les couches transparentes superposées et les effets plein écran coûteux.

---

## 11. Animation

L'animation doit exprimer :

- poids ;
- intention ;
- conséquence ;
- anticipation ;
- impact ;
- récupération.

Pour le combat tactique, la lecture de l'action prévaut sur la virtuosité. Une animation plus courte et claire vaut mieux qu'une animation longue qui ralentit le rythme ou masque le résultat.

Les ultimes peuvent dépasser ce cadre, mais doivent conserver une version accélérée ou une logique de répétition non fatigante si les playtests le demandent.

---

## 12. Pipeline de validation d'asset

### A. Brief

Objectif gameplay, rôle narratif, contexte, taille écran, contraintes.

### B. Références

Au moins plusieurs sources et, idéalement, plusieurs médiums. Documenter ce qui est retenu et ce qui est transformé.

### C. Exploration

Silhouettes et valeurs avant détail.

### D. Production

Asset suivant conventions de nommage, matériaux, échelle et budget.

### E. Intégration

Test dans Godot dans la vraie scène.

### F. Validation mobile

Taille réelle, contraste, performance, interaction, safe area si UI.

### G. Approbation

Captures avant/après, version source, version runtime, statut et notes.

---

## 13. Critères « oui / non »

### Oui

- silhouette claire ;
- détail concentré ;
- matériaux crédibles ;
- palette cohérente ;
- histoire visible ;
- originalité issue de plusieurs influences transformées ;
- lecture mobile immédiate.

### Non

- bruit visuel partout ;
- copie d'une référence unique ;
- couleur utilisée comme seule information ;
- accumulation de détails invisibles en jeu ;
- VFX qui cachent les cibles ;
- UI décorative avant d'être fonctionnelle ;
- assets validés uniquement sur une planche.

---

## 14. Revue artistique hebdomadaire

Pour chaque élément revu :

1. intention ;
2. capture en jeu ;
3. lecture à taille téléphone ;
4. silhouette/valeurs ;
5. palette ;
6. cohérence culturelle ;
7. originalité ;
8. performance ;
9. décision : valider / modifier / supprimer.

La capture en jeu est la preuve principale. Le concept art est une étape, pas le produit final.
