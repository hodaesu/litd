# Workflow de revue visuelle

1. Générer le blockout sans exporter le GLB final.
2. Rendre un turntable et une capture à la caméra de combat.
3. Remplir le rapport de revue à partir du modèle `reports/visual_slice_review_template.json`.
4. Valider le rapport avec `tools/qa/visual_review_validator.py`.
5. Corriger toute note bloquante sous 4/5.
6. Exporter le GLB seulement après approbation humaine.
