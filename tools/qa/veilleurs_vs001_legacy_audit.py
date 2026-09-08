from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data/veilleurs/vs001_legacy_contract.json"
LEGACY_GLOB = "veilleurs_vs001_*.gd"


def _load_contract(root: Path) -> dict[str, Any]:
    path = root / "data/veilleurs/vs001_legacy_contract.json"
    return json.loads(path.read_text(encoding="utf-8"))


def _relative_paths(paths: list[Path], root: Path) -> set[str]:
    return {path.relative_to(root).as_posix() for path in paths}


def audit(root: Path = ROOT) -> dict[str, Any]:
    contract = _load_contract(root)
    errors: list[str] = []

    if contract.get("status") != "compatibility_only_pending_pc_validation":
        errors.append("VS001 status must remain compatibility_only_pending_pc_validation until the real PC migration gate is validated")

    declared_scripts = {entry["path"] for entry in contract.get("legacy_scripts", [])}
    actual_scripts = _relative_paths(
        sorted((root / "scripts/world").glob(LEGACY_GLOB)),
        root,
    )
    unmanaged_scripts = sorted(actual_scripts - declared_scripts)
    missing_scripts = sorted(declared_scripts - actual_scripts)
    if unmanaged_scripts:
        errors.append("unmanaged VS001 runtime scripts: " + ", ".join(unmanaged_scripts))
    if missing_scripts:
        errors.append("declared VS001 runtime scripts missing: " + ", ".join(missing_scripts))

    declared_scenes = list(contract.get("legacy_scenes", []))
    missing_scenes = [path for path in declared_scenes if not (root / path).is_file()]
    if missing_scenes:
        errors.append("declared VS001 compatibility scenes missing: " + ", ".join(missing_scenes))

    project_path = root / "project.godot"
    project_text = project_path.read_text(encoding="utf-8")
    missing_autoloads: list[str] = []
    for autoload_name, script_path in contract.get("autoloads", {}).items():
        if autoload_name not in project_text or script_path not in project_text:
            missing_autoloads.append(f"{autoload_name} -> {script_path}")
    gate = contract.get("deletion_gate", {})
    if gate.get("requires_real_pc_old_save_test") and not gate.get("validated") and missing_autoloads:
        errors.append("legacy autoload removed before PC old-save gate: " + ", ".join(missing_autoloads))

    canonical_vs001_refs: list[str] = []
    canonical_paths = set(contract.get("canonical_entry_points", []))
    scenes_root = root / "scenes/veilleurs"
    if scenes_root.is_dir():
        canonical_paths.update(
            path.relative_to(root).as_posix()
            for path in scenes_root.rglob("*")
            if path.is_file() and path.suffix.lower() in {".gd", ".tscn", ".tres"}
        )
    for relative in sorted(canonical_paths):
        path = root / relative
        if not path.is_file():
            errors.append(f"canonical entry point missing: {relative}")
            continue
        text = path.read_text(encoding="utf-8").lower()
        if "vs001" in text:
            canonical_vs001_refs.append(relative)
    if canonical_vs001_refs:
        errors.append("canonical v0.9/player surface depends on VS001: " + ", ".join(canonical_vs001_refs))

    if contract.get("legacy_save_key") != "veilleurs_vs001":
        errors.append("legacy save key contract changed unexpectedly")
    if contract.get("canonical_save_key") != "veilleurs":
        errors.append("canonical save key must remain 'veilleurs'")

    policy = contract.get("policy", {})
    if policy.get("new_vs001_runtime_files_allowed") is not False:
        errors.append("contract must forbid new VS001 runtime files")
    if policy.get("new_canonical_dependencies_on_vs001_allowed") is not False:
        errors.append("contract must forbid new canonical dependencies on VS001")
    if gate.get("validated") is False and policy.get("delete_legacy_runtime_before_pc_gate") is not False:
        errors.append("contract must forbid legacy runtime deletion before the PC migration gate")

    return {
        "ok": not errors,
        "errors": errors,
        "legacy_scripts_declared": len(declared_scripts),
        "legacy_scripts_actual": len(actual_scripts),
        "unmanaged_legacy_scripts": unmanaged_scripts,
        "missing_legacy_scripts": missing_scripts,
        "canonical_vs001_refs": canonical_vs001_refs,
        "pc_old_save_gate_validated": bool(gate.get("validated", False)),
    }


def main() -> int:
    result = audit()
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
