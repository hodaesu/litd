import json

from tools.qa.veilleurs_player_validation_audit import main as audit_main
from tools.qa.veilleurs_player_validation_report import CONTRACT_PATH, ROOT, validate_report


def _load_inputs() -> tuple[dict, dict]:
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    report = json.loads(
        (ROOT / "reports/veilleurs_player_validation_template.json").read_text(encoding="utf-8")
    )
    return report, contract


def test_veilleurs_player_validation_contract_is_coherent() -> None:
    assert audit_main() == 0


def test_empty_template_is_valid_as_incomplete_report() -> None:
    report, contract = _load_inputs()
    assert validate_report(report, contract, allow_incomplete=True) == []


def test_empty_template_cannot_unlock_content_scale_up() -> None:
    report, contract = _load_inputs()
    errors = validate_report(report, contract, allow_incomplete=False)
    assert errors
    assert any("montée en volume interdite" in error for error in errors)
