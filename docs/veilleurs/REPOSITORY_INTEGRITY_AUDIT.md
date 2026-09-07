# Audit d’intégrité du dépôt — LITD : Les Veilleurs

`tools/qa/veilleurs_repository_integrity_audit.py` complète les audits fonctionnels en contrôlant les incohérences entre dossiers.

Le gate vérifie notamment :

- parsing de tous les JSON sous `data/veilleurs/` ;
- quatuor canonique exact et loadouts de départ ;
- 12 arbres / 180 compétences uniques et cohérence avec le contrat source ;
- 24 ennemis ordinaires uniques ;
- six donjons de production ;
- alignement `project.godot` / contrat pré-PC / pipeline sur Godot 4.7 ;
- workflows Godot alignés sur l’image CI 4.7.2 et template Android correspondant ;
- existence de tous les fichiers requis par le verrou pré-PC ;
- absence de dérive vers l’ancien quatuor hors exceptions historiques et fichiers de garde négative autorisés ;
- résolution des références `res://` statiques des scènes et scripts Les Veilleurs ;
- absence de fichiers texte actifs vides.

Les marqueurs explicites de dette de code et les références `VS001` encore présentes sont reportés comme avertissements afin de distinguer dette technique et rupture de contrat.

Le contrôle est exécuté à la fois par `pytest` et par le pipeline de production Les Veilleurs. Son rapport est écrit dans `build/automation/veilleurs_repository_integrity.json`.
