# LITD : Les Veilleurs — préparation playtest Wave 2

## Objectif

Cette couche prépare le passage du combat et des systèmes prioritaires de **2/5 — testé techniquement** vers **3/5 — compris par le joueur**.

Elle ne constitue pas une validation humaine. Les outils peuvent préparer, mesurer, agréger et signaler des risques ; ils ne peuvent jamais convertir automatiquement un résultat humain en `PASS`.

## 1. Correctifs probables préparés, non appliqués à l'aveugle

Cinq familles de corrections sont prêtes à être déclenchées par les observations :

1. **Feedback de cible / zone anatomique** — si le joueur hésite ou se trompe sur la cible ou la zone ;
2. **Prévisualisation action → conséquence** — si le joueur ne sait pas ce que la compétence devrait provoquer ;
3. **Feedback causal Peur/Folie/blessure** — si le joueur voit un changement sans comprendre sa cause ;
4. **Affordance d'exploration** — si l'incertitude voulue ressemble à une interaction cachée ;
5. **Retour de conséquence au Sanctuaire** — si le joueur ne relie pas l'expédition à l'état persistant du monde.

Règle : aucune de ces corrections n'est appliquée uniquement parce qu'elle paraît plausible. Le déclencheur doit exister dans une session observée, sauf bug évident ou défaut d'accessibilité indépendant du gameplay.

## 2. Mesures standardisées

Chaque observation de scénario utilise les mêmes champs :

- `tester_id` ;
- `build_commit` ;
- `platform` ;
- `scenario_id` ;
- `first_action` ;
- `hesitation_count` ;
- `help_request_count` ;
- `coach_intervention_count` ;
- `misinput_count` ;
- `blocking_issue_count` ;
- `player_explanation` ;
- `observer_notes`.

Les scénarios minimum sont : onboarding, décision de combat, causalité anatomique, Peur/Folie, exploration et conséquence au Sanctuaire.

L'agrégateur :

```bash
python -m tools.playtest.summarize_naive_playtests local/playtests/naive-pack --out local/playtests/naive-pack/SUMMARY.json
```

Il calcule les volumes d'hésitations, demandes d'aide, interventions, erreurs de saisie et blocages par scénario. Il ne produit **aucune décision PASS/FAIL automatique**.

## 3. Cinq sessions de testeurs naïfs

Le paquet canonique est généré avec :

```bash
python -m tools.playtest.prepare_naive_tester_pack --count 5
```

Chaque dossier `naive-01` à `naive-05` contient :

- `player_validation.json` — tous les gates à `NOT_RUN` ;
- `observer_notes.md` — fiche d'observation ;
- `measurement_events.jsonl` — mesures structurées ;
- `session_manifest.json` — identifiant du testeur, commit, statut et scénarios.

Le workflow `Veilleurs Playtest Readiness` fabrique aussi ce paquet automatiquement à chaque PR pertinente et sur `main`, afin qu'il puisse être téléchargé sans préparer le PC.

## 4. Accessibilité — readiness statique

Avant validation appareil, on exige au minimum :

- aucune information critique dépend uniquement d'une couleur ;
- tout contrôle interactif doit pouvoir présenter un état de focus identifiable lorsqu'un mode focus est utilisé ;
- le texte essentiel doit rester conçu pour la lecture mobile ;
- une action destructive critique doit demander confirmation ou offrir un retour arrière sûr ;
- l'haptique doit toujours avoir un équivalent visuel ou audio ;
- les flashs rapides doivent être évitables ou strictement bornés ;
- le mouvement ne doit jamais être l'unique canal d'un feedback critique.

Ce gate est un **readiness**, pas une certification d'accessibilité. La validation réelle nécessite encore observation humaine et appareils.

## 5. Localisation — readiness statique

Le français reste la locale source. Avant traduction massive :

- les textes joueur doivent avoir des clés stables ;
- aucune règle de gameplay ne doit dépendre du texte français affiché ;
- l'UI doit accepter une expansion de texte cible de **35 %** ;
- nombres et unités doivent pouvoir être séparés de l'ordre de phrase ;
- un plan de fallback de polices est requis avant des locales non latines ;
- une passe de pseudo-localisation est requise avant verrouillage des traductions.

Cette couche ne revendique pas qu'une traduction est bonne : une validation linguistique humaine reste obligatoire.

## 6. Performance théorique

Le contrat reste aligné sur le gate matériel `gpu_cpu_thermal_performance` :

- cible préférée : **60 FPS** ;
- plancher dur : **30 FPS** ;
- budget indicatif 60 FPS : **16,67 ms/frame** ;
- budget indicatif 30 FPS : **33,33 ms/frame** ;
- crash accepté : **0** ;
- problème bloquant accepté : **0**.

Les scénarios runtime obligatoires restent : cold launch, hub 10 min, combat 20 min, traversée six donjons, stress ultime et boucle sauvegarde/reprise.

L'audit statique vérifie la cohérence de ces budgets avec le contrat matériel. Il ne peut pas déclarer un PASS de performance sans mesures runtime réelles.

## 7. Audit

```bash
python -m tools.qa.veilleurs_playtest_readiness_audit
pytest -q tests/test_veilleurs_playtest_readiness.py
```

La CI doit échouer si :

- le minimum de cinq testeurs est réduit ;
- une session préparée n'est plus neutre ;
- les budgets performance divergent du contrat matériel ;
- les règles d'accessibilité/localisation de readiness disparaissent ;
- un outil tente d'automatiser la décision humaine.

## 8. Ce qui pourra être corrigé automatiquement après le premier test

Une fois les observations saisies, les compteurs permettront de classer les problèmes par scénario et fréquence. Les correctifs de lisibilité et d'UX pourront alors être priorisés par preuve : blocages d'abord, puis erreurs répétées, puis hésitations, puis polish.

Le système de maturité ne progresse cependant que lorsque les rapports humains correspondants sont réellement renseignés et validés par le contrat existant.
