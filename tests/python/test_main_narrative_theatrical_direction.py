import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIRECTION = ROOT / "data/narrative/main_script/theatrical_direction.json"
MANIFEST = ROOT / "data/narrative/main_script/manifest.json"
RUNTIME = ROOT / "scripts/core/main_narrative_script_runtime.gd"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def test_theatrical_direction_is_authored_and_cycle_zero_only():
    data = load(DIRECTION)
    assert data["scope"] == "LITD1 cycle initial main narrative"
    assert data["rules"]["authored_only"] is True
    assert data["rules"]["no_runtime_improvisation"] is True
    assert data["rules"]["dialogue_text_unchanged"] is True
    assert data["rules"]["created_player_has_no_forced_voice_or_body_language"] is True


def test_core_actor_profiles_have_complete_performance_fields():
    data = load(DIRECTION)
    required = {"emotion", "posture", "gaze", "gesture", "breath", "voice", "subtext", "script_note"}
    core = [
        "nara_vey", "sela_mor", "meira_sen", "orren_taal", "bram_torgun",
        "veyra_oss", "eline_sar", "saen", "edras_nhal", "toma_rei", "sana_khel",
    ]
    actors = data["actors"]
    for actor_id in core:
        assert actor_id in actors
        assert required.issubset(actors[actor_id].keys())
        assert actors[actor_id]["script_note"].startswith("(")
        assert actors[actor_id]["script_note"].endswith(")")


def test_all_ten_chapters_have_a_physical_and_emotional_profile():
    data = load(DIRECTION)
    profiles = data["chapter_profiles"]
    expected = {
        "chapter_01_ashlands", "chapter_02_before_fall", "chapter_03_threshold",
        "chapter_04_first_rupture", "chapter_05_great_closure", "chapter_06_absent",
        "chapter_07_living_responsible", "chapter_08_outer_world",
        "chapter_09_veil_nature", "chapter_10_final_choice",
    }
    assert set(profiles) == expected
    for profile in profiles.values():
        assert profile["emotion"].strip()
        assert profile["physical_tone"].strip()
        assert profile["note"].strip()


def test_major_scenes_have_specific_blocking_overrides():
    data = load(DIRECTION)
    overrides = data["scene_overrides"]
    required = {
        "c01_opening_refuge", "c01_boss_witness", "c03_bram_abort", "c03_veyra_fragment",
        "c04_boss_unfinished_chorus", "c05_closure_map", "c06_saen_first_contact",
        "c06_closing_rights_without_ontology", "c07_bram_refuge", "c07_veyra_monastery",
        "c07_boss_edras", "c07_pretrial_conflict", "c08_varkhane_marshal",
        "c08_azravel_saint", "c09_veyra_limit", "c09_no_final_answer",
        "c10_opening_assembly", "c10_boss_common_rupture", "c10_final_deliberation",
        "c10_closing_light",
    }
    assert required.issubset(overrides.keys())
    for scene_id in required:
        assert overrides[scene_id]["emotion"].strip()
        assert overrides[scene_id]["blocking"].strip()


def test_runtime_attaches_direction_to_scenes_dialogue_and_choice_responses():
    runtime = RUNTIME.read_text(encoding="utf-8")
    assert 'THEATRICAL_DIRECTION_PATH := "res://data/narrative/main_script/theatrical_direction.json"' in runtime
    assert "func theatrical_scene_direction(" in runtime
    assert "func performance_for_line(" in runtime
    assert 'scene_payload["theatrical_direction"]' in runtime
    assert 'payload["performance"] = performance_for_line(' in runtime
    assert 'prepared["performance"] = performance_for_line(' in runtime


def test_manifest_makes_theatrical_direction_part_of_production_contract():
    manifest = load(MANIFEST)
    assert manifest["schema_version"] >= 2
    assert manifest["theatrical_direction"] == "res://data/narrative/main_script/theatrical_direction.json"
    contract = manifest["scene_contract"]
    assert "theatrical_rule" in contract
    assert "posture" in contract["theatrical_rule"]
    assert "sous-texte" in contract["theatrical_rule"]
    assert "didascalie" in contract["theatrical_rule"]


def test_player_is_never_given_authored_emotion_or_posture():
    data = load(DIRECTION)
    corpus = json.dumps(data, ensure_ascii=False).lower()
    assert '"player"' not in data["actors"]
    assert '"protagoniste"' not in data["actors"]
    assert "created_player_has_no_forced_voice_or_body_language" in corpus
