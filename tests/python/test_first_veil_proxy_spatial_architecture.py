import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "data" / "roguelike" / "first_veil_rooms.json"
PLAN = ROOT / "data" / "roguelike" / "first_veil_proxy_plan.json"
PLAN_RUNTIME = ROOT / "scripts" / "core" / "first_veil_proxy_plan_runtime.gd"
ROOM_RUNTIME = ROOT / "scripts" / "world" / "dungeon_proxy_room.gd"
UI = ROOT / "scripts" / "ui" / "main_v28.gd"


def _data(path):
    return json.loads(path.read_text(encoding="utf-8"))


def test_every_first_veil_room_has_an_exact_proxy_plan():
    catalog = _data(CATALOG)
    plan = _data(PLAN)
    room_ids = {room["id"] for room in catalog["rooms"]}
    planned = {room["id"] for room in plan["rooms"]}
    assert room_ids == planned
    assert len(planned) == 37
    for room in plan["rooms"]:
        width, length, height = room["dimensions"]
        assert width >= 8
        assert length >= 6
        assert height >= 4
        assert len(room["port_sides"]) == 4
        assert set(room["port_sides"]) == {"north", "east", "south", "west"}
        assert room["module"].startswith("FV_")
        assert 1 <= room["phase"] <= 4


def test_proxy_plan_defines_stable_blender_handoff_and_four_connector_families():
    plan = _data(PLAN)
    assert plan["design_contract"]["one_node_one_room"] is True
    assert plan["design_contract"]["physical_passages"] is True
    assert plan["design_contract"]["secrets_hidden_until_discovered"] is True
    assert plan["design_contract"]["stable_gameplay_anchors_for_blender_swap"] is True
    assert set(plan["connectors"]) == {
        "standard_corridor",
        "stairwell",
        "secret_passage",
        "boss_gate",
    }
    assert plan["geometry"]["palier_drop"] == 7.5
    assert len(plan["anchor_profile"]) >= 8


def test_production_order_covers_all_rooms_before_blender_polish():
    plan = _data(PLAN)
    catalog = _data(CATALOG)
    all_ids = {room["id"] for room in catalog["rooms"]}
    scheduled = set()
    for phase in plan["production_order"]:
        if phase["rooms"] == ["ALL"]:
            continue
        scheduled.update(phase["rooms"])
    assert scheduled == all_ids
    assert plan["production_order"][-1]["name"] == "Blender et polish"


def test_runtime_resolves_gameplay_anchors_ports_and_connector_types():
    runtime = PLAN_RUNTIME.read_text(encoding="utf-8")
    required = [
        "func resolved_room",
        "dimensions_m",
        "interaction_points",
        "standard_corridor",
        "stairwell",
        "secret_passage",
        "boss_gate",
        "blender_module_id",
    ]
    for token in required:
        assert token in runtime


def test_walkable_proxy_builds_collision_anchors_and_exit_areas():
    room_runtime = ROOM_RUNTIME.read_text(encoding="utf-8")
    assert "extends Node3D" in room_runtime
    assert "StaticBody3D" in room_runtime
    assert "CollisionShape3D" in room_runtime
    assert "GameplayAnchors" in room_runtime
    assert "InteractionAnchors" in room_runtime
    assert "Area3D" in room_runtime
    assert "exit_reached" in room_runtime
    assert "EXPLORER_SCENE" in room_runtime


def test_main_v28_exposes_walkable_proxy_without_revealing_secrets():
    scene = (ROOT / "scenes" / "Main.tscn").read_text(encoding="utf-8")
    ui = UI.read_text(encoding="utf-8")
    assert 'res://scripts/ui/main_v28.gd' in scene
    assert 'res://scripts/ui/main_v27.gd' in scene
    assert 'extends "res://scripts/ui/main_v27.gd"' in ui
    assert "VISITER LA SALLE EN PROXY 3D" in ui
    assert "player_connections(runtime, room_id)" in ui
    assert "show_dungeon_proxy" in ui
    assert "exit_reached" in ui
