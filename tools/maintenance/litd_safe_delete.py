#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PLAN = ROOT / "artifacts" / "file-sorter-delete-plan.json"
GODOT_COMPANION_SUFFIXES = (".uid", ".import", ".remap")
TEXT_SUFFIXES = {
    ".gd", ".tscn", ".tres", ".cfg", ".godot", ".json", ".md", ".txt",
    ".yml", ".yaml", ".py", ".sh", ".cs", ".gdshader", ".svg",
    ".uid", ".import", ".remap",
}
UID_RE = re.compile(r"uid://[a-z0-9]+", re.IGNORECASE)


def _git(args: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if check and proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or f"git {' '.join(args)} failed")
    return proc


def tracked_paths() -> set[str]:
    return {line for line in _git(["ls-files"]).stdout.splitlines() if line.strip()}


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def working_tree_clean() -> bool:
    return not _git(["status", "--porcelain", "--untracked-files=no"]).stdout.strip()


def _safe_repo_path(rel: str) -> Path:
    if not rel or rel.startswith("-"):
        raise RuntimeError(f"invalid deletion path: {rel!r}")
    target = ROOT / rel
    if target.is_symlink():
        raise RuntimeError(f"refusing symlink deletion: {rel}")
    resolved = target.resolve()
    root = ROOT.resolve()
    if resolved == root or root not in resolved.parents:
        raise RuntimeError(f"refusing path outside repository: {rel}")
    return target


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="strict")
    except (OSError, UnicodeDecodeError):
        return ""


def resource_uids(path: Path) -> set[str]:
    if path.suffix.lower() not in TEXT_SUFFIXES:
        return set()
    return set(UID_RE.findall(_read_text(path)))


def build_uid_owners(paths: set[str]) -> dict[str, set[str]]:
    owners: dict[str, set[str]] = {}
    for rel in paths:
        path = ROOT / rel
        for uid in resource_uids(path):
            # A UID occurring in a resource header or its .uid companion may identify that file.
            if path.suffix.lower() in {".tscn", ".tres", ".uid"}:
                owner = rel[:-4] if rel.endswith(".uid") else rel
                owners.setdefault(uid, set()).add(owner)
    return owners


def incoming_uid_references(paths: set[str], candidates: set[str]) -> dict[str, list[str]]:
    uid_owners = build_uid_owners(paths)
    candidate_uids: dict[str, set[str]] = {candidate: set() for candidate in candidates}
    for uid, owners in uid_owners.items():
        for owner in owners:
            if owner in candidates:
                candidate_uids.setdefault(owner, set()).add(uid)

    result: dict[str, set[str]] = {candidate: set() for candidate in candidates}
    for source_rel in paths:
        if source_rel in candidates:
            continue
        source = ROOT / source_rel
        source_uids = resource_uids(source)
        if not source_uids:
            continue
        for candidate, uids in candidate_uids.items():
            if source_uids & uids:
                result[candidate].add(source_rel)
    return {candidate: sorted(sources) for candidate, sources in result.items()}


def _companion_owner(path: str) -> str | None:
    for suffix in GODOT_COMPANION_SUFFIXES:
        if path.endswith(suffix):
            return path[: -len(suffix)]
    return None


def validate_companion_coherence(candidates: set[str], tracked: set[str]) -> list[str]:
    errors: list[str] = []
    for rel in candidates:
        owner = _companion_owner(rel)
        if owner is not None:
            if owner in tracked and owner not in candidates:
                errors.append(f"companion_without_owner:{rel}:{owner}")
            continue

        for suffix in GODOT_COMPANION_SUFFIXES:
            companion = rel + suffix
            if companion in tracked and companion not in candidates:
                errors.append(f"owner_without_companion:{rel}:{companion}")
    return sorted(errors)


def load_plan(path: Path) -> dict:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise RuntimeError("delete plan must be a JSON object")
    candidates = payload.get("candidates", [])
    if not isinstance(candidates, list):
        raise RuntimeError("delete plan candidates must be a list")
    return payload


def validate_plan(plan: dict) -> list[str]:
    errors: list[str] = []
    tracked = tracked_paths()
    rows = plan.get("candidates", [])
    candidate_paths = [str(row.get("path", "")) for row in rows if isinstance(row, dict)]
    candidates = set(candidate_paths)

    if len(candidate_paths) != len(candidates):
        errors.append("duplicate_candidate_path")

    for row in rows:
        if not isinstance(row, dict):
            errors.append("invalid_candidate_record")
            continue
        rel = str(row.get("path", ""))
        expected = str(row.get("sha256", ""))
        if rel not in tracked:
            errors.append(f"not_tracked:{rel}")
            continue
        try:
            target = _safe_repo_path(rel)
        except RuntimeError as exc:
            errors.append(str(exc))
            continue
        if not target.is_file():
            errors.append(f"not_regular_file:{rel}")
            continue
        if not expected or expected == "SYMLINK":
            errors.append(f"missing_valid_hash:{rel}")
            continue
        current = file_sha256(target)
        if current != expected:
            errors.append(f"hash_changed_since_audit:{rel}")

    errors.extend(validate_companion_coherence(candidates, tracked))
    uid_refs = incoming_uid_references(tracked, candidates)
    for rel, sources in uid_refs.items():
        if sources:
            errors.append(f"uid_referenced:{rel}:{','.join(sources)}")

    return sorted(set(errors))


def git_rm_dry_run(paths: list[str]) -> str:
    if not paths:
        return ""
    proc = _git(["rm", "--dry-run", "--", *paths], check=False)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or "git rm --dry-run failed")
    return proc.stdout.strip()


def git_rm(paths: list[str]) -> str:
    if not paths:
        return ""
    # Intentionally no --force: Git's own up-to-date checks remain active.
    proc = _git(["rm", "--", *paths], check=False)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or "git rm failed")
    return proc.stdout.strip()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Final Git-backed deletion gate for LITD obsolete files.")
    parser.add_argument("--plan", type=Path, default=DEFAULT_PLAN)
    parser.add_argument("--execute", action="store_true", help="Stage real removals through git rm.")
    parser.add_argument("--allow-delete", action="store_true", help="Second explicit switch required with --execute.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.execute and not args.allow_delete:
        print("REFUSAL: --execute requires --allow-delete", file=sys.stderr)
        return 3
    if not working_tree_clean():
        print("REFUSAL: tracked working tree must be clean", file=sys.stderr)
        return 5

    plan = load_plan(args.plan)
    errors = validate_plan(plan)
    for error in errors:
        print("DELETE_GATE_ERROR", error, file=sys.stderr)
    if errors:
        return 4

    paths = [str(row["path"]) for row in plan.get("candidates", [])]
    preview = git_rm_dry_run(paths)
    print("GIT_RM_DRY_RUN_OK", len(paths))
    if preview:
        print(preview)

    if not args.execute:
        print("AUDIT_ONLY: no files removed")
        return 0

    output = git_rm(paths)
    if output:
        print(output)
    print("GIT_RM_STAGED", len(paths))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
