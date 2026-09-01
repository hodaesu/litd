from __future__ import annotations

import json
import shutil
from pathlib import Path

from tools.qa.lore_universe_audit import audit


ROOT = Path(__file__).resolve().parents[2]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_master_timeline_uses_fall_as_year_zero() -> None:
    timeline = load_json(ROOT / "universe/lore/timeline_master.json")
    assert timeline["time_origin"] == {
        "anchor": "event.fall",
        "label": "La Chute",
        "relative_year": 0,
    }
    events = {event["id"]: event for event in timeline["events"]}
    assert events["history.fall"]["relative_year"] == 0
    assert events["history.ashai.first_rupture"]["relative_year"] == -3700
    assert events["history.concord.birth"]["relative_year"] == -1000


def test_game_order_and_veilleurs_protagonists_are_not_invented() -> None:
    canon = load_json(ROOT / "universe/lore/canon_registry.json")
    facts = {fact["id"]: fact for fact in canon["facts"]}
    assert facts["universe.timeline.game_order"]["value"] == ["litd2", "litd_veilleurs", "litd1"]
    assert facts["veilleurs.protagonists.count"]["value"] == 4
    assert facts["veilleurs.protagonists.identities"]["value"] == "unconfirmed"

    timeline = load_json(ROOT / "universe/lore/timeline_master.json")
    events = {event["id"]: event for event in timeline["events"]}
    assert events["veilleurs.campaign"]["characters"] == []


def test_legendary_seven_composition_and_formation_order() -> None:
    canon = load_json(ROOT / "universe/lore/canon_registry.json")
    facts = {fact["id"]: fact for fact in canon["facts"]}
    expected_members = [
        "hero.aurelien",
        "hero.effrie",
        "hero.lya",
        "hero.mathilde",
        "hero.marec",
        "hero.zeje",
        "hero.anouk",
    ]
    expected_order = [
        "hero.zeje",
        "hero.mathilde",
        "hero.marec",
        "hero.aurelien",
        "hero.lya",
        "hero.effrie",
        "hero.anouk",
    ]
    assert facts["legendary_seven.members"]["value"] == expected_members
    assert facts["legendary_seven.predestined"]["value"] is False
    assert facts["legendary_seven.formation_order"]["value"] == expected_order


def test_current_universe_lore_audit_passes() -> None:
    report = audit(ROOT)
    assert report["ok"], report


def test_audit_rejects_aurelien_in_early_concord_veilleurs(tmp_path: Path) -> None:
    shutil.copytree(ROOT / "universe", tmp_path / "universe")
    shutil.copytree(ROOT / "docs", tmp_path / "docs")
    shutil.copytree(ROOT / "data", tmp_path / "data")

    timeline_path = tmp_path / "universe/lore/timeline_master.json"
    timeline = load_json(timeline_path)
    for event in timeline["events"]:
        if event["id"] == "veilleurs.campaign":
            event["characters"] = ["hero.aurelien"]
            break
    timeline_path.write_text(json.dumps(timeline, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    report = audit(tmp_path)
    assert not report["ok"]
    assert any(
        "hero.aurelien" in error and "avant sa première ancre autorisée" in error
        for error in report["errors"]
    ), report
