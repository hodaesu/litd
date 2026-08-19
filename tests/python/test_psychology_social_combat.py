from pathlib import Path
import json

from tools.qa.psychology_social_combat_audit import run

ROOT = Path(__file__).resolve().parents[2]


def test_psychology_social_combat_audit_has_no_errors():
    report = run(ROOT)
    failed = [f"{item['name']}: {item['detail']}" for item in report["checks"] if not item["ok"]]
    assert not failed, failed


def test_fear_targeting_prefers_terrified_and_panic_states():
    data = json.loads((ROOT / "data/psychology_social_combat.json").read_text(encoding="utf-8"))
    targeting = data["targeting"]
    assert targeting["fear_weight"] > 0
    assert targeting["terrified_bonus"] > 0
    assert targeting["panic_bonus"] > targeting["terrified_bonus"]
    assert targeting["boss_fear_multiplier"] > 1.0


def test_companions_have_distinct_psychological_roles():
    data = json.loads((ROOT / "data/psychology_social_combat.json").read_text(encoding="utf-8"))
    roles = data["companion_roles"]
    assert roles["hungry_ghoul"]["role"] == "feral_guard"
    assert roles["oni"]["role"] == "protector"
    assert roles["oni"]["guard"] is True
    assert roles["jorogumo"]["role"] == "anchor"
    assert roles["jorogumo"]["hope_event"] == "combat_ally_support"


def test_ash_witness_has_specific_psychological_hunt_rule():
    data = json.loads((ROOT / "data/psychology_social_combat.json").read_text(encoding="utf-8"))
    witness = data["boss_overrides"]["c01_boss_ash_witness"]
    assert witness["archetype"] == "breaker"
    assert witness["fear_target_bonus"] > 0
    assert witness["pressure_bonus"] > 0
    assert "Témoin" in witness["line"]
