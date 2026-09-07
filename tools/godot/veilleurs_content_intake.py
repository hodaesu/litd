#!/usr/bin/env python3
"""Production content intake for LITD: Les Veilleurs.

Creates deterministic work orders and reserves canonical IDs without mutating
canonical gameplay data. Standard-library only so it can run on CI and Windows.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data/veilleurs/content_intake_contract.json"
DEFAULT_WORK_ORDER_ROOT = ROOT / "data/veilleurs/intake/work_orders"
ID_RE = re.compile(r"^[A-Z][A-Z0-9_]*$")
SCAN_SUFFIXES = {".json", ".gd", ".tscn", ".tres", ".cfg", ".md"}
CANONICAL_SCAN_ROOTS = [
    ROOT / "data/veilleurs",
    ROOT / "scripts/core",
    ROOT / "scripts/ui",
    ROOT / "scripts/world",
    ROOT / "scenes/veilleurs",
    ROOT / "scenes/ui",
    ROOT / "scenes/tests",
]


def load_contract(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def ascii_slug(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    ascii_text = normalized.encode("ascii", "ignore").decode("ascii").lower()
    slug = re.sub(r"[^a-z0-9]+", "_", ascii_text).strip("_")
    slug = re.sub(r"_+", "_", slug)
    if not slug:
        raise ValueError("display name does not produce a usable slug")
    return slug


def canonical_token(value: str) -> str:
    return ascii_slug(value).upper()


def validate_content_type(content_type: str, contract: dict[str, Any]) -> dict[str, Any]:
    supported = contract.get("supported_types", {})
    if content_type not in supported:
        raise ValueError(f"unsupported content type: {content_type}")
    return supported[content_type]


def derive_id(content_type: str, display_name: str, contract: dict[str, Any], explicit_id: str | None = None) -> str:
    spec = validate_content_type(content_type, contract)
    prefix = str(spec["id_prefix"])
    candidate = explicit_id.strip().upper() if explicit_id else prefix + canonical_token(display_name)
    if not ID_RE.fullmatch(candidate):
        raise ValueError(f"invalid canonical id: {candidate}")
    if not candidate.startswith(prefix):
        raise ValueError(f"canonical id for {content_type} must start with {prefix}")
    if candidate == prefix.rstrip("_") or candidate == prefix:
        raise ValueError("canonical id must contain a meaningful suffix")
    return candidate


def safe_work_order_path(canonical_id: str, work_order_root: Path = DEFAULT_WORK_ORDER_ROOT) -> Path:
    if not ID_RE.fullmatch(canonical_id):
        raise ValueError("unsafe canonical id")
    root = work_order_root.resolve()
    path = (root / f"{canonical_id.lower()}.json").resolve()
    if root != path.parent:
        raise ValueError("work-order path traversal detected")
    return path


def render_planned_files(spec: dict[str, Any], slug: str, canonical_id: str) -> list[dict[str, str]]:
    result: list[dict[str, str]] = []
    values = {
        "slug": slug,
        "canonical_id": canonical_id,
        "canonical_id_lower": canonical_id.lower(),
    }
    for row in spec.get("planned_files", []):
        path = str(row.get("path", ""))
        for key, value in values.items():
            path = path.replace("{" + key + "}", value)
        if not path or path.startswith("/") or ".." in Path(path).parts:
            raise ValueError(f"unsafe planned path: {path}")
        result.append({"path": path, "action": str(row.get("action", "review")), "status": "pending"})
    return result


def _iter_scan_files(repository_root: Path = ROOT):
    intake_root = (repository_root / "data/veilleurs/intake/work_orders").resolve()
    for base in CANONICAL_SCAN_ROOTS:
        try:
            relative = base.relative_to(ROOT)
        except ValueError:
            continue
        mapped = repository_root / relative
        if not mapped.exists():
            continue
        for path in mapped.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in SCAN_SUFFIXES:
                continue
            try:
                if path.resolve().is_relative_to(intake_root):
                    continue
            except AttributeError:
                if str(path.resolve()).startswith(str(intake_root)):
                    continue
            yield path


def canonical_id_occurrences(canonical_id: str, repository_root: Path = ROOT) -> list[str]:
    hits: list[str] = []
    for path in _iter_scan_files(repository_root):
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        if canonical_id in text:
            try:
                hits.append(path.relative_to(repository_root).as_posix())
            except ValueError:
                hits.append(path.as_posix())
    return sorted(set(hits))


def reserved_id_occurrences(canonical_id: str, work_order_root: Path = DEFAULT_WORK_ORDER_ROOT) -> list[str]:
    if not work_order_root.exists():
        return []
    hits: list[str] = []
    for path in work_order_root.glob("*.json"):
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError, OSError):
            continue
        if payload.get("canonical_id") == canonical_id:
            hits.append(path.as_posix())
    return hits


def assert_available(canonical_id: str, repository_root: Path = ROOT, work_order_root: Path = DEFAULT_WORK_ORDER_ROOT) -> None:
    canonical_hits = canonical_id_occurrences(canonical_id, repository_root)
    if canonical_hits:
        raise ValueError(f"canonical id already exists: {canonical_id} ({', '.join(canonical_hits[:6])})")
    reserved_hits = reserved_id_occurrences(canonical_id, work_order_root)
    if reserved_hits:
        raise ValueError(f"canonical id already reserved: {canonical_id} ({reserved_hits[0]})")


def build_work_order(
    content_type: str,
    display_name: str,
    *,
    explicit_id: str | None = None,
    contract: dict[str, Any] | None = None,
    repository_root: Path = ROOT,
    work_order_root: Path = DEFAULT_WORK_ORDER_ROOT,
) -> dict[str, Any]:
    contract = contract or load_contract()
    spec = validate_content_type(content_type, contract)
    slug = ascii_slug(display_name)
    canonical_id = derive_id(content_type, display_name, contract, explicit_id)
    assert_available(canonical_id, repository_root, work_order_root)
    output_root = str(spec.get("output_root_pattern", "")).replace("{slug}", slug)
    state = str(contract.get("rules", {}).get("new_work_order_state", "intake_reserved"))
    return {
        "schema_version": 2,
        "state": state,
        "content_type": content_type,
        "canonical_id": canonical_id,
        "display_name_fr": display_name.strip(),
        "slug": slug,
        "canonical_sources": list(spec.get("canonical_sources", [])),
        "integration_targets": list(spec.get("integration_targets", [])),
        "planned_files": render_planned_files(spec, slug, canonical_id),
        "production": {
            "output_root": output_root,
            "required_assets": list(spec.get("required_assets", [])),
            "asset_status": {slot: "pending" for slot in spec.get("required_assets", [])},
        },
        "validation": {
            "required_tests": list(spec.get("required_tests", [])),
            "required_gates": list(spec.get("required_gates", [])),
            "evidence": [],
        },
        "constraints": {
            "runtime_target": contract.get("rules", {}).get("runtime_target"),
            "mobile_first": bool(contract.get("rules", {}).get("mobile_first", True)),
            "presentation_never_decides_gameplay": True,
            "canonical_gameplay_mutated_by_intake": False,
            "cannot_canonicalize": bool(spec.get("cannot_canonicalize", False)),
        },
        "handoff": {
            "next_state": "canonical_implementation_pending",
            "rule": "Implement canonical data/runtime/tests in a reviewed change; intake reservation alone is never gameplay authority.",
        },
    }


def reserve_work_order(order: dict[str, Any], work_order_root: Path = DEFAULT_WORK_ORDER_ROOT) -> Path:
    canonical_id = str(order.get("canonical_id", ""))
    path = safe_work_order_path(canonical_id, work_order_root)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        raise ValueError(f"work order already exists: {path}")
    path.write_text(json.dumps(order, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return path


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create or preview a Veilleurs production work order.")
    parser.add_argument("content_type", nargs="?", help="watcher, enemy, boss, dungeon, ui_screen, ultimate or generic")
    parser.add_argument("display_name", nargs="?", help="French display name")
    parser.add_argument("--id", dest="explicit_id", help="Explicit canonical ID (must match type prefix)")
    parser.add_argument("--reserve", action="store_true", help="Write the work order and reserve its ID")
    parser.add_argument("--list-types", action="store_true", help="List supported content types")
    parser.add_argument("--json", action="store_true", help="Print compact JSON")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    contract = load_contract()
    if args.list_types:
        for key, spec in contract.get("supported_types", {}).items():
            suffix = " (refinement required)" if spec.get("cannot_canonicalize") else ""
            print(f"{key}: {spec.get('id_prefix')}{suffix}")
        return 0
    if not args.content_type or not args.display_name:
        print("ERROR: content_type and display_name are required (or use --list-types)", file=sys.stderr)
        return 2
    try:
        order = build_work_order(args.content_type, args.display_name, explicit_id=args.explicit_id, contract=contract)
        if args.reserve:
            path = reserve_work_order(order)
            order["reservation_path"] = path.relative_to(ROOT).as_posix()
        if args.json:
            print(json.dumps(order, ensure_ascii=False, separators=(",", ":")))
        else:
            print(json.dumps(order, ensure_ascii=False, indent=2))
        print("VEILLEURS_CONTENT_INTAKE_RESERVED" if args.reserve else "VEILLEURS_CONTENT_INTAKE_PREVIEW", file=sys.stderr)
        return 0
    except (ValueError, OSError, json.JSONDecodeError) as exc:
        print(f"VEILLEURS_CONTENT_INTAKE_FAILED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
