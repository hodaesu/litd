import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V06 = ROOT / "data" / "veilleurs" / "v06"
DUNGEONS = ROOT / "data" / "dungeons"


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def expansion():
    return load(V06 / "remaining_dungeon_archetypes_production_v1.json")


def generic_v06():
    return load(V06 / "hybrid_generation_rules.json")


def module_schema():
    return load(DUNGEONS / "hybrid_module_contract.schema.json")


def unpack_node(data, row):
    return dict(zip(data["record_fields"]["node"], row))


def parse_connector(record):
    connector_id, connector_type, orientation, level = record.split(":")
    return {
        "id": connector_id,
        "type": connector_type,
        "orientation": orientation,
        "level": int(level),
    }


def node_maps(data, pack):
    nodes = [unpack_node(data, row) for row in pack["nodes"]]
    return nodes, {node["id"]: node for node in nodes}


def test_expansion_covers_exactly_the_five_non_khar_sen_archetypes():
    data = expansion()
    generic = generic_v06()
    expected = {item["id"] for item in generic["archetypes"]} - {"DUNGEON_ASH_RUINS"}
    actual = {pack["archetype_id"] for pack in data["packs"]}
    assert actual == expected
    assert len(data["packs"]) == 5


def test_reference_room_counts_match_each_archetype_bounds_and_total_fifty():
    data = expansion()
    generic = {item["id"]: item for item in generic_v06()["archetypes"]}
    total = 0
    for pack in data["packs"]:
        count = len(pack["nodes"])
        low, high = generic[pack["archetype_id"]]["rooms"]
        assert low <= count <= high
        assert pack["room_bounds"] == [low, high]
        total += count
    assert total == 50


def test_families_and_hazards_are_bound_to_the_existing_v06_archetypes():
    data = expansion()
    generic = {item["id"]: item for item in generic_v06()["archetypes"]}
    for pack in data["packs"]:
        source = generic[pack["archetype_id"]]
        assert pack["families"] == source["families"]
        assert set(pack["environment"]) == set(source["hazards"]) | {"none"}
        nodes, _ = node_maps(data, pack)
        assert {node["family"] for node in nodes} <= set(source["families"])
        assert {node["hazard"] for node in nodes} <= set(pack["environment"])


def test_node_roles_sizes_connectors_and_mobile_costs_obey_generic_contract_enums():
    data = expansion()
    schema = module_schema()
    allowed_roles = set(schema["role_values"])
    allowed_sizes = set(schema["size_classes"])
    allowed_types = set(schema["connector_contract"]["types"])
    allowed_orientations = set(schema["connector_contract"]["orientation_values"])
    for pack in data["packs"]:
        nodes, _ = node_maps(data, pack)
        for node in nodes:
            assert node["role"] in allowed_roles
            assert node["size_class"] in allowed_sizes
            assert node["authored_mode"] in {"authored_critical", "rule_generated_support"}
            connectors = [parse_connector(item) for item in node["connectors"]]
            ids = [item["id"] for item in connectors]
            assert len(ids) == len(set(ids))
            assert all(item["type"] in allowed_types for item in connectors)
            assert all(item["orientation"] in allowed_orientations for item in connectors)
            cost = node["mobile_cost"]
            assert len(cost) == 6
            assert all(isinstance(value, int) and 0 <= value <= 5 for value in cost)
            assert node["pc_detail_tier"] in {"same", "enhanced", "hero"}


def test_every_edge_references_real_nodes_and_real_sockets():
    data = expansion()
    for pack in data["packs"]:
        _, nodes = node_maps(data, pack)
        sockets = {
            node_id: {parse_connector(item)["id"] for item in node["connectors"]}
            for node_id, node in nodes.items()
        }
        for edge in pack["edges"]:
            source, source_socket, target, target_socket, optional, requires_flag = edge
            assert source in nodes
            assert target in nodes
            assert source_socket in sockets[source]
            assert target_socket in sockets[target]
            assert isinstance(optional, bool)
            if optional:
                assert requires_flag


def test_critical_paths_are_continuous_without_optional_edges():
    data = expansion()
    for pack in data["packs"]:
        required_edges = {(edge[0], edge[2]) for edge in pack["edges"] if edge[4] is False}
        path = pack["critical_path"]
        assert len(path) == len(set(path))
        for source, target in zip(path, path[1:]):
            assert (source, target) in required_edges


def test_anchor_ids_are_unique_and_protected_overrides_resolve():
    data = expansion()
    global_anchor_ids = set()
    for pack in data["packs"]:
        _, nodes = node_maps(data, pack)
        per_node_ids = {}
        for node_id, node in nodes.items():
            anchor_ids = {
                anchor_id
                for values in node["anchors"].values()
                for anchor_id in values
            }
            socket_ids = {parse_connector(item)["id"] for item in node["connectors"]}
            per_node_ids[node_id] = anchor_ids | socket_ids
            assert not (global_anchor_ids & anchor_ids)
            global_anchor_ids |= anchor_ids
        for node_id, protected in pack["remanence"]["protected_overrides"].items():
            assert node_id in nodes
            assert set(protected) <= per_node_ids[node_id]


def test_remanence_scar_types_are_supported_by_the_generic_hybrid_system():
    data = expansion()
    generic = load(DUNGEONS / "hybrid_generation_rules.json")
    allowed = set(generic["remenance"]["allowed_scar_types"])
    for pack in data["packs"]:
        assert set(pack["remanence"]["scar_types"]) <= allowed


def test_memory_rift_optional_loop_is_noncritical_and_state_gated():
    data = expansion()
    rift = next(pack for pack in data["packs"] if pack["archetype_id"] == "DUNGEON_MEMORY_RIFT")
    loops = [edge for edge in rift["edges"] if edge[4] is True]
    assert loops == [["MR_08", "LOOP", "MR_03", "IN_2", True, "opened_shortcut"]]
    required_pairs = {(a, b) for a, b in zip(rift["critical_path"], rift["critical_path"][1:])}
    assert ("MR_08", "MR_03") not in required_pairs


def test_shared_godot_contract_keeps_mobile_desktop_topology_identical():
    data = expansion()
    shared = data["shared_contract"]
    assert (ROOT / shared["godot_base_contract"]).exists()
    assert shared["socket_node_type"] == "Marker3D"
    assert shared["anchor_node_type"] == "Marker3D"
    assert set(shared["scene_nodes"]) == {
        "Geometry", "Collision", "Sockets", "Anchors",
        "VariationSlots", "Navigation", "Remanence",
    }
    assert "mobile and desktop use identical topology and collision" in shared["invariants"]


def test_production_registry_covers_all_six_archetypes_and_unique_seeds():
    registry = load(V06 / "dungeon_production_registry.json")
    generic_ids = {item["id"] for item in generic_v06()["archetypes"]}
    entries = registry["archetypes"]
    assert {entry["archetype_id"] for entry in entries} == generic_ids
    seeds = [entry["seed"] for entry in entries]
    assert len(seeds) == len(set(seeds)) == 6
    assert next(entry for entry in entries if entry["archetype_id"] == "DUNGEON_ASH_RUINS")["production_status"] == "canonical_slice_locked"
    assert all(entry["production_status"].endswith("slice_locked") for entry in entries)


def test_registry_file_references_exist_on_branch():
    registry = load(V06 / "dungeon_production_registry.json")
    for entry in registry["archetypes"]:
        for relative in entry.get("files", []):
            assert (ROOT / relative).exists()
        container = entry.get("container_file")
        if container:
            assert (ROOT / container).exists()
