import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENRICHMENT = ROOT / "data/narrative/base_game_enrichment.json"
SIDE_STORIES = ROOT / "data/narrative/base_game_side_stories.json"
VOICE_POLISH = ROOT / "data/narrative/base_game_voice_polish.json"
SIDE_RUNTIME = ROOT / "scripts/core/side_quest_runtime.gd"
ENRICHMENT_RUNTIME = ROOT / "scripts/core/base_game_enrichment_runtime.gd"
SAVE_MANAGER = ROOT / "scripts/core/save_manager.gd"
PROJECT = ROOT / "project.godot"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def test_chapters_2_to_10_have_two_strong_side_stories_each():
    stories = load(SIDE_STORIES)
    assert len(stories) == 18
    counts = Counter(int(story["available_chapter"]) for story in stories)
    assert counts == Counter({chapter: 2 for chapter in range(2, 11)})
    ids = [story["id"] for story in stories]
    assert len(ids) == len(set(ids))
    for story in stories:
        assert story["narrative_role"] == "side"
        assert len(story["objectives"]) >= 2
        assert story["narrative"]["hook"].strip()
        assert story["narrative"].get("offer_lines")
        assert story["narrative"].get("completion_lines")
        assert story.get("reward")
        for choice in story.get("choices", []):
            assert not choice["label"].startswith("«")


def test_side_stories_never_claim_to_be_required_for_main_plot():
    corpus = SIDE_STORIES.read_text(encoding="utf-8").lower()
    forbidden = [
        "obligatoire pour comprendre",
        "nécessaire pour comprendre",
        "requis pour débloquer le chapitre",
        "révélation principale obligatoire",
    ]
    for phrase in forbidden:
        assert phrase not in corpus


def test_enrichment_has_all_requested_layers_and_good_density():
    data = load(ENRICHMENT)
    assert data["scope"] == "LITD1 cycle initial only"
    assert data["rules"]["never_required_for_main_plot"] is True
    assert data["rules"]["created_player_has_no_forced_voice"] is True
    assert data["rules"]["ngplus_expansion_frozen"] is True
    assert len(data["optional_conversations"]) >= 20
    assert len(data["rare_reactions"]) >= 10
    assert len(data["expedition_banter"]) >= 10
    assert len(data["relationship_variants"]) >= 10


def test_optional_conversations_cover_every_main_chapter():
    data = load(ENRICHMENT)
    counts = Counter(int(entry["chapter"]) for entry in data["optional_conversations"])
    for chapter in range(1, 11):
        assert counts[chapter] >= 2, f"chapter {chapter} lacks optional conversations"


def test_enrichment_ids_are_unique_and_player_has_no_authored_voice():
    data = load(ENRICHMENT)
    all_entries = []
    for category in ["optional_conversations", "rare_reactions", "expedition_banter", "relationship_variants"]:
        all_entries.extend(data[category])
    ids = [entry["id"] for entry in all_entries]
    assert len(ids) == len(set(ids))
    forbidden_speakers = {"Protagoniste", "Joueur", "Player", "Hero", "Aurélien"}
    for entry in all_entries:
        assert entry.get("speaker") not in forbidden_speakers
        for line in entry.get("lines", []):
            if isinstance(line, dict):
                assert line.get("speaker") not in forbidden_speakers


def test_rare_reactions_and_banter_are_chapter_bounded():
    data = load(ENRICHMENT)
    for category in ["rare_reactions", "expedition_banter", "relationship_variants"]:
        chapters = {int(entry["chapter"]) for entry in data[category]}
        assert chapters.issubset(set(range(1, 11)))
    assert {int(entry["chapter"]) for entry in data["rare_reactions"]} == set(range(1, 11))
    assert {int(entry["chapter"]) for entry in data["expedition_banter"]} == set(range(1, 11))


def test_side_quest_runtime_loads_supplemental_cycle_zero_stories():
    runtime = SIDE_RUNTIME.read_text(encoding="utf-8")
    assert '"res://data/quests.json"' in runtime
    assert '"res://data/narrative/base_game_side_stories.json"' in runtime
    assert "func _quest_available(" in runtime
    assert "available_chapter" in runtime
    assert "func offered_quests_for_current_chapter(" in runtime


def test_enrichment_runtime_is_autoloaded_and_persistent():
    project = PROJECT.read_text(encoding="utf-8")
    runtime = ENRICHMENT_RUNTIME.read_text(encoding="utf-8")
    save = SAVE_MANAGER.read_text(encoding="utf-8")
    assert 'BaseGameEnrichmentRuntime="*res://scripts/core/base_game_enrichment_runtime.gd"' in project
    for func in ["request_optional", "request_rare", "request_banter", "request_relationship", "serialize", "deserialize"]:
        assert f"func {func}(" in runtime
    assert '"base_game_enrichment": BaseGameEnrichmentRuntime.serialize()' in save
    assert 'BaseGameEnrichmentRuntime.deserialize(payload.get("base_game_enrichment",{}))' in save


def test_pre_dubbing_contract_covers_core_recurring_cast():
    data = load(VOICE_POLISH)
    assert data["status"] == "pre_dubbing_ready_v1"
    assert data["global_rules"]["created_player_voice_is_never_authored"] is True
    names = {character["name"] for character in data["characters"]}
    expected = {"Nara Vey", "Sela Mor", "Meira Sen", "Orren Taal", "Bram Torgun", "Veyra Oss", "Eline Sar", "Saen"}
    assert expected.issubset(names)
    assert data["global_rules"]["target_spoken_line_words"]["hard_review_over"] <= 42
    assert len(data["pronunciation"]) >= 12
    assert len(data["scene_polish_rules"]) >= 6


def test_optional_dialogue_stays_spoken_and_not_essay_length():
    data = load(ENRICHMENT)
    too_long = []
    for category in ["optional_conversations", "rare_reactions", "expedition_banter", "relationship_variants"]:
        for entry in data[category]:
            texts = []
            if entry.get("text"):
                texts.append(entry["text"])
            for line in entry.get("lines", []):
                texts.append(line["text"] if isinstance(line, dict) else str(line))
            for text in texts:
                if len(text.split()) > 42:
                    too_long.append((entry["id"], text))
    assert not too_long, too_long
