import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "data" / "roguelike" / "first_veil_rooms.json"
RUNTIME = ROOT / "scripts" / "core" / "first_veil_dungeon_runtime.gd"
UI = ROOT / "scripts" / "ui" / "main_v27.gd"


def test_main_scene_activates_physical_dungeon_layer():
    scene = (ROOT / "scenes" / "Main.tscn").read_text(encoding="utf-8")
    assert 'res://scripts/ui/main_v27.gd' in scene
    assert 'res://scripts/ui/main_v26.gd' in scene
    assert 'res://scripts/ui/main_v24.gd' in scene


def test_first_veil_is_four_palier_vertical_descent_with_real_rooms():
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    assert data["dungeon_id"] == "first_veil_crypts"
    assert data["orientation"] == "vertical_descending"
    assert data["palier_count"] == 4
    assert data["design_rules"]["one_node_one_explorable_space"] is True
    assert data["design_rules"]["one_connection_one_physical_passage"] is True
    assert len(data["rooms"]) >= 30
    assert {room.get("palier", 0) for room in data["rooms"] if room.get("palier", 0) > 0} == {1, 2, 3, 4}
    assert any(room.get("room_role") == "entry" for room in data["rooms"])
    assert any(room.get("room_role") == "boss" for room in data["rooms"])
    for room in data["rooms"]:
        assert room["id"]
        assert room["name"]
        assert room["connections"]
        assert room["space_kind"]
        assert room["description"]
        assert room["interactions"]
        assert room["variant_pool"]


def test_secret_rooms_are_real_but_not_revealed_before_discovery():
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    secrets = [room for room in data["rooms"] if room.get("secret")]
    assert len(secrets) >= 4
    runtime = RUNTIME.read_text(encoding="utf-8")
    assert 'room["discovered"] = not bool(room.get("secret", false))' in runtime
    assert 'if not bool(room.get("secret", false))' in runtime
    assert 'return bool(room.get("discovered", false))' in runtime
    assert 'target["discovered"] = true' in runtime
    assert 'secret_searches' in runtime


def test_macro_map_uses_fog_of_war_and_room_screen():
    ui = UI.read_text(encoding="utf-8")
    assert 'func show_dungeon_room()' in ui
    assert 'CARTE MACRO' in ui
    assert '1 NŒUD = 1 SALLE VISITABLE' in ui
    assert 'SALLE INCONNUE' in ui
    assert 'FOUILLER MURS ET PASSAGES' in ui
    assert 'Les salles secrètes sont totalement absentes jusqu\'à leur découverte.' in ui
    assert 'ISSUES ET PASSAGES' in ui
    assert 'ENGAGER LE COMBAT DANS CETTE SALLE' in ui
    assert 'RETOURNER DANS LA SALLE' in ui


def test_physical_state_is_serialized_inside_existing_run_state():
    runtime = RUNTIME.read_text(encoding="utf-8")
    roguelike = (ROOT / "scripts" / "core" / "roguelike_runtime.gd").read_text(encoding="utf-8")
    assert 'active["physical_dungeon_version"]' in runtime
    assert 'active["room_transition_history"]' in runtime
    assert 'active["discovered_secrets"]' in runtime
    assert '"active_run": active_run' in roguelike
