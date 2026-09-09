import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FORMATION = (ROOT / "scripts" / "ui" / "main_v47.gd").read_text(encoding="utf-8")
POSITION_RULES = (ROOT / "scripts" / "core" / "combat_position_rules.gd").read_text(encoding="utf-8")
ROSTER = json.loads((ROOT / "data" / "veilleurs" / "canonical_roster.json").read_text(encoding="utf-8"))


def test_canonical_quartet_roles_match_front_and_back_contract():
    heroes = {hero["id"]: hero for hero in ROSTER["heroes"]}
    assert heroes["mathilde"]["class_id"] == "duelist"
    assert heroes["marec"]["class_id"] == "breaker"
    assert heroes["anouk"]["class_id"] == "mystic"
    assert heroes["aurelien"]["class_id"] == "surgeon"
    assert '"breaker", "watcher", "inquisitor", "duelist"' in POSITION_RULES
    assert '"vestal", "mystic", "ranger", "surgeon", "scout", "occultist"' in POSITION_RULES


def test_initial_formation_scores_canonical_front_and_back_classes():
    assert '"duelist", "breaker"' in FORMATION
    assert '"mystic", "surgeon"' in FORMATION


def test_equal_role_scores_are_stable_by_canonical_roster_order():
    assert 'left.get("starting_quartet_order", 999)' in FORMATION
    assert 'right.get("starting_quartet_order", 999)' in FORMATION


def test_visual_rank_order_keeps_r1_at_enemy_contact():
    assert "var visual_order := [4, 3, 2, 1]" in FORMATION
    assert "R4   R3   R2   R1" in FORMATION
