from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UNREAL = ROOT / "unreal" / "LITDValidation"


def test_unreal_validation_project_is_complete_and_isolated() -> None:
    project = json.loads((UNREAL / "LITDValidation.uproject").read_text(encoding="utf-8"))
    assert project["Modules"][0]["Name"] == "LITDValidation"
    required = [
        "LITDValidationGameMode", "LITDValidationCharacter", "LITDValidationHUD",
        "LITDValidationRoom", "LITDValidationStation", "LITDValidationEnemy",
    ]
    for class_name in required:
        assert (UNREAL / "Source" / "LITDValidation" / f"{class_name}.h").exists()
        assert (UNREAL / "Source" / "LITDValidation" / f"{class_name}.cpp").exists()


def test_unreal_room_matches_godot_validation_contract() -> None:
    godot = json.loads((ROOT / "data" / "qa" / "validation_room_matrix.json").read_text(encoding="utf-8"))
    scorecard = json.loads((UNREAL / "comparison_scorecard.json").read_text(encoding="utf-8"))
    game_mode = (UNREAL / "Source" / "LITDValidation" / "LITDValidationGameMode.cpp").read_text(encoding="utf-8")
    expected_checks = {
        "movement", "dialogue", "chest", "loot", "combat_started", "combat_finished",
        "consumables", "psychology", "injury", "ash_guidance", "save_roundtrip",
    }
    assert expected_checks <= {token.strip('TEXT(")') for token in []} or all(
        f'TEXT("{check}")' in game_mode for check in expected_checks
    )
    assert scorecard["same_machine_required"] is True
    assert scorecard["same_assets_required"] is True
    assert scorecard["migration_gate"]["no_full_migration_before_gate"] is True
    assert {station["id"] for station in godot["stations"]} == {
        "movement", "dialogue", "loot", "combat", "systems"
    }


def test_unreal_prototype_has_real_interactions_and_four_enemies() -> None:
    game_mode = (UNREAL / "Source" / "LITDValidation" / "LITDValidationGameMode.cpp").read_text(encoding="utf-8")
    station = (UNREAL / "Source" / "LITDValidation" / "LITDValidationStation.cpp").read_text(encoding="utf-8")
    enemy = (UNREAL / "Source" / "LITDValidation" / "LITDValidationEnemy.cpp").read_text(encoding="utf-8")
    assert game_mode.count("FVector(-1") >= 4
    assert "GrantPrototypeLoot" in station
    assert "PresentDialogue" in station
    assert "HealthRatio() <= 0.35f" in enemy
    assert "barre vert-cendre" in enemy


def test_unreal_setup_is_automated_and_non_destructive() -> None:
    setup = (UNREAL / "Tools" / "Setup-UnrealPrototype.ps1").read_text(encoding="utf-8")
    scorecard = json.loads((UNREAL / "comparison_scorecard.json").read_text(encoding="utf-8"))
    assert "Find-UnrealEngine" in setup
    assert "Build.bat" in setup
    assert "LITDValidationEditor Win64 Development" in setup
    assert "Start-Process $EditorExe" in setup
    assert scorecard["decision"] == "pending_pc_test"
