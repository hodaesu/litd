# Triage post-playtest — LITD : Les Veilleurs

Après les sessions humaines, les mesures ne doivent pas être transformées mécaniquement en validation de gameplay. Le triage sert à organiser la revue, pas à remplacer le jugement humain.

Commande :

```bash
python -m tools.playtest.triage_veilleurs_playtests local/playtests/naive-pack --out local/reports/veilleurs_postplaytest_triage.json
```

Le rapport produit contient :

- une file de priorité P0 à P3 ;
- les métriques observées par scénario ;
- les systèmes de maturité concernés ;
- les hypothèses de correction déjà autorisées par le contrat de readiness ;
- l'état de complétude du jeu de données pour revue ;
- le prochain gate de chaque système.

## Sens des priorités

- **P0** : un problème bloquant a été observé ;
- **P1** : coaching, erreur de saisie, demande d'aide ou hésitation observée ;
- **P2** : observation incomplète ou explication joueur manquante ;
- **P3** : aucun signal quantitatif de friction détecté, mais la revue humaine reste obligatoire.

Une priorité n'est jamais un statut de gate. P0 n'est pas un `FAIL` automatique et P3 n'est pas un `PASS` automatique.

## Garde-fous

Le triage :

- ne modifie jamais `system_maturity_registry.json` ;
- n'émet jamais de PASS/FAIL humain automatique ;
- n'autorise jamais une transition de maturité automatique ;
- ne transforme jamais une hypothèse de correction en modification approuvée ;
- conserve `HUMAN_REVIEW_REQUIRED` comme seule sortie positive de préparation à une revue de gate.

Les cinq systèmes prioritaires restent donc à leur niveau canonique tant qu'une preuve humaine versionnée puis les preuves appareil réel et production n'ont pas été validées selon leurs contrats respectifs.
