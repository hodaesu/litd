# QA du vertical slice

Commandes utilisables sans Blender :

```bash
python -m tools.qa.visual_slice_runtime_audit
python -m tools.qa.visual_slice_examples_audit
python -m tools.qa.visual_slice_review_schema_audit
python tools/blender/vertical_slice_session.py --preflight --ci
pytest -q tests/test_visual_slice_runtime.py tests/test_visual_slice_session.py
```

Sur PC, après génération d'un rapport d'inspection 3D :

```bash
python -m tools.qa.visual_asset_validator reports/darius_asset_report.json
python -m tools.qa.visual_review_validator reports/visual_slice_darius_review.json
```
