from pathlib import Path
import subprocess

ROOT = Path(__file__).parents[1]

FORBIDDEN_OBSOLETE_PATHS = (
    "00_LIRE_AVANT_IMPORT_WORKING_COPY.md",
    "WORKING_COPY_IMPORT_READY.txt",
    "docs/SPRINT_1_ACCEPTANCE.md",
    "docs/TEST_REPORT.md",
    "docs/MIGRATION_STATUS.md",
    "docs/GITHUB_SETUP.md",
    "docs/FILE_MANIFEST.json",
)

FORBIDDEN_TRACKED_NAMES = {".DS_Store"}
FORBIDDEN_TRACKED_SUFFIXES = (".bak", ".orig", ".tmp")
FORBIDDEN_README_MARKERS = (
    "Studio Sprint 1",
    "docs/GITHUB_SETUP.md",
    "Limites du Sprint 1",
    "Premier envoi sur GitHub",
)


def _tracked_files() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def test_confirmed_obsolete_files_do_not_return():
    for relative_path in FORBIDDEN_OBSOLETE_PATHS:
        assert not (ROOT / relative_path).exists(), relative_path


def test_no_transient_editor_or_backup_files_are_tracked():
    for relative_path in _tracked_files():
        path = Path(relative_path)
        assert path.name not in FORBIDDEN_TRACKED_NAMES, relative_path
        assert not relative_path.endswith(FORBIDDEN_TRACKED_SUFFIXES), relative_path


def test_readme_does_not_reference_retired_bootstrap_material():
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    for marker in FORBIDDEN_README_MARKERS:
        assert marker not in readme, marker
