import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "data/audio/source_sfx_library.json"
REGISTRY = ROOT / "data/audio/source_sfx_registry.json"
TOOL = ROOT / "tools/audio/source_sfx_library.py"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def test_source_library_targets_1800_material_sounds():
    data = load(CONTRACT)
    assert data["acceptable_source_count"] == [1000, 3000]
    assert data["target_source_count"] == 1800
    assert sum(category["target"] for category in data["categories"].values()) == 1800
    assert len(data["categories"]) == 12


def test_raw_and_working_sources_stay_out_of_public_repo():
    data = load(CONTRACT)
    policy = data["repository_policy"]
    assert policy["raw_sources_are_local_only"] is True
    assert policy["working_derivatives_are_local_only"] is True
    assert policy["never_vendor_private_royalty_free_source_files"] is True
    gitignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
    assert "local/audio_library/" in gitignore


def test_licence_gate_blocks_unknown_and_noncommercial_material():
    policy = load(CONTRACT)["license_policy"]
    assert "OWN_RECORDING" in policy["green"]
    assert "CC0" in policy["green"]
    assert "CC-BY" in policy["green"]
    assert "ROYALTY_FREE_NO_REDISTRIBUTION" in policy["private_only"]
    assert "CC-BY-NC" in policy["blocked"]
    assert "UNKNOWN" in policy["blocked"]
    assert policy["commercial_use_required"] is True
    assert policy["derivative_work_permission_required"] is True


def test_seed_registry_reuses_only_already_verified_cc0_metadata():
    registry = load(REGISTRY)
    assert len(registry["sources"]) == 6
    assert all(source["license"] == "CC0" for source in registry["sources"])
    assert all(source["status"] == "metadata_seed_binary_not_ingested" for source in registry["sources"])
    assert all(source["sha256"] == "PENDING_LOCAL_INGEST" for source in registry["sources"])
    assert {source["provider"] for source in registry["sources"]} == {"OpenGameArt"}


def test_library_audit_cli_passes_without_private_binaries():
    completed = subprocess.run(
        [sys.executable, str(TOOL), "audit"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    assert completed.returncode == 0, completed.stdout + completed.stderr
    assert "SOURCE_SFX_LIBRARY_AUDIT_OK" in completed.stdout


def test_derivative_contract_keeps_lineage_and_variants():
    derivative = load(CONTRACT)["derivative_schema"]
    assert derivative["lineage_required"] is True
    assert derivative["minimum_variants_per_repeating_cue"] >= 4
    assert derivative["recommended_variants_per_footstep_material"] >= 8
    assert "layer" in derivative["recipe_operations"]
    assert "pitch" in derivative["recipe_operations"]
