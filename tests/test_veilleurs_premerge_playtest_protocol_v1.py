import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "veilleurs"
MATRIX = DATA / "qa" / "premerge_playtest_matrix_v1.json"
DOC = ROOT / "docs" / "veilleurs" / "VEILLEURS_PR173_PREMERGE_PLAYTEST_V1.md"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_premerge_matrix_is_complete_and_unique():
    matrix = load(MATRIX)
    assert matrix["protocol_id"] == "VEILLEURS_PR173_PREMERGE_V1"
    assert matrix["pull_request"] == 173
    assert matrix["godot_version"] == "4.3"
    assert matrix["required_input_modes"] == [
        "windows_keyboard_mouse",
        "windows_gamepad",
        "windows_touch_emulation_landscape",
    ]
    assert matrix["merge_gate"]["max_open_blocker"] == 0
    assert matrix["merge_gate"]["max_open_reproducible_major_core"] == 0
    assert matrix["merge_gate"]["actual_ios_device_required_for_pr173"] is False
    assert matrix["merge_gate"]["actual_ios_device_required_for_mobile_alpha"] is True

    cases = matrix["cases"]
    assert len(cases) == 39
    case_ids = [case["id"] for case in cases]
    assert len(case_ids) == len(set(case_ids))
    assert all(case["severity_if_fail"] in matrix["severity"] for case in cases)
    assert all(case["merge_blocking"] for case in cases if case["severity_if_fail"] == "BLOCKER")

    expected_categories = {
        "preflight",
        "controls_ui",
        "khar_sen",
        "watchers",
        "intent_knowledge",
        "body_injuries",
        "remanence",
        "recruitment_refuge",
        "bosses",
        "save_load",
        "balance",
        "stability_performance",
    }
    assert {case["category"] for case in cases} == expected_categories
    required_case_ids = {
        "PRE-01",
        "CTRL-01", "CTRL-02", "CTRL-03", "CTRL-04",
        "KHAR-01", "KHAR-02", "KHAR-03", "KHAR-04", "KHAR-05",
        "WATCH-01", "WATCH-02", "WATCH-03", "WATCH-04",
        "INT-01", "INT-02", "INT-03",
        "BODY-01", "BODY-02", "BODY-03",
        "REM-01", "REM-02", "REM-03", "REM-04",
        "REC-01", "REC-02", "REC-03", "REC-04", "REC-05",
        "BOSS-01", "BOSS-02", "BOSS-03",
        "SAVE-01",
        "BAL-01", "BAL-03",
        "PERF-01",
    }
    assert required_case_ids.issubset(set(case_ids))


def test_playtest_quartet_matches_v06_canonical_watchers():
    matrix = load(MATRIX)
    watchers = load(DATA / "v06" / "watchers.json")["watchers"]
    canonical_names = [watcher["name_fr"] for watcher in watchers]
    assert matrix["canonical_watchers"] == canonical_names == [
        "Sahen Varo",
        "Mira Sen",
        "Narem Osh",
        "Ysra Nahal",
    ]
    assert not set(matrix["forbidden_legacy_watchers_in_v06"]) & set(canonical_names)


def test_khar_sen_playtest_cases_match_authored_slice():
    matrix = load(MATRIX)
    slice_data = load(DATA / "v06" / "dungeon_slice_01_khar_sen.json")
    assert slice_data["slice_id"] == "SLICE_KHAR_SEN_01"
    assert slice_data["seed"] == 606101
    nodes = {node["node_id"]: node for node in slice_data["nodes"]}
    assert set(nodes) == {f"KHAR_{index:02d}" for index in range(1, 10)}
    assert nodes["KHAR_03"]["archive_unlock"] == "CODEX_REMANENCE_FIRST_TRACE"
    assert nodes["KHAR_05"]["memoriel_required"] is True
    assert nodes["KHAR_06"]["choice"] == {"left": "KHAR_07", "right": "KHAR_08"}
    assert nodes["KHAR_09"]["objective"] == "recover_messenger_trace"
    assert slice_data["rules"]["retreat_preserves_consequences"] is True
    assert slice_data["rules"]["world_persistence"] == "seed + node flags + anchored scars"

    khar_cases = [case for case in matrix["cases"] if case["category"] == "khar_sen"]
    assert len(khar_cases) == 6
    assert sum(case["merge_blocking"] for case in khar_cases) >= 5


def test_remanence_and_recruitment_gates_match_production_contracts():
    matrix = load(MATRIX)
    remanence = load(DATA / "remanence_entity_contract_v1.json")
    recruitment = load(DATA / "recruitment_refuge_contract_v1.json")

    assert set(remanence["memory_ranks"]) == {"normal", "memorial", "veteran", "elite", "nemesis"}
    assert remanence["memory_ranks"]["nemesis"]["requires_shared_history"] is True
    assert remanence["memory_ranks"]["nemesis"]["hp_sponge_design_forbidden"] is True
    assert remanence["adaptation_guardrails"]["omniscient_learning_forbidden"] is True
    assert remanence["adaptation_guardrails"]["learn_only_from_experienced_events"] is True
    assert remanence["world_persistence"]["full_scene_snapshot_forbidden"] is True

    assert recruitment["rallying"]["capture_is_recruitment"] is False
    assert recruitment["rallying"]["injuries_reset_on_rally"] is False
    assert recruitment["rallying"]["display_capture_probability"] is False
    assert recruitment["rallying"]["bosses_recruitable"] is False
    assert recruitment["refuge"]["overflow_policy"] == "block_new_recruit_until_slot_is_freed"

    categories = Counter(case["category"] for case in matrix["cases"])
    assert categories["remanence"] == 4
    assert categories["recruitment_refuge"] == 5


def test_boss_playtest_gate_matches_five_boss_sixteen_phase_catalog():
    matrix = load(MATRIX)
    boss_catalog = load(DATA / "boss_phase_catalog_v1.json")
    assert boss_catalog["boss_count"] == 5
    assert boss_catalog["count"] == 16
    phases = Counter(record["boss"] for record in boss_catalog["records"])
    assert phases == {
        "Ishar, Gardien du Passage": 3,
        "Orateur Sans Voix": 3,
        "Mère des Veines": 3,
        "Porte-Cendres Blanc": 3,
        "Le Copiste": 4,
    }
    boss_cases = [case for case in matrix["cases"] if case["category"] == "bosses"]
    assert [case["id"] for case in boss_cases] == ["BOSS-01", "BOSS-02", "BOSS-03"]
    assert all(case["merge_blocking"] for case in boss_cases)


def test_human_protocol_documents_exact_merge_gate():
    text = DOC.read_text(encoding="utf-8")
    for required in [
        "0 BLOCKER ouvert",
        "0 MAJOR reproductible",
        "Sahen Varo",
        "Mira Sen",
        "Narem Osh",
        "Ysra Nahal",
        "KHAR_09",
        "Normal → Mémoriel → Vétéran → Élite → Némésis",
        "Capture ≠ recrutement",
        "Le Copiste",
        "actual",
    ]:
        if required == "actual":
            continue
        assert required in text
    assert "test sur iPhone physique" in text
    assert "non bloquant pour la fusion #173" in text
