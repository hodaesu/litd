import json
from pathlib import Path

import pytest


PACK = Path("docs/LITD2/REMANENCE_PRODUCTION_PACK.md")
MANIFEST = Path("unreal/LITD2/Data/Remanence/archive_asset_manifest.json")
MATRIX = Path("unreal/LITD2/Data/Remanence/archive_validation_matrix.json")
AUDIO = Path("unreal/LITD2/Data/Remanence/archive_audio_direction.json")
README = Path("unreal/LITD2/README.md")


@pytest.mark.data
def test_remanence_production_pack_is_litd2_only_and_defines_done() -> None:
    text = PACK.read_text(encoding="utf-8")
    assert "LITD 2 uniquement" in text
    assert "Ne pas importer" in text
    assert "Définition de terminé" in text
    for status in ("TODO", "READY", "IMPLEMENTED", "VALIDATED", "BLOCKED"):
        assert f"`{status}`" in text


@pytest.mark.data
def test_required_archive_assets_have_unique_ids_and_valid_statuses() -> None:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assert data["game"] == "LITD2"
    allowed = set(data["allowed_statuses"])
    assets = data["assets"]
    ids = [asset["asset_id"] for asset in assets]
    names = [asset["canonical_name"] for asset in assets]
    assert len(ids) == len(set(ids))
    assert len(names) == len(set(names))
    assert all(asset["status"] in allowed for asset in assets)
    assert any(asset["required"] for asset in assets)


@pytest.mark.data
def test_manifest_contains_core_material_audio_ui_and_font_contracts() -> None:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    by_name = {asset["canonical_name"]: asset for asset in data["assets"]}
    required_names = {
        "M_Remanence_Line",
        "M_Remanence_NodeGlow",
        "M_Remanence_Contradiction",
        "M_Remanence_ReconstructionPulse",
        "WBP_RemembranceArchive",
        "SFX_RemArchive_Open",
        "SFX_RemArchive_Select",
        "SFX_RemArchive_Contradiction",
        "SFX_RemArchive_Reconstruct",
        "Remanence_Title",
        "Remanence_UI",
        "Remanence_Body",
    }
    assert required_names <= set(by_name)
    assert by_name["WBP_RemembranceArchive"]["status"] == "IMPLEMENTED"
    for font_name in ("Remanence_Title", "Remanence_UI", "Remanence_Body"):
        assert by_name[font_name]["status"] == "BLOCKED"
        assert "licence" in by_name[font_name]["blocker"].lower()


@pytest.mark.data
def test_audio_manifest_cues_resolve_to_audio_direction() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    audio = json.loads(AUDIO.read_text(encoding="utf-8"))
    cue_ids = {cue["cue_id"] for cue in audio["cues"]}
    sound_assets = [asset for asset in manifest["assets"] if asset["type"] == "Sound"]
    assert len(sound_assets) == 4
    for asset in sound_assets:
        assert asset["cue_id"] in cue_ids


@pytest.mark.data
def test_validation_matrix_covers_resolutions_interaction_audio_and_rights() -> None:
    data = json.loads(MATRIX.read_text(encoding="utf-8"))
    assert data["game"] == "LITD2"
    checks = data["checks"]
    ids = [check["check_id"] for check in checks]
    assert len(ids) == len(set(ids))
    assert all(check["status"] == "TODO" for check in checks)
    assert {check["target"] for check in checks if check["group"] == "Resolution"} == {
        "1920x1080",
        "2560x1440",
        "3840x2160",
    }
    groups = {check["group"] for check in checks}
    for group in ("Interaction", "Readability", "ContentFlow", "Audio", "Performance", "ArtDirection", "Architecture", "Rights"):
        assert group in groups
    assert all(check["pass_condition"] for check in checks)


@pytest.mark.data
def test_litd2_readme_links_official_production_contracts() -> None:
    text = README.read_text(encoding="utf-8")
    assert "REMANENCE_PRODUCTION_PACK.md" in text
    assert "archive_asset_manifest.json" in text
    assert "archive_validation_matrix.json" in text
