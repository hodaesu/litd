# LITD : Les Veilleurs — modèle de maturité des systèmes

## Pourquoi ce modèle existe

Un système peut être présent dans le code sans être prêt pour la production. Pour éviter les faux « terminé », Les Veilleurs utilise cinq niveaux de maturité cumulatifs et non sautables.

## Niveau 1 — Implémenté

Le système existe réellement dans le runtime ou dans la verticale jouable. Ses dépendances principales sont présentes et il peut être exécuté.

Ce niveau ne prouve ni sa stabilité, ni sa compréhension, ni son confort.

## Niveau 2 — Testé techniquement

Les tests, audits et smokes nécessaires passent sur un commit précis. Les règles et dépendances objectivables sont cohérentes et aucun problème technique bloquant connu n'empêche le scénario contrôlé.

Une CI verte ne fait jamais passer automatiquement un système au niveau 3.

## Niveau 3 — Compris par le joueur

Des playtests humains montrent que les décisions, causes et conséquences sont comprises sans coaching indu du développeur. Les preuves sont versionnées et rattachées à un build précis.

Un joueur doit notamment pouvoir expliquer ce qu'il essayait de faire et pourquoi le résultat s'est produit.

## Niveau 4 — Validé mobile

Le système est validé sur appareil réel : tactile, safe areas, lisibilité, performance, mémoire, thermique, audio et haptique lorsque pertinent.

Les simulations, émulations et régressions logiques ne remplacent pas cette étape.

## Niveau 5 — Verrouillé pour production

Le système réunit quatre preuves :

- design : l'intention et les critères sont clairs ;
- joueur : l'expérience recherchée est observée ;
- technique : les tests et régressions passent ;
- production : le procédé est reproductible pour produire plus de contenu sans reconstruire le système.

À ce niveau seulement, l'expansion de contenu utilisant ce système peut accélérer sans requalifier chaque fondation comme prototype.

## Règles

- aucun niveau ne peut être sauté ;
- une régression peut faire redescendre un système ;
- la CI ne peut jamais promouvoir seule aux niveaux 3 ou 4 ;
- une preuve doit pointer vers un build/commit et un rapport concret ;
- « pas de bug observé » n'est pas une preuve de compréhension joueur ;
- « jouable dans l'éditeur » n'est pas une validation mobile ;
- le niveau le plus bas d'une dépendance critique peut limiter le système parent.

## État actuel du combat

Le registre machine est `data/veilleurs/system_maturity_registry.json`.

À la création de ce modèle, le combat principal est :

**Niveau 2/5 — Testé techniquement.**

Preuves déjà disponibles : règles de tours, rangs et déplacements, anatomie/démembrement, familles ennemies, psychologie, smokes Godot et CI.

Preuve suivante obligatoire : `combat_decision_readability` dans le contrat de validation joueur.

Le passage au niveau 3 exige des playtests humains versionnés. Le passage au niveau 4 exige ensuite les validations sur téléphone réel. Le niveau 5 exige enfin que le Chapitre I démontre que le système et son contenu peuvent être reproduits de manière fiable.

## Commande QA

```bash
python -m tools.qa.veilleurs_system_maturity_audit
```

Cet audit empêche notamment de déclarer un système au niveau joueur/mobile/production sans les catégories de preuves correspondantes.
