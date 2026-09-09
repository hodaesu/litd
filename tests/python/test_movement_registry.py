import json
import subprocess
import sys
from collections import Counter
from pathlib import Path

from tools.animation.movement_registry import load as load_registry

ROOT = Path(__file__).resolve().parents[2]
CURRENT_HEROES = {"mathilde", "marec", "anouk", "aurelien"}
LEGACY_STARTER_IDS = {"malvor", "lysandra", "darius"}


def load():
    return load_registry()


def test_registry_is_large_unique_and_structured():
    data = load()
    entries = data["entries"]
    assert len(entries) >= 600
    ids = [x["id"] for x in entries]
    assert len(ids) == len(set(ids))
    required = {"id","category","owner","trigger","motion_family","markers","variants","rig","status","gameplay_authority","root_motion","notes"}
    assert all(required <= set(x) for x in entries)
    assert all(x["gameplay_authority"] == "Godot" for x in entries)


def test_every_current_hero_has_45_skill_movements_and_three_branches():
    data = load()
    heroes = json.loads((ROOT / "data/heroes.json").read_text(encoding="utf-8"))
    assert {hero["id"] for hero in heroes} == CURRENT_HEROES
    for hero in heroes:
        movements = [x for x in data["entries"] if x["category"] == "hero_skill" and x["owner"] == hero["id"]]
        assert len(movements) == 45
        for branch in ["offense","defense","special"]:
            branch_entries = [x for x in movements if f"_{branch}_" in x["id"]]
            assert len(branch_entries) == 15
            ultimates = [x for x in branch_entries if "ultimate_signature" in x["variants"]]
            assert len(ultimates) == 1
            assert ultimates[0]["ultimate_uses_by_level"] == {"16": 1, "32": 2, "48": 3}


def test_legacy_starter_ids_are_not_exposed_by_active_registry():
    hero_entries = [x for x in load()["entries"] if x["category"] == "hero_skill"]
    owners = {x["owner"] for x in hero_entries}
    assert owners == CURRENT_HEROES
    assert owners.isdisjoint(LEGACY_STARTER_IDS)
    assert all(not any(old in x["id"] for old in LEGACY_STARTER_IDS) for x in hero_entries)
    assert all(not any(old in x["trigger"] for old in LEGACY_STARTER_IDS) for x in hero_entries)


def test_registry_covers_requested_situations():
    categories = Counter(x["category"] for x in load()["entries"])
    for category in ["locomotion","combat","reaction","posture","equipment","interaction","traversal","hazard","camp","social","combat_end","enemy","boss"]:
        assert categories[category] > 0
    ids = {x["id"] for x in load()["entries"]}
    for movement in ["global.climb","global.crawl_narrow","global.camp_sleep","global.ally_death_react","global.ally_mutilation_react"]:
        assert movement in ids


def test_cli_audit_passes():
    result = subprocess.run([sys.executable, str(ROOT / "tools/animation/movement_registry.py"), "audit"], cwd=ROOT, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "MOVEMENT_REGISTRY_OK" in result.stdout
