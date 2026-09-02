import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DUNGEONS = ROOT / "data" / "dungeons"


def load(name):
    return json.loads((DUNGEONS / name).read_text(encoding="utf-8"))


def test_hybrid_files_are_valid_json_and_versioned():
    for name in [
        "hybrid_module_contract.schema.json",
        "hybrid_generation_rules.json",
        "first_accord_hybrid_config.json",
        "first_accord_module_library.json",
        "first_accord_remanence_anchors.json",
        "first_accord_encounters.json",
    ]:
        data = load(name)
        assert data["version"] == 1


def test_first_accord_protected_story_order_is_complete():
    cfg = load("first_accord_hybrid_config.json")
    protected = cfg["protected_story_order"]
    assert protected == [
        "vestibule",
        "gallery_of_names",
        "debate_chamber",
        "collapsed_passage",
        "three_pillars_hall",
        "warden_sanctum",
    ]
    mandatory = {room["id"] for room in cfg["mandatory_rooms"]}
    assert set(protected) <= mandatory


def test_every_mandatory_pool_resolves_to_a_module():
    cfg = load("first_accord_hybrid_config.json")
    lib = load("first_accord_module_library.json")
    pools = {m["pool"] for m in lib["modules"]}
    for room in cfg["mandatory_rooms"]:
        assert room["module_pool"] in pools


def test_protected_boss_module_exists_and_is_boss():
    cfg = load("first_accord_hybrid_config.json")
    lib = load("first_accord_module_library.json")
    modules = {m["module_id"]: m for m in lib["modules"]}
    boss = modules[cfg["protected_boss_module"]]
    assert boss["role"] == "boss"
    assert boss["combat_profile"] == "authored_boss"


def test_module_ids_and_connector_ids_are_unique():
    lib = load("first_accord_module_library.json")
    ids = [m["module_id"] for m in lib["modules"]]
    assert len(ids) == len(set(ids))
    for module in lib["modules"]:
        connector_ids = [c["id"] for c in module["connectors"]]
        assert len(connector_ids) == len(set(connector_ids))


def test_all_scar_anchors_exist_in_catalog():
    lib = load("first_accord_module_library.json")
    rem = load("first_accord_remanence_anchors.json")
    catalog = {a["anchor_id"] for a in rem["anchors"]}
    referenced = {
        scar["anchor_id"]
        for module in lib["modules"]
        for scar in module.get("scar_anchors", [])
    }
    assert referenced <= catalog


def test_critical_remanence_cannot_remove_only_retreat():
    rem = load("first_accord_remanence_anchors.json")
    anchors = {a["anchor_id"]: a for a in rem["anchors"]}
    retreat = anchors["accord.collapse.retreat_breach"]
    assert retreat["criticality"] == "protected"
    assert retreat["progression_rule"] == "physical_retreat_must_remain_possible"


def test_nemesis_rules_cannot_break_critical_progression():
    encounters = load("first_accord_encounters.json")
    rules = encounters["nemesis_override"]
    assert rules["may_block_critical_path"] is False
    assert rules["may_remove_only_retreat"] is False
    assert rules["requires_shared_history"] is True


def test_mobile_and_pc_share_topology_contract():
    rules = load("hybrid_generation_rules.json")
    assert rules["global_constraints"]["mobile_pc_topology_identical"] is True
    assert rules["global_constraints"]["store_scene_snapshots"] is False


def test_module_contract_required_fields_are_present():
    schema = load("hybrid_module_contract.schema.json")
    lib = load("first_accord_module_library.json")
    required = set(schema["required"])
    for module in lib["modules"]:
        assert required <= set(module)


def test_every_encounter_table_references_known_module_pool_or_service_pool():
    lib = load("first_accord_module_library.json")
    encounters = load("first_accord_encounters.json")
    pools = {m["pool"] for m in lib["modules"]} | {"accord_service_rooms"}
    assert set(encounters["room_tables"]) <= pools


def test_fallback_authored_map_still_exists():
    cfg = load("first_accord_hybrid_config.json")
    res_path = cfg["fallback_authored_map"]
    assert res_path.startswith("res://")
    local = ROOT / res_path.removeprefix("res://")
    assert local.exists()
