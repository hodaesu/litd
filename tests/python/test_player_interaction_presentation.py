from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTROLLER = (ROOT / "scripts/world/exploration_party_controller.gd").read_text(encoding="utf-8")
HUD = (ROOT / "scripts/world/ashlands_hud.gd").read_text(encoding="utf-8")


def test_controller_publishes_contract_only_target_state_and_feedback():
    assert "signal interaction_target_changed(descriptor: Dictionary)" in CONTROLLER
    assert "signal interaction_feedback(result: Dictionary)" in CONTROLLER
    assert "func get_interaction_descriptor() -> Dictionary:" in CONTROLLER
    assert "EnvironmentInteractionContract.describe" in CONTROLLER
    assert "EnvironmentInteractionContract.perform" in CONTROLLER
    assert "interaction_target_changed.emit" in CONTROLLER
    assert "interaction_feedback.emit" in CONTROLLER


def test_controller_does_not_restore_specialized_interaction_routing():
    assert 'has_method("harvest")' not in CONTROLLER
    assert 'has_method("rest")' not in CONTROLLER
    assert 'has_method("interact")' not in CONTROLLER
    assert ".harvest()" not in CONTROLLER
    assert ".rest()" not in CONTROLLER


def test_hud_uses_progressive_contextual_presentation():
    assert 'name = "ContextualInteraction"' in HUD
    assert "_interaction_panel.visible = false" in HUD
    assert "_interaction_button.visible = false" in HUD
    assert "interaction_target_changed.connect" in HUD
    assert "interaction_feedback.connect" in HUD
    assert "func _interaction_prompt_text(descriptor: Dictionary) -> String:" in HUD
    assert "func _blocked_reason_text(reason: String) -> String:" in HUD
    assert "func _feedback_text(result: Dictionary) -> String:" in HUD
    assert "INDISPONIBLE" in HUD
    assert "Impossible pour l’instant." in HUD
    assert "wait_time = 2.0" in HUD


def test_hud_does_not_know_specialized_world_interactable_classes():
    forbidden = (
        "ShortcutGate",
        "ResourceNode",
        "LoreCollectible",
        "VeilleursVS001CorpseProxy",
        "VeilleursVS001InteractionProxy",
        "CampfireInteraction",
    )
    for name in forbidden:
        assert name not in HUD
