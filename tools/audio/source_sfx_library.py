#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import shutil
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data/audio/source_sfx_library.json"
REGISTRY_PATH = ROOT / "data/audio/source_sfx_registry.json"
LOCAL_ROOT = ROOT / "local/audio_library"
SOURCE_ROOT = LOCAL_ROOT / "01_SOURCE"
WORKING_ROOT = LOCAL_ROOT / "02_WORKING"
RENDERED_ROOT = LOCAL_ROOT / "03_RENDERED"
LICENSE_ROOT = LOCAL_ROOT / "04_LICENSES"


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def contract() -> dict:
    return load_json(CONTRACT_PATH)


def registry() -> dict:
    return load_json(REGISTRY_PATH)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def init_library(_: argparse.Namespace) -> int:
    for folder in (SOURCE_ROOT, WORKING_ROOT, RENDERED_ROOT, LICENSE_ROOT):
        folder.mkdir(parents=True, exist_ok=True)
    for category in contract()["categories"]:
        (SOURCE_ROOT / category).mkdir(parents=True, exist_ok=True)
    marker = LOCAL_ROOT / "README_LOCAL_ONLY.txt"
    if not marker.exists():
        marker.write_text(
            "Sonothèque locale LITD. Ne pas versionner les sources brutes ni les licences privées.\n",
            encoding="utf-8",
        )
    print(f"SOURCE_SFX_LIBRARY_INITIALIZED {LOCAL_ROOT}")
    return 0


def license_class(license_id: str) -> str:
    policy = contract()["license_policy"]
    if license_id in policy["green"]:
        return "green"
    if license_id in policy["private_only"]:
        return "private_only"
    return "blocked"


def require_external_metadata(args: argparse.Namespace) -> None:
    if args.license == "OWN_RECORDING":
        return
    missing = [name for name in ("provider", "author", "source_url", "license_evidence") if not getattr(args, name)]
    if missing:
        raise ValueError("External source missing: " + ", ".join(missing))


def next_source_id(payload: dict, category: str) -> str:
    number = int(payload.get("next_id", 1))
    prefix = category.upper().replace("_", "")[:10]
    return f"SRC_{prefix}_{number:06d}"


def ingest(args: argparse.Namespace) -> int:
    init_library(args)
    cfg = contract()
    if args.category not in cfg["categories"]:
        raise ValueError(f"Unknown category: {args.category}")
    tier = license_class(args.license)
    if tier == "blocked":
        raise ValueError(f"Blocked or unverified licence: {args.license}")
    require_external_metadata(args)

    source = Path(args.file).expanduser().resolve()
    if not source.is_file():
        raise FileNotFoundError(source)
    digest = sha256(source)
    payload = registry()
    for item in payload.get("sources", []):
        if item.get("sha256") == digest:
            raise ValueError(f"Duplicate source hash already registered as {item.get('id')}")

    source_id = next_source_id(payload, args.category)
    ext = source.suffix.lower() or ".bin"
    destination = SOURCE_ROOT / args.category / f"{source_id}{ext}"
    shutil.copy2(source, destination)
    evidence_target = ""
    if args.license_evidence:
        evidence = Path(args.license_evidence).expanduser()
        if evidence.is_file():
            evidence_target_path = LICENSE_ROOT / f"{source_id}_{evidence.name}"
            shutil.copy2(evidence, evidence_target_path)
            evidence_target = str(evidence_target_path.relative_to(ROOT))
        else:
            evidence_target = args.license_evidence

    tags = sorted({tag.strip() for tag in args.tags.split(",") if tag.strip()})
    record = {
        "id": source_id,
        "category": args.category,
        "subcategory": args.subcategory or "",
        "tags": tags,
        "source_type": args.source_type or args.license,
        "provider": args.provider or "",
        "author": args.author or "",
        "source_url": args.source_url or "",
        "license": args.license,
        "license_evidence": evidence_target,
        "commercial_use": True,
        "derivatives_allowed": True,
        "redistribution_allowed": tier == "green",
        "original_filename": source.name,
        "local_path": str(destination.relative_to(ROOT)),
        "sha256": digest,
        "ingested_on": dt.date.today().isoformat(),
        "status": "ingested_local_private" if tier == "private_only" else "ingested_local",
        "notes": args.notes or "",
    }
    payload.setdefault("sources", []).append(record)
    payload["next_id"] = int(payload.get("next_id", 1)) + 1
    save_json(REGISTRY_PATH, payload)
    print(json.dumps(record, ensure_ascii=False, indent=2))
    return 0


def audit_payload() -> tuple[list[str], dict]:
    cfg = contract()
    payload = registry()
    errors: list[str] = []
    ids: set[str] = set()
    hashes: set[str] = set()
    counts = Counter()
    status_counts = Counter()
    license_counts = Counter()
    for item in payload.get("sources", []):
        source_id = str(item.get("id", ""))
        if not source_id or source_id in ids:
            errors.append(f"duplicate/missing id: {source_id!r}")
        ids.add(source_id)
        category = str(item.get("category", ""))
        if category not in cfg["categories"]:
            errors.append(f"{source_id}: unknown category {category!r}")
        else:
            counts[category] += 1
        lic = str(item.get("license", "UNKNOWN"))
        tier = license_class(lic)
        license_counts[lic] += 1
        if tier == "blocked":
            errors.append(f"{source_id}: blocked/unverified licence {lic}")
        if lic != "OWN_RECORDING":
            for field in ("provider", "author", "source_url", "license_evidence"):
                if not item.get(field):
                    errors.append(f"{source_id}: missing {field}")
        if not bool(item.get("commercial_use", False)):
            errors.append(f"{source_id}: commercial use not cleared")
        if not bool(item.get("derivatives_allowed", False)):
            errors.append(f"{source_id}: derivatives not cleared")
        digest = str(item.get("sha256", ""))
        status = str(item.get("status", ""))
        status_counts[status] += 1
        if digest and not digest.startswith("PENDING_"):
            if digest in hashes:
                errors.append(f"{source_id}: duplicate sha256 {digest}")
            hashes.add(digest)
        elif status != "metadata_seed_binary_not_ingested":
            errors.append(f"{source_id}: missing final sha256")
        local_path = item.get("local_path")
        if local_path and not (ROOT / str(local_path)).exists():
            errors.append(f"{source_id}: local file missing: {local_path}")

    targets = {key: int(value["target"]) for key, value in cfg["categories"].items()}
    deficits = {key: max(0, targets[key] - counts[key]) for key in targets}
    stats = {
        "registered_sources": sum(counts.values()),
        "target_sources": int(cfg["target_source_count"]),
        "acceptable_range": cfg["acceptable_source_count"],
        "by_category": dict(sorted(counts.items())),
        "targets": targets,
        "deficits": deficits,
        "by_license": dict(sorted(license_counts.items())),
        "by_status": dict(sorted(status_counts.items())),
        "audit_errors": len(errors),
    }
    return errors, stats


def audit(_: argparse.Namespace) -> int:
    errors, stats = audit_payload()
    print(json.dumps(stats, ensure_ascii=False, indent=2))
    if errors:
        for error in errors:
            print("ERROR:", error, file=sys.stderr)
        return 1
    print("SOURCE_SFX_LIBRARY_AUDIT_OK")
    return 0


def stats(_: argparse.Namespace) -> int:
    _, payload = audit_payload()
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


def plan(_: argparse.Namespace) -> int:
    _, payload = audit_payload()
    rows = sorted(payload["deficits"].items(), key=lambda item: (-item[1], item[0]))
    print(f"Target: {payload['target_sources']} sources")
    print(f"Registered: {payload['registered_sources']}")
    for category, missing in rows:
        print(f"{category:20s} missing {missing:4d}")
    return 0


def credits(args: argparse.Namespace) -> int:
    payload = registry()
    lines = ["# LITD — SFX source attributions", "", "Generated from source_sfx_registry.json.", ""]
    seen: set[tuple[str, str, str]] = set()
    for item in payload.get("sources", []):
        if item.get("license") != "CC-BY":
            continue
        key = (str(item.get("author", "")), str(item.get("provider", "")), str(item.get("source_url", "")))
        if key in seen:
            continue
        seen.add(key)
        author, provider, url = key
        lines.append(f"- {author} — {provider} — CC-BY — {url}")
    output = Path(args.output) if args.output else LOCAL_ROOT / "CREDITS.generated.md"
    if not output.is_absolute():
        output = ROOT / output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(output)
    return 0


def register_derivative(args: argparse.Namespace) -> int:
    payload = registry()
    known = {item["id"] for item in payload.get("sources", [])}
    source_ids = [value.strip() for value in args.source_ids.split(",") if value.strip()]
    missing = [value for value in source_ids if value not in known]
    if missing:
        raise ValueError("Unknown source IDs: " + ", ".join(missing))
    recipe = json.loads(args.recipe)
    derivative = {
        "id": args.id,
        "source_ids": source_ids,
        "cue_id": args.cue_id or "",
        "variant": args.variant,
        "recipe": recipe,
        "status": args.status,
        "registered_on": dt.date.today().isoformat(),
    }
    ids = {item.get("id") for item in payload.get("derivatives", [])}
    if derivative["id"] in ids:
        raise ValueError(f"Derivative already exists: {derivative['id']}")
    payload.setdefault("derivatives", []).append(derivative)
    save_json(REGISTRY_PATH, payload)
    print(json.dumps(derivative, ensure_ascii=False, indent=2))
    return 0


def parser() -> argparse.ArgumentParser:
    cli = argparse.ArgumentParser(description="Manage the local LITD source SFX library")
    sub = cli.add_subparsers(dest="command", required=True)
    sub.add_parser("init").set_defaults(func=init_library)
    sub.add_parser("audit").set_defaults(func=audit)
    sub.add_parser("stats").set_defaults(func=stats)
    sub.add_parser("plan").set_defaults(func=plan)

    add = sub.add_parser("ingest")
    add.add_argument("file")
    add.add_argument("--category", required=True)
    add.add_argument("--subcategory", default="")
    add.add_argument("--license", required=True)
    add.add_argument("--source-type", default="")
    add.add_argument("--provider", default="")
    add.add_argument("--author", default="")
    add.add_argument("--source-url", default="")
    add.add_argument("--license-evidence", default="")
    add.add_argument("--tags", default="")
    add.add_argument("--notes", default="")
    add.set_defaults(func=ingest)

    credit = sub.add_parser("credits")
    credit.add_argument("--output", default="")
    credit.set_defaults(func=credits)

    derivative = sub.add_parser("derivative")
    derivative.add_argument("--id", required=True)
    derivative.add_argument("--source-ids", required=True)
    derivative.add_argument("--recipe", required=True, help="JSON array/object describing processing")
    derivative.add_argument("--cue-id", default="")
    derivative.add_argument("--variant", type=int, default=1)
    derivative.add_argument("--status", default="working")
    derivative.set_defaults(func=register_derivative)
    return cli


def main() -> int:
    args = parser().parse_args()
    try:
        return int(args.func(args))
    except Exception as exc:  # CLI: actionable one-line failure.
        print(f"SOURCE_SFX_LIBRARY_ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
