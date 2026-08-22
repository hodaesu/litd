# Registre central des mouvements LITD

Le registre `data/movement_registry.json` recense chaque mouvement connu avec son déclencheur, sa famille chorégraphique, ses marqueurs, ses variantes, son rig, son statut et son autorité.

## Couverture actuelle

- 45 mouvements de compétences par héros : 15 Offense, 15 Défense, 15 Spécial ;
- signatures/ultimes de chaque arbre ;
- locomotion, rangs et réactions anatomiques ;
- armes, dégainage et attaques ;
- interactions avec portes, coffres, leviers, autels, cadavres et objets ;
- escaliers, passages étroits, saut, escalade et obstacles ;
- feu, gaz, sang, chaînes, obscurité, effondrement et fosses ;
- repos, sommeil, repas et soins au camp ;
- langage social, relations et cinématiques ;
- réactions aux morts, captures et mutilations ;
- cinq mouvements minimum par ennemi ;
- idle, signature et trois transitions de phase par boss.

## Statuts

- `prepared` : contrat prêt ;
- `proxy` : aperçu procédural ou blockout disponible ;
- `planned_blender` : à produire dans Blender ;
- `imported` : clip importé dans Godot ;
- `validated` : contrôlé humainement dans le jeu.

## Commandes

```bash
python tools/animation/movement_registry.py audit
python tools/animation/movement_registry.py stats
python tools/animation/movement_registry.py blender-todo --output local/reports/blender_movement_queue.json
```

Un mouvement Blender ne possède jamais l’autorité gameplay. Les marqueurs d’impact, de soin, de capture et de déplacement sont consommés par Godot.
