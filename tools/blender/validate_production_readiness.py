#!/usr/bin/env python3
"""Gate generated GLBs before they are staged for Godot import."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.blender.validate_character_glb import validate_character_glb
from tools.blender.validate_glb import read_glb_json, validate_glb

REGISTRY = ROOT / "data/blender/godot_import_registry.json"
BUDGETS = ROOT / "data/blender/production_budgets.json"


def validate_asset(path: Path, category: str, budget: dict) -> dict:
    if not path.exists():
        return {"status": "missing", "valid": False, "errors": ["GLB output is missing"], "stats": {}}
    report = validate_character_glb(path) if category == "characters" else validate_glb(path, require_lods=1, require_collision=True)
    errors = list(report.errors)
    try:
        document = read_glb_json(path)
        stats = {
            "size_mb": round(path.stat().st_size / (1024 * 1024), 3),
            "nodes": len(document.get("nodes", [])), "meshes": len(document.get("meshes", [])),
            "materials": len(document.get("materials", [])), "animations": len(document.get("animations", [])),
        }
        for field, maximum in budget.items():
            stat = "size_mb" if field == "max_glb_mb" else field.removeprefix("max_")
            if stat in stats and stats[stat] > maximum:
                errors.append(f"mobile budget exceeded: {stat} {stats[stat]} > {maximum}")
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        stats = {}
        if str(exc) not in errors:
            errors.append(str(exc))
    return {"status": "ready" if not errors else "blocked", "valid": not errors, "errors": errors, "stats": stats}


def build_report(root: Path = ROOT) -> dict:
    registry = json.loads((root / "data/blender/godot_import_registry.json").read_text(encoding="utf-8"))
    budgets = json.loads((root / "data/blender/production_budgets.json").read_text(encoding="utf-8"))["budgets"]
    assets = []
    for entry in registry["assets"]:
        result = validate_asset(root / entry["source_glb"], entry["category"], budgets[entry["category"]])
        assets.append({**entry, **result})
    counts = {status: sum(asset["status"] == status for asset in assets) for status in ("ready", "missing", "blocked")}
    return {"version": 1, "valid": counts["missing"] == 0 and counts["blocked"] == 0, "summary": {"total": len(assets), **counts}, "assets": assets}


def validate_contract(root: Path = ROOT) -> list[str]:
    registry = json.loads((root / "data/blender/godot_import_registry.json").read_text(encoding="utf-8"))
    pipeline = json.loads((root / "data/blender/full_pipeline_manifest.json").read_text(encoding="utf-8"))
    expected_count = sum(job["stage"] != "materials" for job in pipeline["stages"])
    errors = []
    if registry.get("asset_count") != expected_count or len(registry.get("assets", [])) != expected_count:
        errors.append(f"registry must contain exactly {expected_count} GLB mappings")
    job_ids = [asset["job_id"] for asset in registry["assets"]]
    targets = [asset["godot_path"] for asset in registry["assets"]]
    if len(job_ids) != len(set(job_ids)):
        errors.append("duplicate job_id in Godot import registry")
    if len(targets) != len(set(targets)):
        errors.append("duplicate Godot target path")
    for asset in registry["assets"]:
        if not asset["source_glb"].endswith(".glb") or not asset["godot_path"].startswith("res://assets/3d/"):
            errors.append(f"invalid import mapping for {asset['job_id']}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path, default=ROOT / "reports/blender_production_readiness.json")
    parser.add_argument("--check-contract", action="store_true")
    parser.add_argument("--allow-missing", action="store_true")
    args = parser.parse_args()
    errors = validate_contract()
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    if args.check_contract:
        print(f"{len(json.loads(REGISTRY.read_text(encoding='utf-8'))['assets'])} Godot import mappings satisfy the production contract")
        return 0
    report = build_report()
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report["summary"], ensure_ascii=False))
    return 0 if report["valid"] or (args.allow_missing and report["summary"]["blocked"] == 0) else 1


if __name__ == "__main__":
    raise SystemExit(main())
