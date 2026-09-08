# Tableau de maturité — LITD : Les Veilleurs

Le tableau de maturité transforme le registre canonique des systèmes en une vue lisible et vérifiable de leur niveau réel de preuve.

Il conserve les cinq niveaux non sautables :

1. Implémenté
2. Testé techniquement
3. Compris par le joueur
4. Validé mobile
5. Verrouillé pour production

Le générateur ne promeut jamais un système. Il lit seulement le registre existant, les contrats de validation joueur et matériel, puis expose :

- niveau actuel ;
- prochain gate ;
- type du prochain gate ;
- preuves encore absentes ;
- blocages ;
- autorisation ou non du scale-up de contenu.

Commande de contrôle :

```bash
python -m tools.qa.veilleurs_maturity_dashboard --check
```

Commande de génération :

```bash
python -m tools.qa.veilleurs_maturity_dashboard
```

Sortie par défaut : `reports/veilleurs_maturity_dashboard.json`.

## Règle de production

Le tableau n'autorise le scale-up que lorsqu'un système prioritaire est `production_locked`. Tant que les systèmes critiques restent à 2/5, les nouveaux donjons, ennemis et volumes de contenu ne doivent pas être accélérés au détriment des preuves joueur et mobile.
