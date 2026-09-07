import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VEILLEURS = ROOT / "data" / "veilleurs" / "v06"
DUNGEONS = ROOT / "data" / "dungeons"


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def test_khar_sen_kit_files_are_valid_and_bound_to_canonical_slice():
    slice_data = load(VEILLEURS / "dungeon_slice_01_khar_sen.json")
    for name in [
        "khar_sen_module_catalog.json",
        "khar_sen_environment_rules.json",
        "khar_sen_remanence_matrix.json",
        "khar_sen_godot_scene_contract.json",
    ]:
        data = load(VEILLEURS / name)
        assert data["schema_version"] == "0.6.3"
        assert data["slice_id"] == slice_data["slice_id"]


def test_catalog_covers_all_nine_canonical_nodes_once():
    slice_data = load(VEILLEURS / "dungeon_slice_01_khar_sen.json")
    catalog = load(VEILLEURS / "khar_sen_module_catalog.json")
    canonical = [node["node_id"] for node in slice_data["nodes"]]
    module_nodes = [module["node_id"] for module in catalog["modules"]]
    assert module_nodes == canonical
    assert len(module_nodes) == len(set(module_nodes)) == 9


def test_khar_sen_modules_satisfy_generic_hybrid_contract():
    schema = load(DUNGEONS / "hybrid_module_contract.schema.json")
    catalog = load(VEILLEURS / "khar_sen_module_catalog.json")
    required = set(schema["required"])
    allowed_roles = set(schema["role_values"])
    for module in catalog["modules"]:
        assert required <= set(module)
        assert module["role"] in allowed_roles
        connector_ids = [connector["id"] for connector in module["connectors"]]
        assert len(connector_ids) == len(set(connector_ids))


def test_authored_and_generated_policy_matches_khar_sen_story_topology():
    catalog = load(VEILLEURS / "khar_sen_module_catalog.json")
    policy = catalog["authorship_policy"]
    assert policy["critical_authored_nodes"] == [
        "KHAR_01", "KHAR_03", "KHAR_05", "KHAR_06", "KHAR_08", "KHAR_09"
    ]
    assert policy["rule_generated_support_nodes"] == ["KHAR_02", "KHAR_04", "KHAR_07"]
    assert policy["variants_may_change_critical_connectors"] is False
    assert policy["variants_may_change_story_anchors"] is False


def test_every_environment_binding_matches_canonical_hazard():
    slice_data = load(VEILLEURS / "dungeon_slice_01_khar_sen.json")
    environment = load(VEILLEURS / "khar_sen_environment_rules.json")
    for node in slice_data["nodes"]:
        assert environment["node_bindings"][node["node_id"]]["hazard"] == node["hazard"]
        assert node["hazard"] in environment["hazards"]


def test_remanence_references_only_catalog_anchors_or_connectors():
    catalog = load(VEILLEURS / "khar_sen_module_catalog.json")
    remanence = load(VEILLEURS / "khar_sen_remanence_matrix.json")
    modules = {module["node_id"]: module for module in catalog["modules"]}
    for node_id, rules in remanence["nodes"].items():
        module = modules[node_id]
        known = {connector["id"] for connector in module["connectors"]}
        for key in ("scar_anchors", "encounter_anchors", "resource_anchors", "lore_anchors"):
            known |= {anchor["anchor_id"] for anchor in module[key]}
        assert set(rules["protected"]) <= known


def test_archive_memory_event_and_objective_anchors_are_protected():
    remanence = load(VEILLEURS / "khar_sen_remanence_matrix.json")
    assert "KS03_LORE_CODEX_REMANENCE_FIRST_TRACE" in remanence["nodes"]["KHAR_03"]["protected"]
    assert "KS05_ENC_MEMORY" in remanence["nodes"]["KHAR_05"]["protected"]
    assert "KS08_LORE_SURVIVOR" in remanence["nodes"]["KHAR_08"]["protected"]
    assert "KS09_RES_TRACE" in remanence["nodes"]["KHAR_09"]["protected"]
    assert "EXTRACT" in remanence["nodes"]["KHAR_09"]["protected"]


def test_choice_and_final_objective_keep_both_routes_solvable():
    catalog = load(VEILLEURS / "khar_sen_module_catalog.json")
    modules = {module["node_id"]: module for module in catalog["modules"]}
    choice = {connector["id"] for connector in modules["KHAR_06"]["connectors"]}
    final = {connector["id"] for connector in modules["KHAR_09"]["connectors"]}
    assert {"IN", "LEFT", "RIGHT"} <= choice
    assert {"IN_LEFT", "IN_RIGHT", "EXTRACT"} <= final


def test_godot_scene_contract_uses_stable_marker_sockets_and_anchors():
    contract = load(VEILLEURS / "khar_sen_godot_scene_contract.json")
    required_children = {child["name"] for child in contract["room_scene"]["required_children"]}
    assert {"Geometry", "Collision", "Sockets", "Anchors", "VariationSlots", "Navigation", "Remanence"} <= required_children
    assert contract["socket_contract"]["node_type"] == "Marker3D"
    assert contract["anchor_contract"]["node_type"] == "Marker3D"
    assert "critical socket transform" in contract["variation_contract"]["forbidden_mutations"]
    assert "navigation solvability" in contract["variation_contract"]["forbidden_mutations"]


def test_mobile_and_desktop_topology_and_collision_are_shared():
    generic = load(DUNGEONS / "hybrid_generation_rules.json")
    scene = load(VEILLEURS / "khar_sen_godot_scene_contract.json")
    assert generic["global_constraints"]["mobile_pc_topology_identical"] is True
    assert "Mobile and desktop use identical topology and collision." in scene["acceptance_tests"]
