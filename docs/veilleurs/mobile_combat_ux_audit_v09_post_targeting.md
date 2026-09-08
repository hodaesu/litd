# Audit UX combat mobile v0.9 — post ciblage explicite

Date : 2026-09-08

## Objectif

Vérifier qu’un tour de combat de LITD : Les Veilleurs reste compréhensible de bout en bout sur mobile après l’ajout du ciblage explicite et du feedback d’impact, sans modifier les règles ni l’équilibrage du combat.

Flux audité :

`Veilleur actif → compétence → cible → zone anatomique → aperçu → confirmation → résolution → riposte → prochain choix`

## État du flux

### 1. Veilleur actif — couvert

- Le combattant actif est marqué `▶` sur la grille.
- Le bandeau principal le nomme explicitement.
- Le changement de Veilleur reste possible hors mode de ciblage.
- En mode de ciblage, toucher un allié ou une case vide ne change plus accidentellement l’attaquant.

### 2. Choix de compétence — couvert

- Le premier toucher arme la compétence et n’exécute pas une attaque offensive.
- La compétence armée reste visuellement identifiable.
- Les actions offensives passent en état `CIBLER` puis `CONFIRMER`.
- Les actions personnelles ou de soutien conservent un flux de confirmation court adapté.

### 3. Ciblage ennemi — couvert et testé

- `○` : cible valide.
- `×` : cible hors portée ou indisponible.
- `◎` : cible explicitement verrouillée.
- Une cible hors portée ne déclenche pas de signal tactique et ne désarme pas la compétence.
- Une attaque ne peut plus être confirmée sur l’ancienne cible présélectionnée sans nouvelle sélection explicite après armement.

### 4. Zone anatomique — couvert et testé

- La zone reste modifiable après verrouillage de la cible.
- Changer de zone ne désarme pas la compétence et ne perd pas la cible.
- Les noms techniques (`left_arm`, `right_leg`, etc.) sont traduits dans les surfaces de feedback joueur.

### 5. Aperçu avant confirmation — couvert

- L’aperçu donne la cible, la zone, la chance de toucher, les dégâts estimés, la portée et l’effet lorsque ces informations sont disponibles.
- Le joueur sait explicitement qu’un second toucher sur la compétence exécute l’action.

### 6. Résolution de l’action — renforcée

Le feedback lit directement le résultat produit par le runtime :

- `RATÉ` / `TOUCHÉ` ;
- dégâts ;
- PV restants ;
- zone anatomique ;
- traumatisme ;
- gravité anatomique ;
- démembrement ;
- lésion vitale ;
- statuts appliqués ;
- protection redirigée ;
- soin, garde, soutien, observation, contrôle, déplacement et posture.

Aucune formule de combat n’est dupliquée dans l’UI.

### 7. Riposte ennemie — renforcée

Le résumé global a été remplacé par un retour action par action, limité à quatre lignes visibles pour préserver l’écran mobile :

- ennemi responsable ;
- Veilleur ciblé ;
- zone touchée ;
- dégâts ;
- perte de résolution ;
- statut important ;
- gravité anatomique critique ;
- raté ;
- repositionnement ou attente.

Les actions excédentaires sont regroupées sous `+N autres actions`.

### 8. Inspection — renforcée et testée

L’inspection rend maintenant prioritaires :

1. anatomie critique et membres perdus ;
2. statuts runtime v0.9 ;
3. blessures persistantes ;
4. conséquences fonctionnelles ;
5. traits, buffs et debuffs ;
6. compétences.

Les états anatomiques sont affichés en français : `atteint`, `blessé`, `critique`, `hors d'usage`, `détruit`.

Les conséquences fonctionnelles visibles incluent : maniement des armes réduit, mobilité réduite, perception réduite et vigueur réduite.

### 9. Soumission — couvert

- La disponibilité est visible sans dépendre d’un tooltip.
- Les conditions sont rappelées : PV ≤ 35 %, Résolution ≤ 20 ou contrôle compatible.
- Les boss sont explicitement non soumis.
- Les statuts de contrôle utilisés comme déclencheurs sont affichés en français (`peur`, `entrave`, `immobilisation`, `déséquilibre`).
- La cible reste vivante pour la décision post-combat.

### 10. Retraite — couvert

- La retraite nécessite une confirmation séparée dans une fenêtre courte.
- L’armement d’une compétence et la retraite ne partagent pas le même état de confirmation.
- Aucune retraite ne doit pouvoir partir au premier toucher.

### 11. Boss / Elite / Nemesis — couvert

- Les badges de grille distinguent boss, Nemesis, Elite, Vétéran et Mémoriel.
- Le bandeau remonte la phase du boss et la phase suivante lorsqu’elle est télégraphiée.
- Les règles de ciblage et d’anatomie restent les mêmes que pour les autres ennemis, sauf contrats spécifiques du boss.

### 12. Safe area, échelle UI et texte — couvert automatiquement, validation matérielle encore requise

- La scène v0.9 applique les marges de safe area natives sur mobile.
- L’inspection est responsive et respecte `ui_scale` / `text_scale`.
- Le nouveau panneau de feedback calcule aussi sa propre safe area et sa taille maximale.
- Les overlays de soumission et d’aperçu sont décalés par la couche safe-area v0.9.

## Régressions désormais verrouillées

Le smoke tactile couvre explicitement :

- premier toucher sur un ennemi = sélection, pas inspection ;
- second toucher sur le même ennemi = inspection ;
- inspection à `ui_scale = 1.4` dans le viewport ;
- `text_scale = 1.4` visible ;
- membre perdu visible ;
- statut v0.9 visible ;
- conséquence fonctionnelle visible ;
- compétence offensive armée sans exécution immédiate ;
- `CIBLER` visible ;
- `○` cible valide ;
- `×` cible bloquée ;
- cible bloquée sans émission tactique ;
- cible valide verrouillée en `◎` ;
- `CONFIRMER` visible ;
- changement de zone sans perte de compétence/cible ;
- désarmement réinitialisant complètement le ciblage ;
- feedback `TOUCHÉ` ;
- feedback `RATÉ` et chance de toucher ;
- traumatisme et gravité anatomique ;
- statut appliqué ;
- démembrement ;
- riposte détaillée par ennemi/cible/zone/dégâts/statut.

## Ce qui reste obligatoirement à valider sur iPhone réel

Ces points ne peuvent pas être conclus par CI ou simulation headless :

- Dynamic Island / encoche / indicateur d’accueil ;
- lisibilité physique des textes à distance normale ;
- confort à une main et à deux mains ;
- taux de mauvais toucher sur les cases 56×56 et boutons anatomiques ;
- durée idéale de la fenêtre de ciblage de 12 s ;
- durée idéale de la confirmation de 3,2 s ;
- durée idéale de la confirmation de retraite de 2,5 s ;
- temps de lecture réel du feedback de 4,4 s ;
- haptique ;
- audio réel ;
- GPU, CPU, chauffe et autonomie ;
- reprise de sauvegarde en situation réelle ;
- confort sur un combat long avec boss, Nemesis, blessures et soumission.

## Verdict avant test matériel

Le flux de combat mobile est techniquement cohérent et fortement couvert par les tests automatiques. Aucun changement structurel du système de combat n’est recommandé avant le prochain playtest humain. Les prochaines corrections doivent rester limitées à la lisibilité, au rythme, au confort tactile et aux retours sensoriels jusqu’à obtention de données réelles sur iPhone.
