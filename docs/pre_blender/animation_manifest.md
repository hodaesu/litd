# Manifeste d'animations

## Humanoïde commun

- idle
- combat_idle
- walk
- run
- turn_left / turn_right
- hit_light / hit_heavy
- dodge
- guard
- death
- interact

## Combat

Chaque classe ajoute ses attaques et compétences propres. Les animations doivent être découpées pour permettre à Godot de synchroniser impact, VFX, son et résolution des dégâts.

## Croisé

attacks sword 1/2, défense au bouclier, provocation, frappe finale.

## Chasseur de l'Ombre

tir précis, salve rapide, embuscade, désengagement, frappe finale.

## Médecin de la Peste

lancer de fiole, nuage toxique, soin, lancer de grenade, frappe finale.

## Acolyte des Ténèbres

invocation, drain de vie, malédiction, incantation, frappe finale.

## Gardien des Tombeaux

coup puissant, frappe circulaire, parade, contre-attaque, frappe finale.

## Technique

Le root motion doit être décidé animation par animation. Les points d'événement d'impact seront documentés lors de la fabrication afin que le gameplay reste déterministe côté Godot.
