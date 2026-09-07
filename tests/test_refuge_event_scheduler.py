import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V06 = ROOT / "data" / "veilleurs" / "v06"


def load(name):
    return json.loads((V06 / name).read_text(encoding="utf-8"))


def test_scheduler_sources_all_three_event_libraries():
    data = load("refuge_event_scheduler_v1.json")
    assert data["source_libraries"] == [
        "data/veilleurs/v06/refuge_events_social_v1.json",
        "data/veilleurs/v06/refuge_events_knowledge_v1.json",
        "data/veilleurs/v06/refuge_events_state_v1.json",
    ]


def test_scheduler_is_deterministic_and_bounded_for_mobile():
    data = load("refuge_event_scheduler_v1.json")
    assert data["seed_components"] == ["campaign_seed", "return_index", "story_epoch", "refuge_state", "event_history_hash"]
    selection = data["selection"]
    assert selection["max_auto_presented_on_arrival"] == 2
    assert selection["max_total_new_events_queued_per_return"] == 5
    assert selection["max_social_events_selected_per_return"] == 2
    assert selection["max_debate_events_selected_per_return"] == 1
    assert selection["same_event_max_consecutive_returns"] == 1
    assert selection["repeatable_event_default_cooldown_returns"] >= 2


def test_critical_and_state_events_cannot_be_lost_to_random_selection():
    data = load("refuge_event_scheduler_v1.json")
    selection = data["selection"]
    assert selection["critical_eligible_events_are_queued_before_random_selection"] is True
    assert selection["state_transition_event_always_queued_when_new_state_entered"] is True
    assert data["priority_order"][0] == "critical"


def test_save_reload_never_rerolls_active_event():
    data = load("refuge_event_scheduler_v1.json")
    save = data["save_resume"]
    assert save["save_before_presenting_event"] is True
    assert save["save_after_choice_resolution"] is True
    assert "active_event_id" in save["persist"]
    assert "active_choice_state" in save["persist"]
    assert "never reroll" in save["reload_rule"]


def test_scheduler_receives_committed_post_expedition_state():
    data = load("refuge_event_scheduler_v1.json")
    integration = data["interaction_with_post_expedition"]
    assert integration["queue_build_after"] == "SUMMARY"
    assert all(value is True for key, value in integration.items() if key != "queue_build_after")


def test_scheduler_telemetry_is_stricter_than_single_playthrough():
    data = load("refuge_event_scheduler_v1.json")
    telemetry = data["telemetry"]
    assert telemetry["minimum_simulated_returns"] >= 1000
    assert telemetry["fail_if_one_shot_repeats"] is True
    assert telemetry["fail_if_unresolved_event_rerolls_after_reload"] is True
