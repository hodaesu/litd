from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_guild_stash_is_saved_and_preserves_item_instances():
    manager = (ROOT / "scripts/core/equipment_manager.gd").read_text()
    assert "var guild_stash: Array[Dictionary]" in manager
    assert '"guild_stash": guild_stash' in manager
    assert "store_in_guild_stash" in manager
    assert "withdraw_from_guild_stash" in manager
    assert "instance_id" in manager


def test_equipped_items_cannot_be_stored():
    manager = (ROOT / "scripts/core/equipment_manager.gd").read_text()
    assert "equipped_by_hero.values()" in manager
    assert "slots.values().has(instance_id)" in manager


def test_guild_chest_is_accessible_from_company():
    ui = (ROOT / "scripts/ui/main.gd").read_text()
    assert '"guild_chest": show_guild_chest()' in ui
    assert "COFFRE COMMUN" in ui
    assert "DÉPOSER" in ui and "RETIRER" in ui
