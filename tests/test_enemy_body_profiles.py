import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "animation" / "enemy_body_profiles.py"
SPEC = importlib.util.spec_from_file_location("enemy_body_profiles", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)

def test_every_enemy_has_a_unique_body_signature():
    data, enemies = MODULE.load()
    assert MODULE.audit(data, enemies) == []
    assert len(data["profiles"]) == 39
    assert len({x["signature_key"] for x in data["profiles"]}) == 39

def test_posture_diversity_is_structural_not_random_noise():
    data, _ = MODULE.load()
    assert len(data["archetypes"]) >= 10
    assert len(data["temperaments"]) >= 8
    assert len({x["tactical_role"] for x in data["profiles"]}) >= 15
    assert data["rules"]["no_random_per_frame"] is True
    assert data["rules"]["deterministic_phase_offset"] is True

def test_capture_and_boss_identity_rules():
    data, _ = MODULE.load()
    bosses = [x for x in data["profiles"] if x["boss"]]
    assert bosses
    assert all(not x["capture_compatible"] for x in bosses)
    assert all(x["capture_compatible"] for x in data["profiles"] if not x["boss"])
    assert data["rules"]["captured_enemy_keeps_signature"] is True
