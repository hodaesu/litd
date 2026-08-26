from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def test_first_map_exposes_an_optional_ancient_dungeon() -> None:
    manifest = load("data/levels/terre_des_cendres_blockout_manifest.json")
    first = next(z for z in manifest["zones"] if z["id"] == "zone_01_faubourg_cendreux")
    entrance = next(e for e in first["exits"] if e["to"] == "zone_16_salles_du_premier_accord")
    assert entrance["dungeon"] is True
    assert entrance["optional"] is True
    dungeon_zone = next(z for z in manifest["zones"] if z["id"] == entrance["to"])
    assert dungeon_zone["ancient_civilization"] is True
    assert dungeon_zone["depths"] == 3


def test_dungeon_teaches_danger_and_retreat_without_blocking_campaign() -> None:
    dungeon = load("data/dungeons/first_map_hall_of_first_accord.json")
    assert dungeon["required_for_campaign"] is False
    assert len(dungeon["floors"]) == 3
    assert all(floor["retreat_exit"] for floor in dungeon["floors"])
    assert dungeon["rules"]["death_and_injuries_persist"] is True
    assert dungeon["rules"]["difficulty_mode_selection"] is False
    assert dungeon["rules"]["hud_in_exploration"] == "hidden"
    assert dungeon["miniboss"]["capturable"] is False


def test_chapter_registers_dungeon_as_optional_content() -> None:
    chapter = load("data/levels/chapter_01_vertical_slice.json")
    assert chapter["optional_dungeon"]["required"] is False
    stage_zones = {stage["zone"] for stage in chapter["stages"]}
    assert "zone_16_salles_du_premier_accord" not in stage_zones


def test_dungeon_scene_and_router_are_registered() -> None:
    scene = ROOT / "scenes/world/terre_des_cendres/zone_16_salles_du_premier_accord.tscn"
    assert scene.exists()
    router = (ROOT / "scripts/world/ashlands_scene_router.gd").read_text(encoding="utf-8")
    assert '"zone_16_salles_du_premier_accord"' in router

def test_dangerous_entry_requires_a_second_confirmation() -> None:
    gate = (ROOT / "scripts/world/zone_transition_gate.gd").read_text(encoding="utf-8")
    builder = (ROOT / "scripts/world/ashlands_blockout_builder.gd").read_text(encoding="utf-8")
    assert "dangerous_dungeon_confirmation_requested" in gate
    assert '"dangerous_dungeon_confirmation"' in gate
    assert "_danger_confirmation_until" in gate
    assert "gate.dangerous_entry = gate.dungeon and gate.optional_content" in builder
    assert "Vos blessures et pertes persisteront" in builder


def test_authored_dungeon_map_has_three_connected_depths() -> None:
    dungeon = load("data/dungeons/first_map_hall_of_first_accord.json")
    authored = load("data/dungeons/first_map_hall_of_first_accord_map.json")
    assert dungeon["authored_map"]["path"].endswith("first_map_hall_of_first_accord_map.json")
    assert len(authored["floors"]) == 3
    rooms = {
        room["id"]
        for floor in authored["floors"]
        for room in floor["rooms"]
    }
    assert len(rooms) == 9
    assert {"vestibule", "sealed_archive", "warden_sanctum"} <= rooms
    connections = authored["connections"]
    assert len(connections) == 12
    assert all(connection["from"] in rooms and connection["to"] in rooms for connection in connections)
    assert all(len(connection["waypoints"]) >= 3 for connection in connections)


def test_every_room_is_reachable_from_the_entrance() -> None:
    authored = load("data/dungeons/first_map_hall_of_first_accord_map.json")
    rooms = {
        room["id"]
        for floor in authored["floors"]
        for room in floor["rooms"]
    }
    adjacency = {room: set() for room in rooms}
    for connection in authored["connections"]:
        adjacency[connection["from"]].add(connection["to"])
        adjacency[connection["to"]].add(connection["from"])
    reached = {"vestibule"}
    pending = ["vestibule"]
    while pending:
        current = pending.pop()
        for neighbor in adjacency[current] - reached:
            reached.add(neighbor)
            pending.append(neighbor)
    assert reached == rooms


def test_authored_map_preserves_exploration_rules() -> None:
    authored = load("data/dungeons/first_map_hall_of_first_accord_map.json")
    assert authored["design_rules"]["critical_path_readable_without_hud"] is True
    assert authored["design_rules"]["ash_guidance"] == "only_on_request"
    assert authored["ash_routes"]["never_points_through_walls"] is True
    assert authored["ash_routes"]["uses_connection_waypoints"] is True
    assert len(authored["retreat_points"]) == 3
    assert {point["floor"] for point in authored["retreat_points"]} == {
        "threshold",
        "civic_depths",
        "accord_heart",
    }


def test_authored_map_builder_replaces_generic_dungeon_layout() -> None:
    builder = (ROOT / "scripts/world/ashlands_blockout_builder.gd").read_text(encoding="utf-8")
    dungeon_builder = (ROOT / "scripts/world/first_accord_dungeon_map_builder.gd").read_text(encoding="utf-8")
    assert 'FIRST_ACCORD_DUNGEON_MAP.generate(_root())' in builder
    assert builder.count('zone_id == "zone_16_salles_du_premier_accord"') >= 3
    assert "AuthoredDungeonMap" in dungeon_builder
    assert "AshGuidanceGraph" in dungeon_builder
    assert "_build_path_tiles" in dungeon_builder
