import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_main_campaign_has_ten_ordered_chapters_with_quests_and_bosses():
    data = json.loads((ROOT / "data/world/main_campaign.json").read_text())
    chapters = data["chapters"]
    assert len(chapters) == 10
    assert [chapter["number"] for chapter in chapters] == list(range(1, 11))
    for chapter in chapters:
        assert chapter["title"].strip()
        assert chapter["premise"].strip()
        assert chapter["main_quests"]
        assert chapter["bosses"]
        assert chapter["end_revelation"].strip()


def test_campaign_preserves_reveal_order():
    data = json.loads((ROOT / "data/world/main_campaign.json").read_text())
    titles = [chapter["title"] for chapter in data["chapters"]]
    assert titles == [
        "Survivre aux Terres de Cendre",
        "Les traces d'avant la Chute",
        "Le Projet Seuil",
        "La Première Rupture",
        "Or-Silex et la Grande Fermeture",
        "Les Absents",
        "Les responsables vivants",
        "Le monde extérieur",
        "Ce qu'est réellement le Voile",
        "La lumière mérite d'être défendue",
    ]


def test_final_orientations_are_unlocked_by_previous_world_state():
    data = json.loads((ROOT / "data/world/main_campaign_endings.json").read_text())
    endings = {ending["id"]: ending for ending in data["endings"]}
    assert set(endings) == {
        "radical_closure",
        "stable_coexistence",
        "preserve_crossings",
        "seek_absent",
        "restore_concord",
        "transform_concord",
    }
    for ending in endings.values():
        assert ending["requirements"]
        assert ending["costs"]
        assert ending["best_form"].strip()
        assert ending["dark_form"].strip()


def test_campaign_runtime_is_persistent_and_evaluates_endings():
    runtime = (ROOT / "scripts/core/campaign_state.gd").read_text()
    for contract in (
        "func complete_main_quest(quest_id: String)",
        "func active_main_quests()",
        "func available_endings()",
        "func ending_score_context()",
        "PoliticalState.three_awakenings",
        "func serialize()",
        "func deserialize(payload: Dictionary)",
    ):
        assert contract in runtime


def test_campaign_is_autoloaded_reset_saved_and_shown_in_journal():
    project = (ROOT / "project.godot").read_text()
    game_state = (ROOT / "scripts/core/game_state.gd").read_text()
    save = (ROOT / "scripts/core/save_manager.gd").read_text()
    journal = (ROOT / "scripts/ui/quest_journal_ui.gd").read_text()
    assert 'CampaignState="*res://scripts/core/campaign_state.gd"' in project
    assert "CampaignState.reset_new_game()" in game_state
    assert 'SAVE_VERSION := "0.20"' in save
    assert '"campaign": CampaignState.serialize()' in save
    assert 'CampaignState.deserialize(payload.get("campaign", {}))' in save
    assert "CampaignState.current_chapter()" in journal
    assert "CampaignState.active_main_quests()" in journal
    assert "RÉVÉLATIONS CONFIRMÉES" in journal


def test_final_chapter_does_not_reduce_resolution_to_killing_a_god():
    data = json.loads((ROOT / "data/world/main_campaign.json").read_text())
    final = data["chapters"][-1]
    boss = final["bosses"][0]
    assert boss["name"] == "La Rupture Commune"
    assert boss["type"] == "final non nécessairement tuable"
    assert "crise" in boss["truth"].lower()
