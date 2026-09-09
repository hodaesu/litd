import json
from pathlib import Path

from tools.qa.decision_memory_audit import run

ROOT = Path(__file__).resolve().parents[2]
CURRENT_HEROES = {"mathilde", "marec", "anouk", "aurelien"}


def test_decision_memory_audit_has_no_errors():
    report = run(ROOT)
    failed = [f"{item['name']}: {item['detail']}" for item in report["checks"] if not item["ok"]]
    assert not failed, failed


def test_political_choices_are_interpreted_by_distinct_convictions():
    data = json.loads((ROOT / "data/hero_decision_memory.json").read_text(encoding="utf-8"))
    profiles = data["hero_profiles"]
    welcome = data["choice_vectors"]["ashlands_refugee_gate"]["welcome"]

    assert set(profiles) == CURRENT_HEROES

    def score(hero_id: str) -> int:
        return sum(int(profiles[hero_id].get(key, 0)) * int(welcome.get(key, 0)) for key in data["convictions"])

    scores = {hero_id: score(hero_id) for hero_id in CURRENT_HEROES}
    thresholds = data["stance_thresholds"]

    # The QA contract verifies distinct authored convictions, not a prescribed
    # political opinion inherited from a previous quartet.
    assert len(set(scores.values())) >= 3
    assert max(scores.values()) >= thresholds["strong_support"]
    assert min(scores.values()) < thresholds["support"]
    assert scores["mathilde"] != scores["marec"]
    assert scores["anouk"] != scores["aurelien"]


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
