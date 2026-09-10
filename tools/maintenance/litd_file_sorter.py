#!/usr/bin/env python3
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
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
    replacement: str | None
    evidence: list[str]
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
    if int(raw.get("schema_version", 0)) < 3:
        raise ValueError("manifest schema_version must be >= 3")
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
        if path.is_symlink():
            continue
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
    """Build a conservative repository-local incoming-reference graph."""
    rel_paths = [p.relative_to(ROOT).as_posix() for p in files]
    token_map = _reference_tokens(rel_paths)
    references: dict[str, set[str]] = {rel: set() for rel in rel_paths}
    for source in files:
        if source.is_symlink() or source.suffix.lower() not in TEXT_EXTENSIONS:
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


def obsolete_registry(manifest: dict) -> dict[str, dict]:
    result: dict[str, dict] = {}
    for value in manifest.get("obsolete_records", []):
        if not isinstance(value, dict):
            continue
        path = str(value.get("path", "")).replace("\\", "/").strip()
        if path:
            result[path] = value
    return result


def _confidence(status: str, reasons: list[str], incoming: list[str], duplicates: list[str], declared: float | None = None) -> float:
    if declared is not None:
        return round(max(0.0, min(1.0, declared)), 2)
    if status == STATUS_CANONICAL:
        return 1.0
    if status == STATUS_PROTECTED:
        return 0.99
    if status == STATUS_GENERATED:
        return 0.95
    if status == STATUS_OBSOLETE:
        return 0.90 if not incoming else 0.45
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
    obsolete = obsolete_registry(manifest)
    protected_patterns = _normalize_patterns(manifest.get("protected_patterns", []))
    active_patterns = _normalize_patterns(manifest.get("active_patterns", []))
    generated_patterns = _normalize_patterns(manifest.get("generated_patterns", []))
    legacy_regexes = [str(v) for v in manifest.get("legacy_candidate_regexes", [])]
    min_delete_confidence = float(manifest.get("policy", {}).get("minimum_delete_confidence", 0.95))
    refs = discover_references(files)
    duplicates = duplicate_index(files)

    records: list[FileRecord] = []
    for file_path in files:
        rel = file_path.relative_to(ROOT).as_posix()
        symlink = file_path.is_symlink()
        digest = "SYMLINK" if symlink else file_sha256(file_path)
        duplicate_paths = [] if symlink else [p for p in duplicates.get(digest, []) if p != rel]
        incoming = refs.get(rel, [])
        reasons: list[str] = []
        is_protected = symlink or matches_any(rel, protected_patterns)
        decision = obsolete.get(rel)
        explicit_obsolete = decision is not None
        replacement = str(decision.get("replacement", "")).strip() if decision else ""
        replacement = replacement or None
        evidence = [str(v).strip() for v in (decision.get("evidence", []) if decision else []) if str(v).strip()]
        declared_confidence = float(decision.get("confidence", 0.0)) if decision else None

        if rel in canonical:
            status = STATUS_CANONICAL
            reasons.append("manifest:canonical")
        elif is_protected:
            status = STATUS_PROTECTED
            reasons.append("safety:symlink" if symlink else "manifest:protected")
        elif explicit_obsolete:
            status = STATUS_OBSOLETE
            reasons.append("manifest:obsolete-record")
        elif matches_any(rel, generated_patterns):
            status = STATUS_GENERATED
            reasons.append("manifest:generated")
        else:
            lr = legacy_reasons(rel, legacy_regexes)
            if lr:
                status = STATUS_REVIEW
                reasons.extend(lr)
            elif matches_any(rel, active_patterns):
                status = STATUS_ACTIVE
                reasons.append("manifest:active-pattern")
            else:
                status = STATUS_ACTIVE
                reasons.append("default:tracked-active")

        if incoming:
            reasons.append(f"referenced-by:{len(incoming)}")
        if duplicate_paths:
            reasons.append(f"exact-duplicate:{len(duplicate_paths)}")
        if replacement:
            reasons.append(f"replacement:{replacement}")
        if evidence:
            reasons.append(f"evidence:{len(evidence)}")

        confidence = _confidence(status, reasons, incoming, duplicate_paths, declared_confidence)
        replacement_ok = replacement is None or replacement in {p.relative_to(ROOT).as_posix() for p in files}
        evidence_ok = len(evidence) >= 1
        deletable = (
            explicit_obsolete
            and status == STATUS_OBSOLETE
            and not is_protected
            and rel not in canonical
            and not incoming
            and evidence_ok
            and replacement_ok
            and confidence >= min_delete_confidence
        )
        records.append(FileRecord(
            path=rel,
            status=status,
            confidence=confidence,
            reasons=reasons,
            referenced_by=incoming,
            duplicate_of=duplicate_paths,
            sha256=digest,
            size=file_path.lstat().st_size,
            protected=is_protected,
            explicitly_obsolete=explicit_obsolete,
            replacement=replacement,
            evidence=evidence,
            deletable=deletable,
        ))
    return records


def write_report(records: list[FileRecord], output: Path) -> None:
    counts: dict[str, int] = {}
    for record in records:
        counts[record.status] = counts.get(record.status, 0) + 1
    payload = {
        "schema_version": 3,
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
        {
            "path": r.path,
            "sha256": r.sha256,
            "replacement": r.replacement,
            "confidence": r.confidence,
            "evidence": r.evidence,
            "reasons": r.reasons,
        }
        for r in records if r.deletable
    ]
    payload = {"schema_version": 2, "candidate_count": len(candidates), "candidates": candidates}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def delete_from_plan(plan_path: Path) -> list[str]:
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    deleted: list[str] = []
    root_resolved = ROOT.resolve()
    for row in plan.get("candidates", []):
        rel = str(row.get("path", ""))
        expected = str(row.get("sha256", ""))
        target = ROOT / rel
        if target.is_symlink():
            raise RuntimeError(f"refusing symlink deletion: {rel}")
        resolved = target.resolve()
        if root_resolved not in resolved.parents:
            raise RuntimeError(f"refusing path outside repository: {rel}")
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
    obsolete = obsolete_registry(manifest)
    overlap = sorted(canonical & set(obsolete))
    if overlap:
        errors.append("canonical_and_obsolete:" + ",".join(overlap))
    missing_canonical = sorted(canonical - tracked)
    if missing_canonical:
        errors.append("missing_canonical:" + ",".join(missing_canonical))
    missing_obsolete = sorted(set(obsolete) - tracked)
    if missing_obsolete:
        errors.append("missing_obsolete:" + ",".join(missing_obsolete))
    if len(obsolete) != len(manifest.get("obsolete_records", [])):
        errors.append("duplicate_or_invalid_obsolete_record")
    min_conf = float(manifest.get("policy", {}).get("minimum_delete_confidence", 0.95))
    for path, decision in obsolete.items():
        if not str(decision.get("reason", "")).strip():
            errors.append(f"obsolete_missing_reason:{path}")
        evidence = [str(v).strip() for v in decision.get("evidence", []) if str(v).strip()]
        if not evidence:
            errors.append(f"obsolete_missing_evidence:{path}")
        confidence = float(decision.get("confidence", 0.0))
        if confidence < min_conf:
            errors.append(f"obsolete_low_confidence:{path}:{confidence}")
        replacement = str(decision.get("replacement", "")).strip()
        retired = bool(decision.get("retired_without_replacement", False))
        if not replacement and not retired:
            errors.append(f"obsolete_missing_replacement_or_retirement:{path}")
        if replacement and replacement not in tracked:
            errors.append(f"obsolete_replacement_missing:{path}:{replacement}")
    return errors


def working_tree_clean() -> bool:
    return not _run_git(["status", "--porcelain", "--untracked-files=no"]).strip()


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
    if args.apply and not working_tree_clean():
        print("REFUSAL: tracked working tree must be clean before deletion", file=sys.stderr)
        return 5

    manifest = load_manifest(args.manifest)
    files = tracked_files()
    manifest_errors = validate_manifest(manifest, files)
    for error in manifest_errors:
        print("MANIFEST_ERROR", error, file=sys.stderr)
    if args.apply and manifest_errors:
        print("REFUSAL: manifest errors block deletion", file=sys.stderr)
        return 4
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
