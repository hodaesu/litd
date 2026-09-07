import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V06 = ROOT / "data" / "veilleurs" / "v06"

BINDING_FILES = [
    "interactions_khar_sen_v1.json",
    "interactions_buried_galleries_v1.json",
    "interactions_fractured_sanctuary_v1.json",
    "interactions_abandoned_quarters_v1.json",
    "interactions_black_quarry_v1.json",
    "interactions_memory_rift_v1.json",
]


def load(name):
    return json.loads((V06 / name).read_text(encoding="utf-8"))


def room_map(content):
    fields = content["record_fields"]
    return {row[0]: dict(zip(fields, row)) for row in content["rooms"]}


def gold_token_mean(token):
    if not token.startswith("or_"):
        return 0.0
    _, low, high = token.split("_")
    return (int(low) + int(high)) / 2.0


def loot_gold_mean(table):
    total = sum(gold_token_mean(token) for token in table["guaranteed"])
    total += sum(gold_token_mean(token) * chance for token, chance in table["independent_rolls"])
    return total


def route_gold(content, rooms):
    by_room = room_map(content)
    return round(sum(loot_gold_mean(content["loot_tables"][by_room[r]["loot_table"]]) for r in rooms), 3)


def test_balance_profiles_cover_exactly_all_59_rooms():
    content = load("dungeon_room_content_catalog_v1.json")
    balance = load("dungeon_balance_v1.json")
    content_ids = {row[0] for row in content["rooms"]}
    balance_ids = {row[0] for row in balance["room_profiles"]}
    assert len(content_ids) == 59
    assert balance_ids == content_ids
    assert all(profile in balance["balance_profiles"] for _, profile in balance["room_profiles"])


def test_composition_weights_and_anti_repeat_are_locked():
    balance = load("dungeon_balance_v1.json")
    selection = balance["composition_selection"]
    for key in ("first_visit_weights", "after_A_weights", "after_B_weights"):
        assert abs(sum(selection[key].values()) - 1.0) < 1e-9
    assert selection["max_same_composition_consecutive_visits"] == 2
    assert balance["anti_repetition"]["same_visual_variant_max_consecutive_visits"] == 2
    assert balance["anti_repetition"]["persistent_state_always_overrides_anti_repetition"] is True


def test_declared_route_gold_means_still_match_current_loot_tables():
    content = load("dungeon_room_content_catalog_v1.json")
    balance = load("dungeon_balance_v1.json")
    targets = {row["slice"]: row["expected_gold_route_means"] for row in balance["dungeon_targets"]}
    routes = {
        "SLICE_KHAR_SEN_01": [
            ["KHAR_01","KHAR_02","KHAR_03","KHAR_05","KHAR_06","KHAR_08","KHAR_09"],
            ["KHAR_01","KHAR_02","KHAR_04","KHAR_05","KHAR_06","KHAR_08","KHAR_09"],
            ["KHAR_01","KHAR_02","KHAR_03","KHAR_05","KHAR_06","KHAR_07","KHAR_09"],
            ["KHAR_01","KHAR_02","KHAR_04","KHAR_05","KHAR_06","KHAR_07","KHAR_09"],
        ],
        "REF_BURIED_GALLERIES_01": [
            ["BG_01","BG_02","BG_03","BG_04","BG_05","BG_07","BG_08","BG_09"],
            ["BG_01","BG_02","BG_03","BG_04","BG_05","BG_06","BG_08","BG_09"],
        ],
        "REF_FRACTURED_SANCTUARY_01": [
            ["FS_01","FS_02","FS_03","FS_04","FS_05","FS_08","FS_09","FS_10"],
            ["FS_01","FS_02","FS_03","FS_04","FS_06","FS_07","FS_08","FS_09","FS_10"],
        ],
        "REF_ABANDONED_QUARTERS_01": [
            ["AQ_01","AQ_02","AQ_03","AQ_04","AQ_05","AQ_07","AQ_08","AQ_09"],
            ["AQ_01","AQ_02","AQ_03","AQ_04","AQ_06","AQ_07","AQ_08","AQ_09"],
        ],
        "REF_BLACK_QUARRY_01": [
            ["BQ_01","BQ_02","BQ_03","BQ_04","BQ_05","BQ_06","BQ_08","BQ_09","BQ_10"],
            ["BQ_01","BQ_02","BQ_03","BQ_04","BQ_05","BQ_07","BQ_08","BQ_09","BQ_10"],
        ],
        "REF_MEMORY_RIFT_01": [
            ["MR_01","MR_02","MR_03","MR_04","MR_06","MR_07","MR_08","MR_09","MR_10","MR_11","MR_12"],
            ["MR_01","MR_02","MR_03","MR_04","MR_05","MR_08","MR_09","MR_10","MR_11","MR_12"],
        ],
    }
    for slice_id, slice_routes in routes.items():
        actual = sorted(route_gold(content, route) for route in slice_routes)
        expected = sorted(round(v, 3) for v in targets[slice_id])
        assert actual == expected


def test_interaction_bindings_cover_every_declared_event_exactly_once():
    content = load("dungeon_room_content_catalog_v1.json")
    rooms = room_map(content)
    declared = {(room_id, event) for room_id, room in rooms.items() for event in room["events"]}
    bindings = []
    for name in BINDING_FILES:
        data = load(name)
        assert data["count"] == len(data["bindings"])
        bindings.extend(data["bindings"])
    bound = {(row[0], row[1]) for row in bindings}
    assert len(bindings) == 119
    assert len(bound) == 119
    assert bound == declared


def test_interaction_outcomes_and_microtexts_resolve():
    library = load("dungeon_interaction_outcome_library_v1.json")
    valid = set(library["outcomes"])
    for name in BINDING_FILES:
        for room_id, interaction_id, outcome_code, microtext in load(name)["bindings"]:
            assert room_id and interaction_id
            assert outcome_code in valid
            assert isinstance(microtext, str) and microtext.strip()
    assert library["rules"]["critical_sockets_immutable"] is True
    assert library["rules"]["objectives_extraction_never_hidden"] is True
    assert library["rules"]["single_use_rewards_nonfarmable"] is True


def test_boss_fragments_are_claims_not_duplicate_rewards():
    library = load("dungeon_interaction_outcome_library_v1.json")
    effects = " ".join(library["outcomes"]["BOSS_REWARD"][1])
    assert "already-guaranteed boss_progression_fragment" in effects


def test_balancing_never_converts_progression_value_to_gold():
    balance = load("dungeon_balance_v1.json")
    economy = balance["economy_model"]
    assert economy["gold_is_not_equalized_between_routes"] is True
    assert "never converted to spendable gold" in economy["note"]
    assert balance["telemetry_acceptance"]["seed_batch_minimum"] >= 500
