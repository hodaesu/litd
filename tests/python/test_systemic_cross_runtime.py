from __future__ import annotations

import json
from pathlib import Path

from tools.qa.systemic_cross_runtime_audit import audit_systemic_cross_runtime


ROOT = Path(__file__).resolve().parents[2]


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_systemic_cross_runtime_audit_passes() -> None:
    report = audit_systemic_cross_runtime(ROOT)
    assert report["ok"], report
    assert report["summary"]["events"] == 18
    assert report["summary"]["cascades"] == 4


def test_every_canonical_cross_event_and_cascade_has_runtime_presentation() -> None:
    canon = load(ROOT / "universe/lore/contextual_quest_cross_ramifications.json")
    runtime = load(ROOT / "data/narrative/systemic_cross_runtime.json")
    event_ids = {item["id"] for item in canon["cross_events"]}
    cascade_ids = {item["id"] for item in canon["compound_cascades"]}
    assert set(runtime["events"]) == event_ids
    assert set(runtime["cascades"]) == cascade_ids


def test_runtime_keeps_moral_scores_out_of_cross_consequences() -> None:
    presentation = load(ROOT / "data/narrative/systemic_cross_runtime.json")
    assert presentation["rules"]["new_universal_meter"] is False
    assert presentation["rules"]["global_morality_score"] is False
    runtime_text = (ROOT / "scripts/core/systemic_cross_runtime.gd").read_text(encoding="utf-8")
    for forbidden in ["reputation_score", "morality_score", "alignment_score", "ProgressBar", "PoliticalState.reputation"]:
        assert forbidden not in runtime_text


def test_runtime_preserves_source_reliability_and_conditional_speakers() -> None:
    presentation = load(ROOT / "data/narrative/systemic_cross_runtime.json")
    allowed = {
        "hero.aurelien", "hero.effrie", "hero.lya", "hero.mathilde",
        "hero.marec", "hero.zeje", "hero.anouk",
    }
    reliabilities: set[str] = set()
    speakers: set[str] = set()
    for section in ["events", "cascades"]:
        for item in presentation[section].values():
            for rumor in item["rumors"]:
                reliabilities.add(rumor["reliability"])
            for line in item["dialogue"]:
                speakers.add(line["speaker_id"])
                assert line["speaker_id"] in allowed
                assert line["text"]
    assert {"confirmed", "direct", "reported", "variable", "unreliable"} <= reliabilities
    assert speakers <= allowed


def test_save_contract_keeps_existing_version_and_adds_systemic_state() -> None:
    save = (ROOT / "scripts/core/save_manager.gd").read_text(encoding="utf-8")
    assert 'SAVE_VERSION := "0.31"' in save
    assert '"systemic_cross": SystemicCrossRuntime.serialize()' in save
    assert 'SystemicCrossRuntime.deserialize(payload.get("systemic_cross",{}))' in save
    assert 'payload["systemic_cross"] = payload.get("systemic_cross",{})' in save


def test_existing_economy_consumes_cross_pressure_without_changing_reputation() -> None:
    politics = (ROOT / "scripts/core/political_state.gd").read_text(encoding="utf-8")
    runtime = (ROOT / "scripts/core/systemic_cross_runtime.gd").read_text(encoding="utf-8")
    assert "SystemicCrossRuntime.market_price_modifier()" in politics
    assert "func market_price_modifier()" in runtime
    assert "PoliticalState.reputation" not in runtime
    assert "route_states" in runtime
    assert "economy_tags" in runtime


def test_named_death_and_anti_replay_are_covered_by_godot_smoke() -> None:
    smoke = (ROOT / "scripts/core/systemic_cross_smoke_test.gd").read_text(encoding="utf-8")
    assert "Iria Sen" in smoke
    assert "cross.relationship.named_death_after_difficult_choice" in smoke
    assert "applied_event_ids().count" in smoke
    assert "deserialize(cross_snapshot)" in smoke
    assert "must never replay twice" in smoke
