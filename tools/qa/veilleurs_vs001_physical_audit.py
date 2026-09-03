from __future__ import annotations

import json
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOGICAL_PATH = ROOT / "data" / "dungeons" / "voices_under_sanctuary_map.json"
PHYSICAL_PATH = ROOT / "data" / "dungeons" / "voices_under_sanctuary_physical_map.json"
MODULES_PATH = ROOT / "data" / "dungeons" / "voices_under_sanctuary_module_library.json"


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _reachable(connections: list[dict], start: str, goal: str, include_secrets: bool) -> bool:
    queue: deque[str] = deque([start])
    visited = {start}
    while queue:
        current = queue.popleft()
        if current == goal:
            return True
        for connection in connections:
            if connection.get("secret", False) and not include_secrets:
                continue
            a = str(connection.get("a", ""))
            b = str(connection.get("b", ""))
            if current == a:
                nxt = b
            elif current == b:
                nxt = a
            else:
                continue
            if nxt not in visited:
                visited.add(nxt)
                queue.append(nxt)
    return False


def _same_level_overlap(a: dict, b: dict) -> bool:
    ac = [float(v) for v in a["center"]]
    bc = [float(v) for v in b["center"]]
    az = [float(v) for v in a["size"]]
    bz = [float(v) for v in b["size"]]
    vertical_separated = abs(ac[1] - bc[1]) >= (az[1] + bz[1]) * 0.5
    if vertical_separated:
        return False
    x_overlap = abs(ac[0] - bc[0]) < (az[0] + bz[0]) * 0.5
    z_overlap = abs(ac[2] - bc[2]) < (az[2] + bz[2]) * 0.5
    return x_overlap and z_overlap


def audit() -> list[str]:
    errors: list[str] = []
    logical = _load(LOGICAL_PATH)
    physical = _load(PHYSICAL_PATH)
    modules = _load(MODULES_PATH)

    if physical.get("version") != 1:
        errors.append("physical_version")
    if physical.get("seed") != logical.get("seed"):
        errors.append("seed_mismatch")
    if physical.get("logical_map") != "res://data/dungeons/voices_under_sanctuary_map.json":
        errors.append("logical_map_reference")

    logical_rooms = {room["id"]: room for room in logical.get("rooms", [])}
    physical_rooms = {room["id"]: room for room in physical.get("rooms", [])}
    if set(logical_rooms) != set(physical_rooms):
        errors.append("room_set_mismatch")
    if len(physical_rooms) != 8:
        errors.append("physical_room_count")

    for room_id, room in physical_rooms.items():
        size = room.get("size", [])
        center = room.get("center", [])
        if len(size) != 3 or any(float(value) <= 0 for value in size):
            errors.append(f"invalid_room_size:{room_id}")
        if len(center) != 3:
            errors.append(f"invalid_room_center:{room_id}")
        if not room.get("openings"):
            errors.append(f"missing_openings:{room_id}")
        if not str(room.get("blender_asset_slot", "")).startswith("VEILLEURS_VS001_"):
            errors.append(f"blender_slot:{room_id}")
        logical_room = logical_rooms.get(room_id, {})
        if bool(room.get("critical", False)) != bool(logical_room.get("critical", False)):
            errors.append(f"criticality_mismatch:{room_id}")

    room_values = list(physical_rooms.values())
    for index, room_a in enumerate(room_values):
        for room_b in room_values[index + 1 :]:
            if _same_level_overlap(room_a, room_b):
                errors.append(f"room_overlap:{room_a['id']}:{room_b['id']}")

    for optional_id in ("s4_forgotten_store", "s6_survivor", "s8_lower_archive"):
        if not bool(physical_rooms.get(optional_id, {}).get("optional", False)):
            errors.append(f"optional_room_contract:{optional_id}")
    if not bool(physical_rooms.get("s8_lower_archive", {}).get("secret", False)):
        errors.append("s8_not_secret")
    s7_y = float(physical_rooms["s7_voice_chamber"]["center"][1])
    s8_y = float(physical_rooms["s8_lower_archive"]["center"][1])
    if s8_y > s7_y - 3.0:
        errors.append("s8_not_lower_level")

    logical_pairs = {
        frozenset((connection["a"], connection["b"]))
        for connection in logical.get("connections", [])
    }
    physical_connections = physical.get("connections", [])
    physical_pairs = {
        frozenset((connection["a"], connection["b"]))
        for connection in physical_connections
    }
    if logical_pairs != physical_pairs:
        errors.append("connection_graph_mismatch")
    if len(physical_connections) != 7:
        errors.append("physical_connection_count")

    connection_ids = [connection.get("id") for connection in physical_connections]
    if len(connection_ids) != len(set(connection_ids)):
        errors.append("duplicate_connection_id")
    for connection in physical_connections:
        if connection.get("a") not in physical_rooms or connection.get("b") not in physical_rooms:
            errors.append(f"connection_unknown_room:{connection.get('id')}")
        if len(connection.get("waypoints", [])) < 2:
            errors.append(f"connection_waypoints:{connection.get('id')}")
        if float(connection.get("width", 0)) < 1.4:
            errors.append(f"connection_too_narrow:{connection.get('id')}")

    secret_connection = next(
        (connection for connection in physical_connections if connection.get("id") == "c_s7_s8"),
        None,
    )
    if not secret_connection or not secret_connection.get("secret", False):
        errors.append("secret_connection_missing")
    elif secret_connection.get("locked_by") != "s7_study_acoustic_device":
        errors.append("secret_connection_lock")

    if not _reachable(physical_connections, "s1_vestibule", "s7_voice_chamber", False):
        errors.append("objective_unreachable_without_secret")
    if not _reachable(physical_connections, "s7_voice_chamber", "s1_vestibule", False):
        errors.append("physical_retreat_broken")
    if _reachable(physical_connections, "s1_vestibule", "s8_lower_archive", False):
        errors.append("s8_reachable_without_secret")
    if not _reachable(physical_connections, "s1_vestibule", "s8_lower_archive", True):
        errors.append("s8_not_reachable_after_secret")

    anchors = physical.get("gameplay_anchors", [])
    anchor_ids = [anchor.get("id") for anchor in anchors]
    if len(anchor_ids) != 17 or len(anchor_ids) != len(set(anchor_ids)):
        errors.append("gameplay_anchor_set")
    for anchor in anchors:
        if anchor.get("room") not in physical_rooms:
            errors.append(f"anchor_unknown_room:{anchor.get('id')}")
        if len(anchor.get("position", [])) != 3:
            errors.append(f"anchor_position:{anchor.get('id')}")
        if not anchor.get("role"):
            errors.append(f"anchor_role:{anchor.get('id')}")

    source_anchor_ids: set[str] = set()
    for module in modules.get("modules", []):
        for group in ("scar_anchors", "encounter_anchors", "resource_anchors", "lore_anchors"):
            for anchor in module.get(group, []):
                source_anchor_ids.add(str(anchor.get("anchor_id", "")))
    for anchor in anchors:
        source_anchor = str(anchor.get("source_anchor", ""))
        if source_anchor and source_anchor not in source_anchor_ids:
            errors.append(f"unknown_source_anchor:{anchor.get('id')}:{source_anchor}")

    required_roles = {
        "physical_extraction",
        "hazard",
        "combat",
        "corpse",
        "recruitment",
        "objective_device",
        "secret_reveal",
        "secret_archive",
        "knowledge",
    }
    roles = {str(anchor.get("role", "")) for anchor in anchors}
    if not required_roles <= roles:
        errors.append("required_gameplay_roles")

    rules = physical.get("design_rules", {})
    for key in (
        "mobile_first",
        "physical_backtracking",
        "critical_path_readable_without_minimap",
        "optional_rooms_never_block_objective",
        "secret_room_below_objective_level",
        "navigation_bake_required_after_art_pass",
    ):
        if rules.get(key) is not True:
            errors.append(f"design_rule:{key}")
    if rules.get("scene_snapshot_persistence") is not False:
        errors.append("scene_snapshot_persistence_forbidden")

    budgets = physical.get("budgets", {})
    if int(budgets.get("max_proxy_meshes", 999)) > 180:
        errors.append("mesh_budget_too_high")
    if int(budgets.get("max_collision_shapes", 999)) > 180:
        errors.append("collision_budget_too_high")
    if int(budgets.get("max_dynamic_bodies", -1)) != 0:
        errors.append("dynamic_body_budget")

    return errors


def main() -> int:
    errors = audit()
    print(json.dumps({"system": "veilleurs_vs001_physical", "ok": not errors, "errors": errors}, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
