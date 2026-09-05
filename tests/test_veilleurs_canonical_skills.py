import json
from pathlib import Path

from tools.qa.veilleurs_canonical_skills_audit import audit


def test_veilleurs_canonical_skills_contract_is_coherent():
    errors = audit()
    report_dir = Path("reports")
    report_dir.mkdir(parents=True, exist_ok=True)
    (report_dir / "veilleurs-canonical-skills-audit.json").write_text(
        json.dumps({"ok": not errors, "errors": errors}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    assert errors == []
