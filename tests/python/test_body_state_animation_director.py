import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def test_contract_covers_layered_body_states():
    data = json.loads((ROOT / "data/body_state_animation_contract.json").read_text(encoding="utf-8"))
    assert data["version"] == 1
    for state in ["tense","terrified","panic","fractured","anger","despair","hope"]:
        assert state in data["psychological_states"]
    for state in ["healthy","injured","critical","mobility_impaired","dead"]:
        assert state in data["physical_states"]
    for relation in ["protect","reassure","avoid","threaten"]:
        assert relation in data["relation_layers"]

def test_combat_contract_has_actions_and_authoritative_markers():
    data = json.loads((ROOT / "data/body_state_animation_contract.json").read_text(encoding="utf-8"))
    for action in ["attack_light","attack_heavy","guard","dodge","riposte","rank_move","push","pull","use_item","transfer_item","heal_ally","capture","friendly_fire"]:
        assert action in data["combat_actions"]
        assert data["combat_actions"][action]["required_markers"]
    assert data["authority"]["gameplay_timing"] == "Godot"

def test_runtime_combines_psychology_injury_personality_and_relation():
    runtime = (ROOT / "scripts/core/body_state_director.gd").read_text(encoding="utf-8")
    for token in ["_psychological_state","_physical_state","character_signature","relation_intent","combat_action_plan","hit_reaction","gameplay_timing_scale"]:
        assert token in runtime
    assert "mobility_injury" in runtime
    assert "dismembered_parts" in runtime

def test_blender_handoff_has_no_gameplay_authority():
    data = json.loads((ROOT / "data/body_state_animation_contract.json").read_text(encoding="utf-8"))
    assert data["authority"]["visual_motion"] == "AnimationTree/Blender clips"
    assert data["blender_delivery"]["requirements"]
    handoff = (ROOT / "docs/production/BODY_STATE_ANIMATION_HANDOFF.md").read_text(encoding="utf-8")
    assert "Le gameplay reste autoritaire dans Godot" in handoff
