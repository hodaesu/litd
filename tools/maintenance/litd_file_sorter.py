#!/usr/bin/env python3
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import os
import re
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = ROOT / "data" / "maintenance" / "canonical_files.json"
DEFAULT_REPORT = ROOT / "artifacts" / "file-sorter-report.json"
DEFAULT_PLAN = ROOT / "artifacts" / "file-sorter-delete-plan.json"
TEXT_EXTENSIONS = {
    ".gd", ".tscn", ".tres", ".json", ".md", ".py", ".yml", ".yaml", ".cfg",
    ".txt", ".csv", ".toml", ".ini", ".sh", ".ps1", ".bat", ".html", ".css", ".js",
    ".svg", ".gdshader"
}
STATUS_CANONICAL = "canonical"
STATUS_ACTIVE = "active"
STATUS_REVIEW = "review"
STATUS_OBSOLETE = "obsolete"
STATUS_PROTECTED = "protected"
STATUS_GENERATED = "generated"


@dataclass
class FileRecord:
    path: str
    status: str
    confidence: float
    reasons: list[str]
    referenced_by: list[str]
    duplicate_of: list[str]
    sha256: str
    size: int
    protected: bool
    explicitly_obsolete: bool
    deletable: bool


def _run_git(args: list[str]) -> str:
    proc = subprocess.run(
        ["git", *args], cwd=ROOT, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
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
    if int(raw.get("schema_version", 0)) < 2:
        raise ValueError("manifest schema_version must be >= 2")
    return raw


def _normalize_patterns(values: Iterable[str]) -> list[str]:
    return [str(v).replace("\\", "/").strip() for v in values if str(v).strip()]


def matches_any(path: str, patterns: Iterable[str]) -> bool:
    return any(fnmatch.fnmatch(path, pattern) for pattern in patterns)


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def duplicate_index(files: list[Path]) -> dict[str, list[str]]:
    by_hash: dict[str, list[str]] = {}
    for path in files:
        try:
            digest = file_sha256(path)
        except OSError:
            continue
        by_hash.setdefault(digest, []).append(path.relative_to(ROOT).as_posix())
    return {digest: sorted(paths) for digest, paths in by_hash.items() if len(paths) > 1}


def _reference_tokens(rel_paths: list[str]) -> dict[str, set[str]]:
    tokens: dict[str, set[str]] = {}
    basename_counts: dict[str, int] = {}
    for rel in rel_paths:
        basename_counts[Path(rel).name] = basename_counts.get(Path(rel).name, 0) + 1
    for rel in rel_paths:
        values = {rel, f"res://{rel}"}
        base = Path(rel).name
        if basename_counts[base] == 1:
            values.add(base)
        for token in values:
            tokens.setdefault(token, set()).add(rel)
    return tokens


def discover_references(files: list[Path]) -> dict[str, list[str]]:
    """Conservative repository-local reference graph.

    Only tracked text-like files are scanned. False positives intentionally block
    deletion; they never make deletion easier.
    """
    rel_paths = [p.relative_to(ROOT).as_posix() for p in files]
    token_map = _reference_tokens(rel_paths)
    references: dict[str, set[str]] = {rel: set() for rel in rel_paths}
    for source in files:
        if source.suffix.lower() not in TEXT_EXTENSIONS:
            continue
        try:
            text = source.read_text(encoding="utf-8").replace("\\", "/")
        except (UnicodeDecodeError, OSError):
            continue
        source_rel = source.relative_to(ROOT).as_posix()
        for token, targets in token_map.items():
            if token not in text:
                continue
            for target in targets:
                if target != source_rel:
                    references[target].add(source_rel)
    return {key: sorted(value) for key, value in references.items()}


def legacy_reasons(path: str, regexes: list[str]) -> list[str]:
    lowered = path.lower()
    return [f"legacy-pattern:{p}" for p in regexes if re.search(p, lowered)]


def _confidence(status: str, reasons: list[str], incoming: list[str], duplicates: list[str]) -> float:
    if status == STATUS_CANONICAL:
        return 1.0
    if status == STATUS_PROTECTED:
        return 0.99
    if status == STATUS_GENERATED:
        return 0.95
    if status == STATUS_OBSOLETE:
        score = 0.92
        if incoming:
            score -= 0.45
        if duplicates:
            score += 0.03
        return round(max(0.0, min(1.0, score)), 2)
    if status == STATUS_REVIEW:
        score = 0.55 + min(0.2, 0.05 * sum(r.startswith("legacy-pattern:") for r in reasons))
        if incoming:
            score -= 0.15
        if duplicates:
            score += 0.10
        return round(max(0.0, min(1.0, score)), 2)
    return 0.80


def classify(files: list[Path], manifest: dict) -> list[FileRecord]:
    canonical = set(_normalize_patterns(manifest.get("canonical_paths", [])))
    obsolete = set(_normalize_patterns(manifest.get("obsolete_paths", [])))
    protected_patterns = _normalize_patterns(manifest.get("protected_patterns", []))
    active_patterns = _normalize_patterns(manifest.get("active_patterns", []))
    generated_patterns = _normalize_patterns(manifest.get("generated_patterns", []))
    legacy_regexes = [str(v) for v in manifest.get("legacy_candidate_regexes", [])]
    refs = discover_references(files)
    duplicates = duplicate_index(files)
    digest_for: dict[str, str] = {}
    for digest, paths in duplicates.items():
        for path in paths:
            digest_for[path] = digest

    records: list[FileRecord] = []
    for file_path in files:
        rel = file_path.relative_to(ROOT).as_posix()
        digest = file_sha256(file_path)
        duplicate_paths = [p for p in duplicates.get(digest, []) if p != rel]
        incoming = refs.get(rel, [])
        reasons: list[str] = []
        is_protected = matches_any(rel, protected_patterns)
        explicit_obsolete = rel in obsolete

        if rel in canonical:
            status = STATUS_CANONICAL
            reasons.append("manifest:canonical")
        elif is_protected:
            status = STATUS_PROTECTED
            reasons.append("manifest:protected")
        elif matches_any(rel, generated_patterns):
            status = STATUS_GENERATED
            reasons.append("manifest:generated")
        elif explicit_obsolete:
            status = STATUS_OBSOLETE
            reasons.append("manifest:obsolete")
        elif matches_any(rel, active_patterns):
            status = STATUS_ACTIVE
            reasons.append("manifest:active-pattern")
        else:
            lr = legacy_reasons(rel, legacy_regexes)
            if lr:
                status = STATUS_REVIEW
                reasons.extend(lr)
            else:
                status = STATUS_ACTIVE
                reasons.append("default:tracked-active")

        if incoming:
            reasons.append(f"referenced-by:{len(incoming)}")
        if duplicate_paths:
            reasons.append(f"exact-duplicate:{len(duplicate_paths)}")

        deletable = (
            explicit_obsolete
            and status == STATUS_OBSOLETE
            and not is_protected
            and rel not in canonical
            and not incoming
        )
        records.append(FileRecord(
            path=rel,
            status=status,
            confidence=_confidence(status, reasons, incoming, duplicate_paths),
            reasons=reasons,
            referenced_by=incoming,
            duplicate_of=duplicate_paths,
            sha256=digest,
            size=file_path.stat().st_size,
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
        "schema_version": 2,
        "summary": counts,
        "deletable_count": sum(r.deletable for r in records),
        "review_count": sum(r.status == STATUS_REVIEW for r in records),
        "duplicate_file_count": sum(bool(r.duplicate_of) for r in records),
        "records": [asdict(r) for r in records],
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_delete_plan(records: list[FileRecord], output: Path) -> None:
    candidates = [
        {"path": r.path, "sha256": r.sha256, "reasons": r.reasons}
        for r in records if r.deletable
    ]
    payload = {"schema_version": 1, "candidate_count": len(candidates), "candidates": candidates}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def delete_from_plan(plan_path: Path) -> list[str]:
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    deleted: list[str] = []
    for row in plan.get("candidates", []):
        rel = str(row.get("path", ""))
        expected = str(row.get("sha256", ""))
        target = ROOT / rel
        if not target.is_file():
            continue
        current = file_sha256(target)
        if current != expected:
            raise RuntimeError(f"refusing changed file since audit: {rel}")
        target.unlink()
        deleted.append(rel)
    return deleted


def validate_manifest(manifest: dict, files: list[Path]) -> list[str]:
    errors: list[str] = []
    tracked = {p.relative_to(ROOT).as_posix() for p in files}
    canonical = set(_normalize_patterns(manifest.get("canonical_paths", [])))
    obsolete = set(_normalize_patterns(manifest.get("obsolete_paths", [])))
    overlap = sorted(canonical & obsolete)
    if overlap:
        errors.append("canonical_and_obsolete:" + ",".join(overlap))
    missing_canonical = sorted(canonical - tracked)
    if missing_canonical:
        errors.append("missing_canonical:" + ",".join(missing_canonical))
    missing_obsolete = sorted(obsolete - tracked)
    if missing_obsolete:
        errors.append("missing_obsolete:" + ",".join(missing_obsolete))
    return errors


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Audit and safely prune obsolete LITD files.")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--plan", type=Path, default=DEFAULT_PLAN)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--allow-delete", action="store_true")
    parser.add_argument("--fail-on-review", action="store_true")
    parser.add_argument("--fail-on-manifest-error", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.apply and not args.allow_delete:
        print("REFUSAL: --apply requires --allow-delete", file=sys.stderr)
        return 3

    manifest = load_manifest(args.manifest)
    files = tracked_files()
    manifest_errors = validate_manifest(manifest, files)
    for error in manifest_errors:
        print("MANIFEST_ERROR", error, file=sys.stderr)
    if args.fail_on_manifest_error and manifest_errors:
        return 4

    records = classify(files, manifest)
    write_report(records, args.report)
    write_delete_plan(records, args.plan)

    summary: dict[str, int] = {}
    for record in records:
        summary[record.status] = summary.get(record.status, 0) + 1
    print("LITD_FILE_SORTER", json.dumps(summary, ensure_ascii=False, sort_keys=True))
    print(f"REVIEW {sum(r.status == STATUS_REVIEW for r in records)}")
    print(f"DUPLICATES {sum(bool(r.duplicate_of) for r in records)}")
    print(f"DELETABLE {sum(r.deletable for r in records)}")

    if args.apply:
        deleted = delete_from_plan(args.plan)
        for path in deleted:
            print("DELETED", path)
        print(f"DELETED_COUNT {len(deleted)}")

    if args.fail_on_review and any(r.status == STATUS_REVIEW for r in records):
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
