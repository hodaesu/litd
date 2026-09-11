# LITD Global Governance Foundation

`LITD-GOVERNANCE-FOUNDATION-001` relie la bibliothèque vivante, le Core,
le Guardian, l'exécution et les preuves sans donner d'autorité d'écriture
directe à un outil automatique.

## Invariants

- Knowledge documente; le Core décide; le Guardian autorise ou bloque.
- Aucun composant automatique ne modifie directement le Core.
- Toute transition est explicite, versionnée et reliée à des preuves.
- Une référence inconnue, obsolète ou en quarantaine ferme le Gate.
- `GREEN` exige un Knowledge Gate valide, une décision approuvée, un plan de
  test et un plan de retour arrière.

## Registres

- `knowledge_registry.json`: connaissances et provenance.
- `decision_registry.json`: décisions du Core et objections.
- `change_registry.json`: cycle des changements réels.
- `evidence_registry.json`: tests, mesures et observations.

Validation locale:

```bash
python -m tools.quality.global_governance
```

## Transitions opérationnelles

`governance_transition` prépare une seule transition séquentielle, ajoute une
preuve sans doublon et valide l'état complet avant toute écriture. Le mode par
défaut est une prévisualisation; `--apply` doit être demandé explicitement.

```bash
python -m tools.quality.governance_transition \
  CHG-EXEMPLE-001 APPLIED \
  --evidence-json evidence.json

python -m tools.quality.governance_transition \
  CHG-EXEMPLE-001 APPLIED \
  --evidence-json evidence.json \
  --apply
```

Une transition `APPLIED` exige une preuve `GIT_COMMIT`; `MEASURED` exige une
preuve de CI, d'exécution, de playtest ou de performance. L'outil ne peut
jamais modifier le Core ni les données de gameplay.
