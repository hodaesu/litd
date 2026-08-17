# Console unifiée du pipeline Blender

`tools/blender/pipeline_console.py` rassemble les 88 jobs derrière une seule interface. Elle accepte les trois modes d'instruction prévus.

## 1. Commande directe

```bash
python tools/blender/pipeline_console.py \
  --stage characters \
  --job character_aurelien
```

Ajouter `--execute` lance réellement Blender. Sans cette option, la commande affiche uniquement le plan exact.

## 2. Fichier JSON

```bash
python tools/blender/pipeline_console.py \
  --request data/blender/pipeline_request.example.json
```

Le fichier peut sélectionner plusieurs catégories ou identifiants, choisir l'exécutable Blender et l'emplacement du fichier d'état.

## 3. Questions interactives

```bash
python tools/blender/pipeline_console.py --interactive
```

La console demande les catégories, les jobs précis et si Blender doit être lancé.

## Reprise et sécurité

- le mode simulation est le comportement par défaut ;
- `--execute` est nécessaire pour lancer Blender ;
- les dépendances sont ajoutées automatiquement, notamment la bibliothèque de matériaux ;
- un job déclaré terminé n'est ignoré que si tous ses fichiers de sortie existent ;
- la progression est enregistrée dans `reports/blender_pipeline_state.json` ;
- `--no-resume` permet de reconstruire explicitement les jobs sélectionnés ;
- `--plan chemin.json` enregistre le plan avant exécution.

Cette console ne remplace pas Blender : elle transforme une demande simple en commandes reproductibles, reprend les lots interrompus et évite de relancer inutilement les productions déjà terminées.
