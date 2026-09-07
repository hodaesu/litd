import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V06 = ROOT / "data" / "veilleurs" / "v06"


def load(name):
    return json.loads((V06 / name).read_text(encoding="utf-8"))


def test_return_sequence_is_canonical_and_saved_stage_by_stage():
    data = load("post_expedition_loop_v1.json")
    assert data["return_sequence"] == ["RETURNED", "DEAD", "INJURIES", "KNOWLEDGE", "LOOT", "PROGRESSION", "WORLD_CHANGES", "SUMMARY"]
    assert data["rules"]["death_is_processed_before_statistics"] is True
    assert data["rules"]["save_after_each_stage"] is True
    assert data["rules"]["no_full_scene_snapshot"] is True


def test_refuge_capacity_team_and_no_magic_overflow():
    data = load("refuge_recovery_economy_v1.json")
    refuge = data["refuge"]
    assert refuge["active_capacity_by_level"] == [4, 6, 8, 10, 12]
    assert refuge["team_size_max"] == 4
    assert refuge["minimum_veilleurs_in_team"] == 1
    assert "magical_overflow_storage" in refuge["forbidden"]
    assert [u["to_capacity"] for u in refuge["capacity_upgrades"]] == [6, 8, 10, 12]
    assert all(u["gold"] > 0 and u["materials"] > 0 and u["requires"] for u in refuge["capacity_upgrades"])


def test_stabilization_is_free_but_consequences_persist():
    data = load("refuge_recovery_economy_v1.json")
    assert data["economy"]["rules"][2] == "life-saving stabilization is free"
    physical = data["physical_recovery"]
    for state in physical["on_return"].values():
        assert state["free_stabilization"] is True
    joined = " ".join(physical["care_rules"])
    assert "never erase recorded injury history" in joined
    assert "permanent anatomical record" in joined
    assert "changes function, not history" in joined


def test_only_gold_is_spendable_currency_and_knowledge_is_not_money():
    data = load("refuge_recovery_economy_v1.json")
    economy = data["economy"]
    assert economy["spendable_currency"] == "or"
    assert economy["knowledge_is_nonspendable_unlock_state"] is True
    assert "never ordinary shop currency" in economy["essence_role"]


def test_relationships_keep_four_independent_axes_and_release_identity():
    data = load("refuge_relationships_v1.json")
    assert set(data["axes"]) == {"TRUST", "RESPECT", "FEAR", "RESENTMENT"}
    assert all(axis["min"] == 0 and axis["max"] == 100 for axis in data["axes"].values())
    assert data["deployment_rules"]["fear_is_not_loyalty"] is True
    assert data["release"]["released_entity_remains_existing_and_addressable"] is True
    assert data["release"]["release_is_not_death"] is True
    assert data["death"]["permanent"] is True


def test_knowledge_progression_and_observation_limits():
    data = load("knowledge_archives_remanence_v1.json")
    assert data["knowledge_states"] == ["UNKNOWN", "SUSPECTED", "OBSERVED", "CONFIRMED", "UNDERSTOOD", "TRANSMITTED"]
    rules = data["rules"]
    assert rules["selecting_or_targeting_an_entity_reveals_nothing_by_itself"] is True
    assert rules["observation_only_records_what_was_actually_seen"] is True
    assert rules["knowledge_is_not_currency"] is True
    assert rules["archive_entries_distinguish_fact_hypothesis_memory_and_testimony"] is True


def test_all_knowledge_generating_interaction_outcomes_have_archive_routes():
    outcomes = load("dungeon_interaction_outcome_library_v1.json")["outcomes"]
    knowledge = load("knowledge_archives_remanence_v1.json")
    propagation = knowledge["interaction_outcome_propagation"]
    expected = {
        "OBSERVE_LORE", "READ_ARCHIVE", "BODY_TRACE", "MEMORY_BIND", "IDENTIFY_PERSON",
        "CIVILIAN_TALK", "OBSERVE_CIVILIAN", "TRACK_TRACE", "KNOWLEDGE_SYNTH",
        "IDENTIFY_SYMBOL", "MEMORY_LISTEN", "MEMORY_ANALYZE", "READ_NAMES", "READ_TRACE",
        "CIVILIAN_INFER", "INTEL_MAP", "TOUCH_SCAR", "PUZZLE_SOLVE", "FINAL_SCAR"
    }
    assert expected <= set(outcomes)
    assert expected <= set(propagation)
    assert all(propagation[code] for code in expected)


def test_knowledge_commit_precedes_loot_and_world_changes():
    loop = load("post_expedition_loop_v1.json")
    seq = loop["return_sequence"]
    assert seq.index("KNOWLEDGE") < seq.index("LOOT") < seq.index("WORLD_CHANGES")
    knowledge = load("knowledge_archives_remanence_v1.json")
    assert knowledge["return_commit"]["stage"] == "KNOWLEDGE"
    assert knowledge["return_commit"]["first_discovery_keeps_discoverer_entity_id"] is True
