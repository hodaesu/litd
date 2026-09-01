import json
from pathlib import Path

import pytest


SEED_PATH = Path("unreal/LITD2/Data/Remanence/sarei_seed.json")
LAYOUT_PATH = Path("unreal/LITD2/Data/Remanence/sarei_ui_layout.json")
AUDIO_PATH = Path("unreal/LITD2/Data/Remanence/archive_audio_direction.json")
HEADER_PATH = Path(
    "unreal/LITD2/Source/LITD2/Remanence/UI/LITD2RemembranceArchiveScreen.h"
)
CPP_PATH = Path(
    "unreal/LITD2/Source/LITD2/Remanence/UI/LITD2RemembranceArchiveScreen.cpp"
)
UI_LIBRARY_PATH = Path(
    "unreal/LITD2/Source/LITD2/Remanence/UI/LITD2RemembranceUILibrary.cpp"
)
BUILD_PATH = Path("unreal/LITD2/Source/LITD2/LITD2.Build.cs")
GENERATOR_PATH = Path("unreal/LITD2/Content/Python/build_remanence_ui.py")


@pytest.mark.data
def test_remanence_layout_covers_every_sarei_entry_once() -> None:
    seed = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    layout = json.loads(LAYOUT_PATH.read_text(encoding="utf-8"))

    seed_ids = [entry["entry_id"] for entry in seed["entries"]]
    layout_ids = [node["entry_id"] for node in layout["nodes"]]

    assert len(layout_ids) == len(set(layout_ids))
    assert set(layout_ids) == set(seed_ids)
    assert layout["branch_id"] == seed["branch_id"]


@pytest.mark.data
def test_remanence_layout_stays_inside_safe_normalized_graph_area() -> None:
    layout = json.loads(LAYOUT_PATH.read_text(encoding="utf-8"))
    for node in layout["nodes"]:
        assert 0.04 <= node["x"] <= 0.96, node
        assert 0.06 <= node["y"] <= 0.94, node


@pytest.mark.data
def test_native_archive_screen_contract_contains_required_interactions() -> None:
    header = HEADER_PATH.read_text(encoding="utf-8")
    cpp = CPP_PATH.read_text(encoding="utf-8")

    for token in (
        "NativePaint",
        "NativeOnMouseButtonDown",
        "NativeOnMouseMove",
        "NativeOnMouseWheel",
        "TryReconstructAvailable",
        "ReconstructionPulseSeconds",
    ):
        assert token in header or token in cpp

    assert "DrawDashedLine" in cpp
    assert "CONTRADICTION DÉTECTÉE" in cpp
    assert "ARCHIVES DE RÉMANENCE" in cpp
    assert "RECONSTRUIRE" in cpp


@pytest.mark.data
def test_archive_final_presentation_has_threads_ash_dossier_and_reveal() -> None:
    header = HEADER_PATH.read_text(encoding="utf-8")
    cpp = CPP_PATH.read_text(encoding="utf-8")

    for token in (
        "ThreadRevealDuration",
        "DossierTransitionDuration",
        "KnowledgeRevealDuration",
        "EntryRevealSeconds",
        "KnowledgeRevealSeconds",
        "AshMoteCount",
        "DrawThread",
        "CONNAISSANCE RECONSTRUITE",
        "ArchiveAgeSeconds",
    ):
        assert token in header or token in cpp

    for token in (
        "OpenSound",
        "SelectionSound",
        "ContradictionSound",
        "ReconstructionSound",
    ):
        assert token in header
    assert "UGameplayStatics::PlaySound2D" in cpp


@pytest.mark.data
def test_archive_audio_direction_matches_runtime_slots_and_rights_policy() -> None:
    audio = json.loads(AUDIO_PATH.read_text(encoding="utf-8"))
    assert audio["game"] == "LITD2"
    assert audio["system"] == "RemanenceArchive"
    assert audio["rights_rule"] == "LITD_ORIGINAL_REUSABLE_OR_LICENSED_REUSABLE_ONLY"

    slots = {cue["slot"] for cue in audio["cues"]}
    assert slots == {"OpenSound", "SelectionSound", "ContradictionSound", "ReconstructionSound"}
    assert all(cue["duration_seconds"][1] <= 2.0 for cue in audio["cues"])


@pytest.mark.data
def test_archive_has_blueprint_open_close_entry_points() -> None:
    ui_library = UI_LIBRARY_PATH.read_text(encoding="utf-8")
    assert "OpenRemanenceArchive" in ui_library
    assert "CloseRemanenceArchive" in ui_library
    assert "AddToViewport" in ui_library
    assert "FInputModeGameAndUI" in ui_library
    assert "FInputModeGameOnly" in ui_library


@pytest.mark.data
def test_litd2_module_declares_umg_slate_json_and_stages_archive_data() -> None:
    build = BUILD_PATH.read_text(encoding="utf-8")
    for module in ("UMG", "Slate", "SlateCore", "Json", "InputCore"):
        assert f'"{module}"' in build
    assert "sarei_seed.json" in build
    assert "sarei_ui_layout.json" in build
    assert "archive_audio_direction.json" in build


@pytest.mark.data
def test_umg_generator_targets_native_archive_parent() -> None:
    generator = GENERATOR_PATH.read_text(encoding="utf-8")
    assert 'ASSET_NAME = "WBP_RemembranceArchive"' in generator
    assert 'PARENT_CLASS_PATH = "/Script/LITD2.LITD2RemembranceArchiveScreen"' in generator
    assert "WidgetBlueprintFactory" in generator
