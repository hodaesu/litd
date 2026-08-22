#!/usr/bin/env python3
"""Generate Blender-ready First Veil room modules.

Usage from Blender:
  blender --background --python tools/blender/generate_first_veil_architecture.py -- \
    --room-id ALL --output-dir build/first_veil_rooms --export-glb

The script deliberately keeps gameplay state out of Blender. It creates geometry,
materials and stable empties for anchors/ports. Godot remains authoritative for
secret visibility, combat state, spawns and exit activation.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

try:
    import bpy
except ImportError as exc:  # pragma: no cover - only runnable inside Blender
    raise SystemExit("This script must be executed by Blender Python (bpy missing).") from exc


ROOT = Path(__file__).resolve().parents[2]
PLAN_PATH = ROOT / "data" / "roguelike" / "first_veil_proxy_plan.json"
KIT_PATH = ROOT / "data" / "roguelike" / "first_veil_architecture_kit.json"
ROOMS_PATH = ROOT / "data" / "roguelike" / "first_veil_rooms.json"


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--room-id", default="ALL")
    parser.add_argument("--output-dir", default="build/first_veil_rooms")
    parser.add_argument("--export-glb", action="store_true")
    parser.add_argument("--save-blend", action="store_true", default=True)
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def ensure_collection(name: str) -> bpy.types.Collection:
    collection = bpy.data.collections.get(name)
    if collection is None:
        collection = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(collection)
    return collection


def move_to_collection(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)


def material(name: str, rgba: list[float], metallic: float = 0.0, roughness: float = 0.8) -> bpy.types.Material:
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.diffuse_color = tuple(rgba)
    mat.metallic = metallic
    mat.roughness = roughness
    return mat


def add_cube(name: str, size: tuple[float, float, float], location: tuple[float, float, float], mat=None, collection=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        obj.data.materials.append(mat)
    if collection:
        move_to_collection(obj, collection)
    return obj


def add_cylinder(name: str, radius: float, depth: float, location, mat=None, collection=None, vertices: int = 12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    if mat:
        obj.data.materials.append(mat)
    if collection:
        move_to_collection(obj, collection)
    return obj


def add_empty(name: str, location, collection, display="PLAIN_AXES"):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = display
    obj.location = location
    collection.objects.link(obj)
    return obj


def add_arch(name: str, location, width: float, height: float, depth: float, stone, geo):
    # Three-piece gothic proxy arch; artists can replace it while preserving the port empty.
    add_cube(f"{name}_L", (0.45, depth, height), (location[0] - width * 0.5, location[1], height * 0.5), stone, geo)
    add_cube(f"{name}_R", (0.45, depth, height), (location[0] + width * 0.5, location[1], height * 0.5), stone, geo)
    add_cube(f"{name}_TOP", (width + 0.9, depth, 0.5), (location[0], location[1], height), stone, geo)


def room_by_id(room_catalog: dict) -> dict[str, dict]:
    return {room["id"]: room for room in room_catalog.get("rooms", [])}


def anchor_positions(dim: list[float], anchor_profile: dict) -> dict[str, tuple[float, float, float]]:
    width, length, height = map(float, dim)
    positions = {}
    for key, raw in anchor_profile.items():
        x = float(raw[0]) * width
        y = float(raw[1]) * height if key == "camera_focus" else float(raw[1])
        z = float(raw[2]) * length
        positions[key] = (x, z, y)  # Blender: X,Y horizontal, Z up
    return positions


def port_location(side: str, width: float, length: float):
    if side == "north":
        return (0.0, -length * 0.5, 0.0)
    if side == "south":
        return (0.0, length * 0.5, 0.0)
    if side == "east":
        return (width * 0.5, 0.0, 0.0)
    return (-width * 0.5, 0.0, 0.0)


def build_room(plan_room: dict, logical_room: dict, plan: dict, kit: dict, output_dir: Path, export_glb: bool, save_blend: bool) -> None:
    clear_scene()
    module_id = plan_room["module"]
    room_id = plan_room["id"]
    width, length, height = map(float, plan_room["dimensions"])
    role = plan_room.get("role", "support")

    geo = ensure_collection("GEO")
    collision = ensure_collection("COLLISION")
    gameplay = ensure_collection("GAMEPLAY_ANCHORS")
    light_anchors = ensure_collection("LIGHT_ANCHORS")
    fx_anchors = ensure_collection("FX_ANCHORS")

    palette = kit["palette"]
    stone = material("MAT_stone", palette["stone"], roughness=0.88)
    ash = material("MAT_ash", palette["ash"], roughness=0.96)
    metal = material("MAT_metal", palette["metal"], metallic=0.72, roughness=0.44)
    bone = material("MAT_bone", palette["bone"], roughness=0.78)
    ritual = material("MAT_ritual", palette["ritual"], roughness=0.82)
    cloth = material("MAT_cloth", palette["cloth"], roughness=0.9)

    floor = add_cube(f"{module_id}_FLOOR_LOD0", (width, length, 0.25), (0, 0, -0.125), stone, geo)
    floor["litd_asset_family"] = "floor"
    add_cube(f"{module_id}_FLOOR_COL", (width, length, 0.25), (0, 0, -0.125), None, collision).hide_render = True

    wall_t = float(plan["geometry"]["wall"])
    door_w, door_h = map(float, plan["geometry"]["door"])
    sides = plan_room.get("port_sides", ["north", "east", "south", "west"])
    connection_count = len(logical_room.get("connections", []))
    open_sides = set(sides[:connection_count])

    def wall_with_opening(side: str):
        if side in ("north", "south"):
            y = -length * 0.5 if side == "north" else length * 0.5
            if side in open_sides:
                seg = max(0.5, (width - door_w) * 0.5)
                add_cube(f"WALL_{side}_L", (seg, wall_t, height), (-(door_w + seg) * 0.5, y, height * 0.5), stone, geo)
                add_cube(f"WALL_{side}_R", (seg, wall_t, height), ((door_w + seg) * 0.5, y, height * 0.5), stone, geo)
                add_arch(f"ARCH_{side}", (0.0, y, 0.0), door_w * 0.5, door_h, wall_t * 1.3, stone, geo)
            else:
                add_cube(f"WALL_{side}", (width, wall_t, height), (0, y, height * 0.5), stone, geo)
        else:
            x = width * 0.5 if side == "east" else -width * 0.5
            if side in open_sides:
                seg = max(0.5, (length - door_w) * 0.5)
                add_cube(f"WALL_{side}_L", (wall_t, seg, height), (x, -(door_w + seg) * 0.5, height * 0.5), stone, geo)
                add_cube(f"WALL_{side}_R", (wall_t, seg, height), (x, (door_w + seg) * 0.5, height * 0.5), stone, geo)
            else:
                add_cube(f"WALL_{side}", (wall_t, length, height), (x, 0, height * 0.5), stone, geo)

    for side in ("north", "south", "east", "west"):
        wall_with_opening(side)

    recipe = kit["role_recipes"].get(role, kit["role_recipes"]["support"])
    for i in range(int(recipe.get("pillars", 0))):
        angle = (i / max(1, int(recipe.get("pillars", 1)))) * math.tau
        add_cylinder(f"PILLAR_{i}", 0.42 if role != "boss" else 0.7, 2.8 if role != "boss" else 4.2,
                     (math.cos(angle) * width * 0.32, math.sin(angle) * length * 0.28, 1.4 if role != "boss" else 2.1), stone, geo)
    for i in range(int(recipe.get("tombs", 0))):
        side = -1 if i % 2 == 0 else 1
        add_cube(f"SARCOPHAGUS_{i}", (2.3, 1.1, 0.8), (side * width * 0.28, -length * 0.05 + (i // 2) * 2.0, 0.4), bone, geo)
    for i in range(int(recipe.get("chains", 0))):
        x = ((i + 1) / (int(recipe.get("chains", 0)) + 1) - 0.5) * width * 0.7
        add_cylinder(f"CHAIN_PROXY_{i}", 0.07, max(2.0, height * 0.6), (x, length * 0.08, height * 0.68), metal, geo, 8)
    for i in range(int(recipe.get("altars", 0))):
        add_cube(f"ALTAR_{i}", (2.5, 1.4, 1.0), (0, length * 0.24, 0.5), ritual, geo)
    for i in range(int(recipe.get("furniture", 0))):
        side = -1 if i % 2 == 0 else 1
        add_cube(f"FURNITURE_{i}", (1.8, 0.8, 0.8), (side * width * 0.27, -length * 0.18 + (i // 2) * 1.8, 0.4), cloth if role == "support" else stone, geo)
    for i in range(int(recipe.get("traps", 0))):
        x = (i - (int(recipe.get("traps", 0)) - 1) * 0.5) * 1.5
        add_cube(f"TRAP_PLATE_{i}", (1.1, 1.1, 0.08), (x, 0.2, 0.04), metal, geo)
    for i in range(int(recipe.get("debris", 0))):
        add_cube(f"DEBRIS_{i}", (0.6 + 0.15 * (i % 2), 0.5, 0.3), (-width * 0.3 + i * 1.25, -length * 0.28, 0.15), ash, geo)

    if role == "boss":
        add_cube("BOSS_DAIS", (7.0, 4.5, 0.65), (0, length * 0.22, 0.325), ritual, geo)
        add_cube("BOSS_ALTAR", (3.6, 1.8, 1.5), (0, length * 0.28, 0.75), bone, geo)

    anchors = anchor_positions(plan_room["dimensions"], plan["anchor_profile"])
    for anchor_name, location in anchors.items():
        add_empty(anchor_name, location, gameplay)

    for idx, target in enumerate(logical_room.get("connections", [])):
        side = sides[idx % len(sides)]
        loc = port_location(side, width, length)
        empty = add_empty(f"port_{side}_{target}", loc, gameplay, "ARROWS")
        empty["target_room_id"] = target
        empty["secret_connection"] = bool(target.startswith("p") and target.endswith("secret"))

    light_count = max(1, int(recipe.get("lights", 2)))
    for i in range(light_count):
        angle = (i / light_count) * math.tau
        loc = (math.cos(angle) * width * 0.32, math.sin(angle) * length * 0.3, min(2.6, height * 0.55))
        empty = add_empty(f"light_anchor_{i}", loc, light_anchors)
        empty["suggested_fixture"] = "FV_WALL_LAMP" if i % 2 else "FV_BRAZIER"

    add_empty("fx_room_center", (0, 0, 0.2), fx_anchors)
    add_empty("fx_ceiling", (0, 0, height * 0.88), fx_anchors)

    bpy.context.scene["litd_room_id"] = room_id
    bpy.context.scene["litd_module_id"] = module_id
    bpy.context.scene["litd_role"] = role
    bpy.context.scene["litd_dimensions_m"] = json.dumps(plan_room["dimensions"])
    bpy.context.scene["litd_variant_pool"] = json.dumps(logical_room.get("variant_pool", []))

    output_dir.mkdir(parents=True, exist_ok=True)
    if save_blend:
        bpy.ops.wm.save_as_mainfile(filepath=str((output_dir / f"{module_id}.blend").resolve()))
    if export_glb:
        bpy.ops.export_scene.gltf(
            filepath=str((output_dir / f"{module_id}.glb").resolve()),
            export_format="GLB",
            use_selection=False,
            export_apply=True,
        )
    print(f"FIRST_VEIL_BLENDER_ROOM_OK room={room_id} module={module_id}")


def main() -> None:
    args = parse_args()
    plan = load_json(PLAN_PATH)
    kit = load_json(KIT_PATH)
    room_catalog = load_json(ROOMS_PATH)
    logical_by_id = room_by_id(room_catalog)
    plan_by_id = {room["id"]: room for room in plan["rooms"]}
    room_ids = list(plan_by_id) if args.room_id == "ALL" else [args.room_id]
    missing = [room_id for room_id in room_ids if room_id not in plan_by_id or room_id not in logical_by_id]
    if missing:
        raise SystemExit(f"Unknown or incomplete room ids: {missing}")
    output_dir = (ROOT / args.output_dir).resolve()
    for room_id in room_ids:
        build_room(plan_by_id[room_id], logical_by_id[room_id], plan, kit, output_dir, args.export_glb, args.save_blend)
    print(f"FIRST_VEIL_BLENDER_BATCH_OK rooms={len(room_ids)} output={output_dir}")


if __name__ == "__main__":
    main()
