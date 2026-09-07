import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).parents[1]
CONTRACT_PATH = ROOT / "data/veilleurs/legacy/vs001_dependency_contract.json"


def _contract() -> dict:
    return json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))


def _tracked_files() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def _operational_vs001_references() -> list[str]:
    suffixes = {".gd", ".tscn", ".tres", ".json", ".py", ".yml", ".yaml", ".godot", ".cfg", ".sh", ".ps1", ".cmd"}
    hits: list[str] = []
    for relative in _tracked_files():
        path = ROOT / relative
        if path.suffix.lower() not in suffixes or not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore").lower()
        if "vs001" in text:
            hits.append(relative)
    return sorted(hits)


def _inside_legacy_namespace(path: str, prefixes: list[str]) -> bool:
    return any(path.startswith(prefix) for prefix in prefixes)


def test_declared_critical_legacy_dependencies_exist():
    contract = _contract()
    for group in ("runtime_critical", "persistence_critical", "project_bootstrap_critical", "qa_compatibility"):
        for relative in contract[group]:
            assert (ROOT / relative).exists(), f"missing declared VS001 dependency: {relative}"


def test_vs001_cannot_gain_new_external_consumers():
    contract = _contract()
    allowlist = set(contract["external_consumer_allowlist"])
    prefixes = list(contract["legacy_namespace_prefixes"])
    unexpected = [
        path
        for path in _operational_vs001_references()
        if path not in allowlist and not _inside_legacy_namespace(path, prefixes)
    ]
    assert unexpected == [], "VS001 leaked outside its compatibility boundary: " + ", ".join(unexpected)


def test_migration_has_explicit_removal_gates():
    contract = _contract()
    assert contract["status"] == "contained_active_compatibility"
    assert len(contract["migration_order"]) >= 5
    assert "zero VS001 autoloads in project.godot" in contract["removal_gates"]
    assert "old veilleurs_vs001 saves still load through explicit migration" in contract["removal_gates"]
