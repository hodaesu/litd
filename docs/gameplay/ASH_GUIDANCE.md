# Guidage du joueur par la traînée de cendres

La traînée de cendres est le langage de navigation diégétique de LITD. Elle ne fonctionne pas comme une flèche HUD : les particules s'élèvent autour du joueur, virevoltent, puis s'étirent vers la direction à suivre.

## Objectifs

- Donjon : guider vers le passage praticable qui rapproche du boss, sans pointer à travers les murs.
- Quête : guider vers l'objectif actif ou le prochain point de passage de la quête.
- Le guidage ne révèle pas les salles secrètes non découvertes.

## Couleurs

- Boss : gris à longue distance, puis rouge de plus en plus incandescent à mesure que le joueur s'approche.
- Quête : gris à longue distance, puis bleu de plus en plus présent à mesure que le joueur s'approche.

La transition de couleur est continue et lissée afin d'éviter les changements brusques.

## Mouvement

Le flux comprend deux couches de particules : une traînée principale et des motes plus légères. Les particules ont une composante verticale et tourbillonnante, tandis que leur direction moyenne s'aligne progressivement vers l'objectif. Le guidage suit le joueur et conserve une direction lisible même en mouvement.

## Donjons physiques

Dans les Cryptes du Premier Voile, le calcul utilise le graphe réel des salles. Depuis la salle actuelle, il cherche le plus court chemin public vers la salle du boss et guide le joueur vers la prochaine sortie de ce chemin. Les passages secrets non découverts sont exclus du calcul.

## Intensité contextuelle

Le système peut moduler densité, turbulence et émission selon la proximité, la peur, le danger et la sécurité de l'environnement. Cette modulation ne doit jamais masquer la fonction principale : montrer une direction claire.
