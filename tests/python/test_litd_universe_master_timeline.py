from __future__ import annotations

import json
import shutil
from pathlib import Path

from tools.qa.lore_universe_audit import audit
from tools.qa.timeline_expansion_audit import audit_timeline_expansion


ROOT = Path(__file__).resolve().parents[2]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_master_timeline_uses_fall_as_year_zero() -> None:
    timeline = load_json(ROOT / "universe/lore/timeline_master.json")
    assert timeline["schema_version"] >= 2
    assert timeline["time_origin"] == {
        "anchor": "event.fall",
        "label": "La Chute",
        "relative_year": 0,
    }
    events = {event["id"]: event for event in timeline["events"]}
    assert events["history.fall"]["relative_year"] == 0
    assert events["history.ashai.first_rupture"]["relative_year"] == -3700
    assert events["history.or_silex.inheritance"]["relative_year"] == -3260
    assert events["history.or_silex.great_closure"]["relative_year"] == -2290
    assert events["history.concord.birth"]["relative_year"] == -1000


def test_ancient_civilization_ranges_follow_priority_dossiers() -> None:
    timeline = load_json(ROOT / "universe/lore/timeline_master.json")
    civilizations = {item["id"]: item for item in timeline["civilizations"]}
    expected = {
        "civilization.ashai_nhal": (-4450, -3520),
        "civilization.or_silex": (-3260, -2470),
        "civilization.watchers_saan": (-2910, -1980),
        "civilization.vaor_khal": (-2870, -2010),
        "civilization.lyr_mar": (-2680, -1760),
        "civilization.sahm_ir": (-2440, -1510),
        "civilization.ydris": (-2190, -1280),
    }
    assert set(civilizations) == set(expected)
    for civ_id, period in expected.items():
        assert (civilizations[civ_id]["start_year"], civilizations[civ_id]["end_year"]) == period
        assert civilizations[civ_id]["certainty"] == "approximate"


def test_game_order_and_veilleurs_protagonists_are_not_invented() -> None:
    canon = load_json(ROOT / "universe/lore/canon_registry.json")
    facts = {fact["id"]: fact for fact in canon["facts"]}
    assert facts["universe.timeline.game_order"]["value"] == ["litd2", "litd_veilleurs", "litd1"]
    assert facts["veilleurs.protagonists.count"]["value"] == 4
    assert facts["veilleurs.protagonists.identities"]["value"] == "unconfirmed"

    timeline = load_json(ROOT / "universe/lore/timeline_master.json")
    events = {event["id"]: event for event in timeline["events"]}
    assert events["veilleurs.campaign"]["characters"] == []


def test_legendary_seven_only_locks_confirmed_positions() -> None:
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
    assert facts["legendary_seven.members"]["value"] == expected_members
    assert facts["legendary_seven.predestined"]["value"] is False
    assert facts["legendary_seven.known_formation_positions"]["value"] == {
        "2": "hero.anouk",
        "5": "hero.effrie",
    }
    assert facts["legendary_seven.complete_formation_order"]["value"] == "unconfirmed"
    assert "legendary_seven.formation_order" not in facts

    timeline = load_json(ROOT / "universe/lore/timeline_master.json")
    events = {event["id"]: event for event in timeline["events"]}
    formation = events["litd1.seven.formation"]
    assert formation["known_formation_positions"] == {"2": "hero.anouk", "5": "hero.effrie"}
    assert formation["complete_formation_order"] == "unconfirmed"
    assert "formation_order" not in formation


def test_trame_dragons_and_remanence_keep_unknown_origins_open() -> None:
    timeline = load_json(ROOT / "universe/lore/timeline_master.json")
    characters = {item["id"]: item for item in timeline["characters"]}
    threads = {item["id"]: item for item in timeline["knowledge_threads"]}

    assert characters["hero.anouk"]["formation_position"] == 2
    assert characters["hero.anouk"]["signature_magic"] == "La Trame"
    assert characters["hero.effrie"]["formation_position"] == 5
    assert "dragon" in characters["hero.effrie"]["dragon_link"]

    assert threads["thread.anouk_trame"]["origin_period"] == "unknown"
    assert threads["thread.anouk_trame"]["certainty"] == "unknown"
    assert threads["thread.effrie_dragon_heritage"]["origin_period"] == "before_litd1_formation_undated"
    assert threads["thread.litd2_remanence_vestige"]["origin_civilization"] is None


def test_sanctuaries_are_distinguished_from_ancient_saan_anchor() -> None:
    timeline = load_json(ROOT / "universe/lore/timeline_master.json")
    institutions = {item["id"]: item for item in timeline["institutions"]}
    sites = {item["id"]: item for item in timeline["sites"]}

    assert institutions["institution.first_sanctuaries"]["start_after"] == "event.night_of_sarn"
    assert institutions["institution.mature_three_awakenings_sanctuaries"]["timeline_anchor"] == "era.mature_concord"
    assert sites["site.first_veil_tree_anchor"]["origin_civilization"] == "civilization.watchers_saan"
    assert sites["site.first_veil_tree_anchor"]["latest_origin_year"] == -1980


def test_current_universe_lore_audits_pass() -> None:
    report = audit(ROOT)
    assert report["ok"], report
    expansion = audit_timeline_expansion(ROOT)
    assert expansion["ok"], expansion


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


def test_expansion_audit_rejects_invented_complete_seven_order(tmp_path: Path) -> None:
    shutil.copytree(ROOT / "universe", tmp_path / "universe")
    shutil.copytree(ROOT / "docs", tmp_path / "docs")
    shutil.copytree(ROOT / "data", tmp_path / "data")

    timeline_path = tmp_path / "universe/lore/timeline_master.json"
    timeline = load_json(timeline_path)
    for event in timeline["events"]:
        if event["id"] == "litd1.seven.formation":
            event["formation_order"] = [
                "hero.zeje", "hero.anouk", "hero.mathilde", "hero.marec",
                "hero.effrie", "hero.aurelien", "hero.lya",
            ]
            event["complete_formation_order"] = event["formation_order"]
            break
    timeline_path.write_text(json.dumps(timeline, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    report = audit_timeline_expansion(tmp_path)
    assert not report["ok"]
    assert any("ordre complet" in error.lower() for error in report["errors"]), report
