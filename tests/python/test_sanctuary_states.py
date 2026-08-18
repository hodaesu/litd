import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_sanctuary_has_modular_states_including_absent_listening_room():
    data = json.loads((ROOT / "data/levels/sanctuary_state_layers.json").read_text())
    ids = {layer["id"] for layer in data["layers"]}
    assert ids == {
        "stable",
        "welcoming",
        "tense",
        "militarized",
        "impoverished",
        "creature_coexistence",
        "civic_reconstruction",
        "absent_listening",
        "fractured",
    }
    assert data["base_state"] == "stable"
    assert data["composition"]["max_simultaneous_major_layers"] == 3


def test_every_state_explains_visual_audio_and_population_changes():
    data = json.loads((ROOT / "data/levels/sanctuary_state_layers.json").read_text())
    for layer in data["layers"]:
        assert layer["visual"]
        assert layer["audio"]
        assert layer["population"]


def test_state_runtime_is_driven_by_politics_resources_and_campaign_flags():
    runtime = (ROOT / "scripts/core/sanctuary_state.gd").read_text()
    for contract in (
        "PoliticalState.tension",
        "PoliticalState.trust",
        "PoliticalState.three_awakenings",
        "GameState.supplies",
        "PoliticalState.is_flag_set",
        "CampaignState.chapter_flags",
        "campaign_any_flag",
        "func current_visual_cues()",
        "func current_audio_cues()",
        "func current_population_cues()",
        "func gameplay_modifiers()",
    ):
        assert contract in runtime


def test_sanctuary_state_is_in_quest_journal_not_large_sanctuary_banner():
    project = (ROOT / "project.godot").read_text()
    journal = (ROOT / "scripts/ui/quest_journal_ui.gd").read_text()
    assert 'SanctuaryState="*res://scripts/core/sanctuary_state.gd"' in project
    assert 'QuestJournalUI="*res://scripts/ui/quest_journal_ui.gd"' in project
    assert "SanctuaryStateUI" not in project
    assert not (ROOT / "scripts/ui/sanctuary_state_ui.gd").exists()
    assert '"JOURNAL"' in journal
    assert 'screen_name == "quest_journal"' in journal
    assert "SANCTUAIRE DU PREMIER VOILE" in journal
    assert "SanctuaryState.current_visual_cues()" in journal
    assert "SanctuaryState.current_audio_cues()" in journal
    assert "SanctuaryState.current_population_cues()" in journal


def test_states_cover_requested_player_consequences():
    data = json.loads((ROOT / "data/levels/sanctuary_state_layers.json").read_text())
    by_id = {layer["id"]: layer for layer in data["layers"]}
    assert "refugees_welcomed" in by_id["welcoming"]["when"]["any_flag"]
    assert by_id["tense"]["when"]["tension_min"] >= 50
    assert by_id["impoverished"]["when"]["supplies_max"] <= 4
    assert "creature_sanctuary_trial" in by_id["creature_coexistence"]["when"]["any_flag"]
    assert "city_min" in by_id["civic_reconstruction"]["when"]
    assert "sanctuary_listening_room_unlocked" in by_id["absent_listening"]["when"]["campaign_any_flag"]
    assert "trust_max" in by_id["fractured"]["when"]
