import json
from pathlib import Path

from tools.qa.decision_memory_audit import run

ROOT = Path(__file__).resolve().parents[2]


def test_decision_memory_audit_has_no_errors():
    report = run(ROOT)
    failed = [f"{item['name']}: {item['detail']}" for item in report["checks"] if not item["ok"]]
    assert not failed, failed


def test_political_choices_are_interpreted_by_distinct_convictions():
    data = json.loads((ROOT / "data/hero_decision_memory.json").read_text(encoding="utf-8"))
    profiles = data["hero_profiles"]
    welcome = data["choice_vectors"]["ashlands_refugee_gate"]["welcome"]

    def score(hero_id: str) -> int:
        return sum(int(profiles[hero_id].get(key, 0)) * int(welcome.get(key, 0)) for key in data["convictions"])

    assert score("aurelien") >= data["stance_thresholds"]["strong_support"]
    assert score("lysandra") >= data["stance_thresholds"]["strong_support"]
    assert score("malvor") <= data["stance_thresholds"]["oppose"]
    assert data["stance_thresholds"]["oppose"] < score("darius") < data["stance_thresholds"]["support"]


def test_later_events_can_reframe_old_decisions_without_new_hud_meters():
    data = json.loads((ROOT / "data/hero_decision_memory.json").read_text(encoding="utf-8"))
    runtime = (ROOT / "scripts/core/decision_memory_runtime.gd").read_text(encoding="utf-8")
    ui = (ROOT / "scripts/ui/main_v19.gd").read_text(encoding="utf-8")
    assert "xenophobic_whisper" in data["social_reevaluations"]
    assert "creature_debate" in data["social_reevaluations"]
    assert 'memory["stance"] = new_stance' in runtime
    assert "reevaluation_convergence" in data["relationship_effects"]
    assert "reevaluation_divergence" in data["relationship_effects"]
    assert "MÉMOIRES DE DÉCISION" in ui
    assert "ProgressBar" not in ui
