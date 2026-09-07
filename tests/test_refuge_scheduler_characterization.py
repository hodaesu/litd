import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V06 = ROOT / "data" / "veilleurs" / "v06"


def load(name):
    return json.loads((V06 / name).read_text(encoding="utf-8"))


def test_scheduler_uses_authoritative_49_scene_catalog():
    scheduler = load("refuge_event_scheduler_v1.json")
    catalog = load("refuge_event_catalog_v2.json")
    assert scheduler["authoritative_event_count"] == catalog["total_active_events"] == 49
    assert scheduler["event_catalog"].endswith("refuge_event_catalog_v2.json")


def test_scheduler_binds_voice_reaction_chain_and_staging_contracts():
    scheduler = load("refuge_event_scheduler_v1.json")
    paths = [
        scheduler["characterization_contracts"]["veilleur_voices"],
        scheduler["characterization_contracts"]["recruit_reactions"],
        scheduler["chain_contract"],
        scheduler["staging_contract"],
    ]
    for path in paths:
        assert (ROOT / path).exists(), path
    assert scheduler["casting"]["nonverbal_profile_never_receives_full_human_dialogue"] is True
    assert scheduler["selection"]["pending_chain_act_is_never_forced_if_trigger_or_actor_is_invalid"] is True


def test_reload_preserves_cast_staging_and_chain_state():
    scheduler = load("refuge_event_scheduler_v1.json")
    persisted = set(scheduler["save_resume"]["persist"])
    assert {"active_chain_states", "cast_entity_ids", "staging_profile_id"} <= persisted
    assert "same active event, cast, staging and options" in scheduler["save_resume"]["reload_rule"]


def test_telemetry_watches_characterization_distribution():
    scheduler = load("refuge_event_scheduler_v1.json")
    report = set(scheduler["telemetry"]["report"])
    assert {"voice_cast_frequency", "recruit_profile_frequency", "chain_completion_rate", "staging_profile_frequency"} <= report
    assert scheduler["telemetry"]["fail_if_catalog_event_has_no_staging_binding"] is True
    assert scheduler["telemetry"]["fail_if_illegal_recruit_profile_grants_recruitability"] is True
