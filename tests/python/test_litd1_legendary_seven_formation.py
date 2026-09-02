from __future__ import annotations

import json
import shutil
from pathlib import Path

from tools.qa.legendary_seven_formation_audit import audit_legendary_seven_formation

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ORDER = [
    "hero.zeje", "hero.anouk", "hero.marec", "hero.mathilde",
    "hero.effrie", "hero.aurelien", "hero.lya",
]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_formation_order_and_six_recruitments() -> None:
    data = load_json(ROOT / "universe/lore/legendary_seven_formation.json")
    assert data["formation_order"] == EXPECTED_ORDER
    assert [r["rank"] for r in data["recruitments"]] == [2, 3, 4, 5, 6, 7]
    assert [r["joining_hero"] for r in data["recruitments"]] == EXPECTED_ORDER[1:]


def test_all_six_recruitments_have_tradeoffs_body_camp_and_remanence() -> None:
    data = load_json(ROOT / "universe/lore/legendary_seven_formation.json")
    for rec in data["recruitments"]:
        assert len(rec["choices"]) >= 2
        assert all(choice["costs"] for choice in rec["choices"])
        assert set(rec["body_system"]) >= {
            "event", "mechanical_change", "subjective_experience",
            "social_reaction", "persistent_consequence",
        }
        assert rec["first_camp"]["task"]
        assert len(rec["first_camp"]["lines"]) <= 2
        assert rec["future_break_seed"]
        assert all(rec["remanence"][key] for key in ["source", "transmission", "transformation"])


def test_formation_plants_exactly_the_twenty_one_canonical_pairs() -> None:
    data = load_json(ROOT / "universe/lore/legendary_seven_formation.json")
    relations = load_json(ROOT / "universe/lore/legendary_seven_relationships.json")
    seeds = [seed["pair_id"] for rec in data["recruitments"] for seed in rec["relationship_seeds"]]
    canonical = [pair["id"] for pair in relations["pairs"]]
    assert len(seeds) == 21
    assert len(set(seeds)) == 21
    assert set(seeds) == set(canonical)


def test_anouk_marec_effrie_locked_ranks_are_preserved() -> None:
    data = load_json(ROOT / "universe/lore/legendary_seven_formation.json")
    assert data["formation_order"][1] == "hero.anouk"
    assert data["formation_order"][2] == "hero.marec"
    assert data["formation_order"][4] == "hero.effrie"


def test_formation_is_historical_not_prophetic_or_moral_score() -> None:
    data = load_json(ROOT / "universe/lore/legendary_seven_formation.json")
    rules = data["rules"]
    assert rules["formation_is_not_prophecy"] is True
    assert rules["legendary_status_is_acquired_later"] is True
    assert rules["no_hidden_good_choice"] is True
    assert rules["no_new_relationship_meter"] is True
    assert rules["backward_causation"] is False


def test_current_formation_audit_passes() -> None:
    report = audit_legendary_seven_formation(ROOT)
    assert report["ok"], report
    assert report["summary"]["recruitments"] == 6
    assert report["summary"]["first_camps"] == 6
    assert report["summary"]["relationship_seeds"] == 21


def test_audit_rejects_anouk_moved_from_rank_two(tmp_path: Path) -> None:
    shutil.copytree(ROOT / "universe", tmp_path / "universe")
    shutil.copytree(ROOT / "docs", tmp_path / "docs")
    path = tmp_path / "universe/lore/legendary_seven_formation.json"
    data = load_json(path)
    data["formation_order"][1], data["formation_order"][2] = data["formation_order"][2], data["formation_order"][1]
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report = audit_legendary_seven_formation(tmp_path)
    assert not report["ok"]
    assert any("Ordre des Sept" in error for error in report["errors"])


def test_audit_rejects_missing_first_relationship_seed(tmp_path: Path) -> None:
    shutil.copytree(ROOT / "universe", tmp_path / "universe")
    shutil.copytree(ROOT / "docs", tmp_path / "docs")
    path = tmp_path / "universe/lore/legendary_seven_formation.json"
    data = load_json(path)
    data["recruitments"][-1]["relationship_seeds"].pop()
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report = audit_legendary_seven_formation(tmp_path)
    assert not report["ok"]
    assert any("premiers liens" in error or "21 graines" in error for error in report["errors"])
