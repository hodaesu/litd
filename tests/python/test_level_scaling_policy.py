import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _section(text: str, function_name: str) -> str:
    marker = f"func {function_name}("
    start = text.index(marker)
    next_func = text.find("\nfunc ", start + len(marker))
    return text[start:] if next_func == -1 else text[start:next_func]


def test_campaign_and_dungeon_level_policies_are_separate() -> None:
    policy = (ROOT / "scripts/core/level_scaling_policy.gd").read_text(encoding="utf-8")
    bridge = (ROOT / "scripts/world/ashlands_combat_bridge.gd").read_text(encoding="utf-8")

    campaign = _section(policy, "apply_campaign_scaling")
    dungeon_level = _section(policy, "dungeon_enemy_level")
    dungeon_scaling = _section(policy, "apply_dungeon_scaling")

    assert "campaign_target_level" in campaign
    assert 'enemy["level"] = target_level' in campaign
    assert "CampaignState.current_chapter_number()" in bridge
    assert "apply_campaign_scaling" in bridge

    # Le niveau d'un donjon dépend uniquement du profil et de la profondeur.
    assert "party_level_context" not in dungeon_level
    assert "campaign_target_level" not in dungeon_level
    assert "GameState.party" not in dungeon_level
    assert 'enemy["dungeon_fixed_level"] = true' in dungeon_scaling


def test_dungeon_has_an_explicit_required_level_and_fixed_enemy_curve() -> None:
    rules = json.loads((ROOT / "data/roguelike/roguelike_rules.json").read_text(encoding="utf-8"))
    dungeon_id = rules["default_dungeon_id"]
    profile = rules["dungeons"][dungeon_id]

    assert profile["required_level"] == 3
    assert profile["enemy_base_level"] == 4
    assert profile["enemy_level_per_depth"] == 2
    assert profile["scaling_rule"] == "fixed_by_dungeon_and_depth_never_by_hero_level"
    assert rules["principles"]["campaign_scales_to_party"] is True
    assert rules["principles"]["dungeons_never_scale_to_party"] is True
    assert rules["principles"]["dungeons_have_required_levels"] is True


def test_visible_ui_enforces_and_displays_the_dungeon_requirement() -> None:
    scene = (ROOT / "scenes/Main.tscn").read_text(encoding="utf-8")
    ui = (ROOT / "scripts/ui/main_v25.gd").read_text(encoding="utf-8")

    assert 'res://scripts/ui/main_v25.gd' in scene
    assert "NIVEAU REQUIS" in ui
    assert "dungeon_entry_check" in ui
    assert 'button.disabled = not bool(gate.get("allowed", false))' in ui
    assert "apply_dungeon_scaling" in ui
    assert "dungeon_enemy_level" in ui
