#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = ROOT / "data" / "maintenance" / "canonical_files.json"
TEXT_EXTENSIONS = {
    ".gd", ".tscn", ".tres", ".json", ".md", ".py", ".yml", ".yaml", ".cfg",
    ".txt", ".csv", ".toml", ".ini", ".sh", ".ps1", ".bat", ".html", ".css", ".js"
}

STATUS_CANONICAL = "canonical"
STATUS_ACTIVE = "active"
STATUS_REVIEW = "review"
STATUS_OBSOLETE = "obsolete"
STATUS_PROTECTED = "protected"


@dataclass
class FileRecord:
    path: str
    status: str
    reasons: list[str]
    referenced_by: list[str]
    protected: bool
    explicitly_obsolete: bool
    deletable: bool


def _run_git(args: list[str]) -> str:
    proc = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"git {' '.join(args)} failed")
    return proc.stdout


def tracked_files() -> list[Path]:
    return [ROOT / line for line in _run_git(["ls-files"]).splitlines() if line.strip()]


def load_manifest(path: Path) -> dict:
    raw = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise ValueError("manifest must be a JSON object")
    return raw


def _normalize_patterns(values: Iterable[str]) -> list[str]:
    return [str(value).replace("\\", "/").strip() for value in values if str(value).strip()]


def matches_any(path: str, patterns: Iterable[str]) -> bool:
    import fnmatch
    return any(fnmatch.fnmatch(path, pattern) for pattern in patterns)


def discover_references(files: list[Path]) -> dict[str, list[str]]:
    """Conservative repository-local reference scan.

    It intentionally over-reports references. A false positive only blocks deletion,
    which is the safe failure mode for this maintenance tool.
    """
    rel_paths = [p.relative_to(ROOT).as_posix() for p in files]
    by_basename: dict[str, set[str]] = {}
    for rel in rel_paths:
        by_basename.setdefault(Path(rel).name, set()).add(rel)

    references: dict[str, set[str]] = {rel: set() for rel in rel_paths}
    for source in files:
        if source.suffix.lower() not in TEXT_EXTENSIONS:
            continue
        try:
            text = source.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        source_rel = source.relative_to(ROOT).as_posix()
        normalized_text = text.replace("\\", "/")
        for target_rel in rel_paths:
            if target_rel == source_rel:
                continue
            # Full repo path or Godot res:// path.
            if target_rel in normalized_text or f"res://{target_rel}" in normalized_text:
                references[target_rel].add(source_rel)
                continue
            # Basename fallback only when unique in the repository.
            base = Path(target_rel).name
            if len(by_basename.get(base, set())) == 1 and base in normalized_text:
                references[target_rel].add(source_rel)
    return {key: sorted(value) for key, value in references.items()}


def legacy_score(path: str, legacy_regexes: list[str]) -> list[str]:
    reasons: list[str] = []
    lowered = path.lower()
    for pattern in legacy_regexes:
        if re.search(pattern, lowered):
            reasons.append(f"legacy-pattern:{pattern}")
    return reasons


def classify(files: list[Path], manifest: dict) -> list[FileRecord]:
    canonical = set(_normalize_patterns(manifest.get("canonical_paths", [])))
    obsolete = set(_normalize_patterns(manifest.get("obsolete_paths", [])))
    protected_patterns = _normalize_patterns(manifest.get("protected_patterns", []))
    active_patterns = _normalize_patterns(manifest.get("active_patterns", []))
    legacy_regexes = [str(v) for v in manifest.get("legacy_candidate_regexes", [])]
    refs = discover_references(files)

    records: list[FileRecord] = []
    for file_path in files:
        rel = file_path.relative_to(ROOT).as_posix()
        reasons: list[str] = []
        is_protected = matches_any(rel, protected_patterns)
        explicit_obsolete = rel in obsolete

        if rel in canonical:
            status = STATUS_CANONICAL
            reasons.append("manifest:canonical")
        elif is_protected:
            status = STATUS_PROTECTED
            reasons.append("manifest:protected")
        elif explicit_obsolete:
            status = STATUS_OBSOLETE
            reasons.append("manifest:obsolete")
        elif matches_any(rel, active_patterns):
            status = STATUS_ACTIVE
            reasons.append("manifest:active-pattern")
        else:
            legacy_reasons = legacy_score(rel, legacy_regexes)
            if legacy_reasons:
                status = STATUS_REVIEW
                reasons.extend(legacy_reasons)
            else:
                status = STATUS_ACTIVE
                reasons.append("default:tracked-active")

        incoming = refs.get(rel, [])
        if incoming:
            reasons.append(f"referenced-by:{len(incoming)}")

        # Hard deletion gate: explicit obsolete declaration + no refs + not protected.
        deletable = explicit_obsolete and not is_protected and not incoming and rel not in canonical
        records.append(FileRecord(
            path=rel,
            status=status,
            reasons=reasons,
            referenced_by=incoming,
            protected=is_protected,
            explicitly_obsolete=explicit_obsolete,
            deletable=deletable,
        ))
    return records


def write_report(records: list[FileRecord], output: Path) -> None:
    counts: dict[str, int] = {}
    for record in records:
        counts[record.status] = counts.get(record.status, 0) + 1
    payload = {
        "schema_version": 1,
        "summary": counts,
        "deletable_count": sum(1 for r in records if r.deletable),
        "records": [asdict(r) for r in records],
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def delete_files(records: list[FileRecord]) -> list[str]:
    deleted: list[str] = []
    for record in records:
        if not record.deletable:
            continue
        target = ROOT / record.path
        if target.exists():
            target.unlink()
            deleted.append(record.path)
    return deleted


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Audit and safely prune obsolete LITD files.")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--report", type=Path, default=ROOT / "artifacts" / "file-sorter-report.json")
    parser.add_argument("--apply", action="store_true", help="Actually delete files passing every deletion gate.")
    parser.add_argument("--allow-delete", action="store_true", help="Second explicit safety switch required with --apply.")
    parser.add_argument("--fail-on-review", action="store_true", help="Exit 2 if review candidates exist.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.apply and not args.allow_delete:
        print("REFUSAL: --apply requires --allow-delete", file=sys.stderr)
        return 3

    manifest = load_manifest(args.manifest)
    files = tracked_files()
    records = classify(files, manifest)
    write_report(records, args.report)

    summary: dict[str, int] = {}
    for record in records:
        summary[record.status] = summary.get(record.status, 0) + 1
    print("LITD_FILE_SORTER", json.dumps(summary, ensure_ascii=False, sort_keys=True))
    print(f"REPORT {args.report.relative_to(ROOT) if args.report.is_relative_to(ROOT) else args.report}")

    deletable = [r.path for r in records if r.deletable]
    print(f"DELETABLE {len(deletable)}")
    for path in deletable:
        print("DELETE_CANDIDATE", path)

    if args.apply:
        deleted = delete_files(records)
        for path in deleted:
            print("DELETED", path)
        print(f"DELETED_COUNT {len(deleted)}")

    review_count = sum(1 for r in records if r.status == STATUS_REVIEW)
    if args.fail_on_review and review_count:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
