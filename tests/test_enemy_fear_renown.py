import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = json.loads((ROOT / "data" / "enemy_fear_renown.json").read_text(encoding="utf-8"))

def test_enemy_fear_scale_and_thresholds():
    assert DATA["scale"] == {"min": 0, "max": 100}
    values = list(DATA["thresholds"].values())
    assert values == sorted(values)
    assert DATA["thresholds"]["panic"] == 100

def test_survival_and_deeds_build_reputation():
    weights = DATA["renown_weights"]
    assert weights["dungeon_survived"] > weights["enemy_defeated"]
    assert weights["boss_defeated"] > weights["dungeon_survived"]
    assert weights["perfect_dungeon"] > 0
    assert weights["ultimate_used"] > 0

def test_fear_changes_combat_without_scaling_dungeons():
    assert DATA["rules"]["dungeon_difficulty_never_scales_from_renown"] is True
    assert DATA["rules"]["reputation_cannot_change_enemy_base_stats"] is True
    assert DATA["rules"]["only_witnessed_deeds_change_combat_fear"] is True
    panic = DATA["gameplay"]["panic"]
    assert panic["damage_multiplier"] < 1
    assert panic["retreat_bias"] > DATA["gameplay"]["wary"]["retreat_bias"]

def test_bosses_resist_but_are_not_immune():
    multiplier = DATA["courage"]["boss_multiplier"]
    assert 0 < multiplier < 1
    assert DATA["rules"]["bosses_resist_but_are_not_immune"] is True
