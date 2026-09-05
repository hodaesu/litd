import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HANDOFF = ROOT / "data" / "production" / "les_veilleurs_pre_pc_handoff.json"


def load_data():
    return json.loads(HANDOFF.read_text(encoding="utf-8"))


def test_pre_pc_handoff_declares_static_work_ready():
    data = load_data()
    assert data["status"] == "ready_for_pc_validation"
    completed = " ".join(data["completed_without_pc"])
    for term in ["Actes I-II", "Actes III-V", "Rémanence", "hub", "Copiste", "Godot", "tests Python"]:
        assert term in completed


def test_handoff_points_to_existing_static_contracts():
    data = load_data()
    contracts = data["static_contracts"]
    paths = [
        contracts["narrative_early"],
        contracts["narrative_late"],
        contracts["narrative_godot_catalog"],
        contracts["encounters"],
        contracts["recruitment"],
        contracts["pc_plan"],
        contracts["pc_orchestrator"],
        *contracts["bestiary"],
    ]
    for relative in paths:
        assert (ROOT / relative).exists(), relative


def test_only_runtime_perceptual_or_hardware_work_is_marked_pc_required():
    data = load_data()
    ids = {item["id"] for item in data["pc_required"]}
    assert {
        "godot_strict_import",
        "touch_validation",
        "pc_controls",
        "persistent_corpses_navigation",
        "combat_balance",
        "memoried_enemy_budget",
        "audio_haptics",
        "performance",
        "blender_art_gate",
        "windows_export",
    } == ids
    for item in data["pc_required"]:
        assert item["reason"]
        assert item["acceptance"]


def test_first_pc_commands_use_existing_orchestrator_and_art_gate():
    data = load_data()
    commands = data["first_pc_commands"]
    assert commands[0] == "py tools/build/pc_validation.py --execute --build-blender"
    assert commands[1].endswith("--approve-art")


def test_balance_values_are_not_pretended_locked_before_measurement():
    data = load_data()
    pending = " ".join(data["do_not_lock_before_measurement"]).lower()
    for term in ["dégâts", "précision", "cooldowns", "télégraphe", "densité", "convalescence", "mémoire ia", "audio", "lod"]:
        assert term in pending
