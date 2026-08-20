# Contrôleur d'animations du vertical slice

Le pass 27 sépare état logique et présence réelle des clips. Cela permet de tester le mini-combat avant d'avoir les animations finales.

## Darius

`idle`, `walk`, `tactical_step`, `attack_light`, `attack_heavy`, `guard`, `hit`, `stagger`, `death`.

## Goule affamée

`idle`, `crawl_walk`, `lunge`, `claw_1`, `claw_2`, `hit`, `stagger`, `death`.

Le contrôleur cherche les clips sous leur nom direct puis sous les préfixes `default/` et `Animation/`. Si un clip manque pendant la phase proxy, l'état logique continue de fonctionner. Lorsqu'un GLB est candidat à l'ingestion finale, le loader exige en revanche les clips minimum du contrat avant de remplacer le proxy.
