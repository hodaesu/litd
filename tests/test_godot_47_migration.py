import json
from pathlib import Path

ROOT = Path(__file__).parents[1]
ENGINE_FAMILY = "4.7"
CI_IMAGE = "barichello/godot-ci:4.7.2"

WORKFLOWS = [
    ".github/workflows/ci.yml",
    ".github/workflows/remanence-smoke.yml",
    ".github/workflows/veilleurs-production-automation.yml",
    ".github/workflows/veilleurs-v06.yml",
    ".github/workflows/veilleurs-v07-production.yml",
    ".github/workflows/veilleurs-v08-wave2.yml",
    ".github/workflows/veilleurs-v09-wave3.yml",
    ".github/workflows/build.yml",
    ".github/workflows/nightly.yml",
]

ACTIVE_VERSION_FILES = [
    "project.godot",
    "data/veilleurs/pre_pc_gate.json",
    "tools/godot/veilleurs_pipeline_config.json",
    "tools/workstation/veilleurs_pc_preflight.py",
    "tools/qa/veilleurs_pre_pc_audit.py",
    *WORKFLOWS,
]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def load(path: str) -> dict:
    return json.loads(read(path))


def test_project_contract_and_pipeline_lock_godot_47():
    assert 'config/features=PackedStringArray("4.7")' in read("project.godot")
    assert load("data/veilleurs/pre_pc_gate.json")["godot_version"] == ENGINE_FAMILY
    assert load("tools/godot/veilleurs_pipeline_config.json")["godot_version"] == ENGINE_FAMILY


def test_pc_preflight_accepts_any_godot_47_patch_release():
    preflight = read("tools/workstation/veilleurs_pc_preflight.py")
    assert 'godot_compatible = "4.7" in godot_version' in preflight
    assert '"godot_47_compatible": godot_compatible' in preflight
    assert "Godot_v4.7.2-stable_win64.exe" in preflight


def test_all_active_godot_ci_jobs_use_472():
    for path in WORKFLOWS:
        workflow = read(path)
        assert CI_IMAGE in workflow, path
        assert "barichello/godot-ci:4.3" not in workflow, path


def test_no_active_43_version_lock_remains():
    forbidden = (
        'config/features=PackedStringArray("4.3")',
        '"godot_version": "4.3"',
        "barichello/godot-ci:4.3",
        "Godot_v4.3-stable_win64",
        "Godot 4.3",
    )
    for path in ACTIVE_VERSION_FILES:
        text = read(path)
        for marker in forbidden:
            assert marker not in text, f"{path}: stale marker {marker}"


def test_android_export_template_matches_pinned_ci_patch():
    workflow = read(".github/workflows/veilleurs-production-automation.yml")
    assert "export_templates/4.7.2.stable" in workflow
    assert "editor_settings-4.7.tres" in workflow
