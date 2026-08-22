import json
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "data/movement_registry.json"

def load():
    return json.loads(REGISTRY.read_text(encoding="utf-8"))

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
    for hero in heroes:
        movements = [x for x in data["entries"] if x["category"] == "hero_skill" and x["owner"] == hero["id"]]
        assert len(movements) == 45
        for branch in ["offense","defense","special"]:
            branch_entries = [x for x in movements if f"_{branch}_" in x["id"]]
            assert len(branch_entries) == 15
            assert any("ultimate_signature" in x["variants"] for x in branch_entries)

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
