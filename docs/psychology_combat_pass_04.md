# Psychologie de combat — Pass 04

## Principe

La Peur reste la seule valeur psychologique affichée comme jauge. Les conséquences sont maintenant directement jouables : plus la Peur monte, plus l'exécution des actions devient difficile. La Folie demeure un ensemble de traces persistantes et l'Espoir reste un événement, jamais une monnaie.

## Paliers de Peur

- **Calme (0–24)** : aucun malus.
- **Inquiet (25–49)** : précision légèrement réduite.
- **Effrayé (50–74)** : précision, dégâts et soins réduits.
- **Terrifié (75–99)** : pénalités fortes sur les trois axes.
- **Panique (100)** : crise immédiate au moment d'agir. Sans protection, le héros perd son action en se figeant ou en reculant, puis retombe à 85 de Peur.

## Traces individuelles

Les traces acquises par un héros modifient désormais la manière dont les paliers de Peur l'affectent. Une dissociation peut amortir certains malus, tandis qu'un souvenir de panique peut les renforcer. Les traumatismes et obsessions orientent également la réaction de Panique vers le gel ou le recul.

## Espoir

Une manifestation d'Espoir prépare au maximum **un élan de résolution**. Si le héros atteint 100 de Peur avant de l'avoir dépensé, cet élan est consommé automatiquement : la crise est évitée, l'action est conservée et la Peur redescend à 70.

L'Espoir ne se cumule donc pas comme une ressource. Il laisse une possibilité concrète de résister à une crise future.

## Compatibilité

Les anciennes valeurs numériques `madness` et `hope` restent dans les héros pour assurer la lecture des sauvegardes historiques. Les écritures héritées déclenchées pendant les tours ennemis sont restaurées immédiatement ; les conséquences actives passent par `PsychologyRuntime`.

## Validation

Le pass est couvert par :

- `psychology_smoke.tscn` ;
- `tools.qa.psychology_combat_audit` ;
- `tests/python/test_psychology_combat.py` ;
- la CI Godot stricte et les parcours existants.
