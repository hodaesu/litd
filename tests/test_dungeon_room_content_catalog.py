import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V06 = ROOT / "data" / "veilleurs" / "v06"


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def catalog():
    return load(V06 / "dungeon_room_content_catalog_v1.json")


def expected_room_ids():
    khar = load(V06 / "khar_sen_module_catalog.json")
    other = load(V06 / "remaining_dungeon_archetypes_production_v1.json")
    ids = {module["node_id"] for module in khar["modules"]}
    node_id_index = other["record_fields"]["node"].index("id")
    for pack in other["packs"]:
        ids |= {row[node_id_index] for row in pack["nodes"]}
    return ids


def room_records(data):
    fields = data["record_fields"]
    return [dict(zip(fields, row)) for row in data["rooms"]]


def split_composition_id(data, composition_id):
    for family in sorted(data["enemy_rosters"], key=len, reverse=True):
        prefix = family + "_"
        if composition_id.startswith(prefix):
            return family, composition_id[len(prefix):]
    raise AssertionError(f"Unknown composition family in {composition_id}")


def test_catalog_covers_exactly_all_fifty_nine_production_rooms():
    data = catalog()
    rooms = room_records(data)
    ids = [room["room_id"] for room in rooms]
    assert data["room_count"] == 59
    assert len(ids) == len(set(ids)) == 59
    assert set(ids) == expected_room_ids()


def test_enemy_rosters_reference_only_known_v06_enemies():
    data = catalog()
    enemies = load(V06 / "enemies_24_definitions.json")
    known = {enemy["entity_id"] for enemy in enemies["enemies"]}
    assert sum(len(roster) for roster in data["enemy_rosters"].values()) == 24
    for roster in data["enemy_rosters"].values():
        assert len(roster) == 4
        assert set(roster) <= known


def test_every_declared_enemy_set_can_be_resolved_deterministically():
    data = catalog()
    for room in room_records(data):
        for composition_id in room["enemy_sets"]:
            if composition_id in data["boss_slots"]:
                assert data["boss_slots"][composition_id]["family"] in data["enemy_rosters"]
                continue
            family, pattern = split_composition_id(data, composition_id)
            assert family in data["enemy_rosters"]
            assert pattern in data["band_patterns"]
            roster = data["enemy_rosters"][family]
            expanded = [roster[index] for index in data["band_patterns"][pattern]]
            assert 3 <= len(expanded) <= 5


def test_every_room_has_complete_level_design_content_binding():
    data = catalog()
    for room in room_records(data):
        assert room["loot_table"] in data["loot_tables"]
        assert len(room["events"]) >= 2
        assert len(room["curios"]) >= 2
        assert len(room["lore_hook_fr"].strip()) >= 30
        assert len(room["props"]) >= 4
        assert room["material_kit"] in data["material_kits"]
        assert room["lighting"].strip()
        assert room["audio"].strip()
        assert room["variation_profile"] in data["variation_profiles"]


def test_loot_tables_are_seedable_and_use_independent_roll_contract():
    data = catalog()
    assert data["policy"]["loot_rolls_are_seeded"] is True
    for table in data["loot_tables"].values():
        assert "guaranteed" in table
        assert "independent_rolls" in table
        for reward, chance in table["independent_rolls"]:
            assert reward
            assert 0.0 <= chance <= 1.0


def test_boss_rooms_use_slots_instead_of_inventing_boss_entity_ids():
    data = catalog()
    rooms = {room["room_id"]: room for room in room_records(data)}
    assert rooms["FS_10"]["enemy_sets"] == ["BOSS_FS_10"]
    assert rooms["BQ_10"]["enemy_sets"] == ["BOSS_BQ_10"]
    assert rooms["MR_12"]["enemy_sets"] == ["BOSS_MR_12"]
    assert data["policy"]["boss_identity_is_bound_by_boss_catalog_not_invented_here"] is True


def test_protected_variation_profiles_never_randomize_core_topology():
    data = catalog()
    profiles = data["variation_profiles"]
    assert "sockets" in profiles["V_ENTRY"]
    assert "retreat" in profiles["V_COMBAT"]
    assert "route logic" in profiles["V_CHOICE"]
    assert "lore/event anchors" in profiles["V_NARRATIVE"]
    assert "valid solution" in profiles["V_PUZZLE"]
    assert "boss-critical geometry authored" in profiles["V_BOSS"]
    assert "extraction/objective anchors" in profiles["V_EXIT"]
    assert "saved loop flag" in profiles["V_LOOP_GATE"]


def test_memory_rift_content_never_turns_ui_uncertainty_into_illegal_controls():
    data = catalog()
    rooms = {room["room_id"]: room for room in room_records(data)}
    assert "légalité" in rooms["MR_04"]["lore_hook_fr"]
    assert "ne disparaît jamais" in rooms["MR_07"]["lore_hook_fr"]
    assert data["policy"]["saved_outcomes_override_random_dressing"] is True


def test_every_biome_has_a_distinct_material_identity():
    data = catalog()
    expected = {"MAT_KHAR", "MAT_BG", "MAT_FS", "MAT_AQ", "MAT_BQ", "MAT_MR"}
    assert set(data["material_kits"]) == expected
    used = {room["material_kit"] for room in room_records(data)}
    assert used == expected
