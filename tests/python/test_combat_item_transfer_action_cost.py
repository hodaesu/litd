import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_item_use_costs_action_but_transfer_is_free_for_both_sides():
    rules = json.loads((ROOT / "data/levels/ashlands_survival_rules.json").read_text(encoding="utf-8"))
    transfer = rules["combat_item_transfer"]
    assert rules["version"] >= 4
    assert transfer["personal_carriers"] is True
    assert transfer["using_item_on_ally_costs_action"] is True
    assert transfer["giving_item_to_ally_costs_action"] is False
    assert transfer["transfer_applies_item_effect"] is False
    assert transfer["heroes_and_enemies_share_rule"] is True


def test_v34_item_rules_survive_the_current_main_ui_layer():
    ui = (ROOT / "scripts/ui/main_v34.gd").read_text(encoding="utf-8")
    clinical_manual = (ROOT / "scripts/ui/main_v35.gd").read_text(encoding="utf-8")
    clinical_reactions = (ROOT / "scripts/ui/main_v36.gd").read_text(encoding="utf-8")
    scene = (ROOT / "scenes/Main.tscn").read_text(encoding="utf-8")

    for marker in (
        "COMBAT_INVENTORY_RULES",
        "UTILISER = ACTION · DONNER = GRATUIT",
        "_use_carried_item_on_target",
        "_give_carried_item_to_hero",
        "sans consommer son action",
        "_enemy_try_use_healing_item",
        "_enemy_try_free_item_transfer",
        "Son action est consommée",
        "sans perdre son action",
    ):
        assert marker in ui

    give_start = ui.index("func _give_carried_item_to_hero")
    give_end = ui.index("func _living_hero_by_id", give_start)
    give_body = ui[give_start:give_end]
    assert "_complete_active_hero_turn()" not in give_body
    assert "battle_locked = true" not in give_body

    use_start = ui.index("func _use_carried_item_on_target")
    use_end = ui.index("func _give_carried_item_to_hero", use_start)
    use_body = ui[use_start:use_end]
    assert "battle_locked = true" in use_body
    assert "_complete_active_hero_turn()" in use_body

    # The active UI adds thin specialized layers, but the chain must still reach
    # v34 so the established use-vs-give action-cost contract remains authoritative.
    assert 'res://scripts/ui/main_v36.gd' in scene
    assert 'extends "res://scripts/ui/main_v35.gd"' in clinical_reactions
    assert 'extends "res://scripts/ui/main_v34.gd"' in clinical_manual
    assert "_enemy_try_use_healing_item" in clinical_reactions
    assert "_enemy_try_free_item_transfer" in clinical_reactions


def test_transfer_changes_carrier_without_applying_item_effect():
    core = (ROOT / "scripts/core/combat_inventory_rules.gd").read_text(encoding="utf-8")
    transfer_start = core.index("static func transfer")
    transfer_end = core.index("static func reconcile_party_aggregate", transfer_start)
    transfer_body = core[transfer_start:transfer_end]
    assert "consume(giver" in transfer_body
    assert "add(receiver" in transfer_body
    assert "hp" not in transfer_body
    assert "heal" not in transfer_body.lower()
