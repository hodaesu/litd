import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAN = json.loads((ROOT / "data/roguelike/first_veil_proxy_plan.json").read_text(encoding="utf-8"))
KIT = json.loads((ROOT / "data/roguelike/first_veil_architecture_kit.json").read_text(encoding="utf-8"))
ROOMS = json.loads((ROOT / "data/roguelike/first_veil_rooms.json").read_text(encoding="utf-8"))
BLENDER_SCRIPT = (ROOT / "tools/blender/generate_first_veil_architecture.py").read_text(encoding="utf-8")


def test_architecture_kit_covers_all_gameplay_roles():
    roles = {room["role"] for room in PLAN["rooms"]}
    missing = roles - set(KIT["role_recipes"])
    assert not missing, f"Architecture kit missing role recipes: {sorted(missing)}"


def test_blender_contract_preserves_required_gameplay_structure():
    contract = KIT["blender_contract"]
    assert contract["unit_scale_meters"] == 1.0
    assert contract["export_format"] == "glTF 2.0 / .glb"
    assert {"GEO", "COLLISION", "GAMEPLAY_ANCHORS", "LIGHT_ANCHORS", "FX_ANCHORS"}.issubset(contract["required_collections"])
    assert "secret visibility" in contract["do_not_bake_gameplay"]
    assert "exit enabled state" in contract["do_not_bake_gameplay"]


def test_every_room_has_unique_blender_module_and_matching_logical_room():
    logical_ids = {room["id"] for room in ROOMS["rooms"]}
    modules = [room["module"] for room in PLAN["rooms"]]
    assert len(PLAN["rooms"]) == 37
    assert len(modules) == len(set(modules))
    assert {room["id"] for room in PLAN["rooms"]} == logical_ids


def test_asset_families_cover_requested_crypt_content():
    expected = {"wall", "arch", "door", "stair", "pillar", "tomb", "chain", "altar", "trap", "furniture", "light", "debris", "water", "boss"}
    assert expected.issubset(KIT["asset_families"])
    for family in expected:
        assert KIT["asset_families"][family], family


def test_blender_generator_is_batchable_and_exports_glb():
    assert "--room-id" in BLENDER_SCRIPT
    assert 'default="ALL"' in BLENDER_SCRIPT
    assert "--export-glb" in BLENDER_SCRIPT
    assert "bpy.ops.export_scene.gltf" in BLENDER_SCRIPT
    assert "FIRST_VEIL_BLENDER_BATCH_OK" in BLENDER_SCRIPT
    assert "GAMEPLAY_ANCHORS" in BLENDER_SCRIPT
    assert "LIGHT_ANCHORS" in BLENDER_SCRIPT
    assert "FX_ANCHORS" in BLENDER_SCRIPT


def test_secrets_remain_godot_authoritative():
    assert KIT["principles"][3] == "Secret architecture is never instantiated before discovery."
    assert "secret visibility" in KIT["blender_contract"]["do_not_bake_gameplay"]
