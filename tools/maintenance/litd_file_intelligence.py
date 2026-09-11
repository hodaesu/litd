#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import time
from collections import defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = ROOT / "data" / "maintenance" / "canonical_files.json"
DEFAULT_REPORT = ROOT / "artifacts" / "file-intelligence-report.json"

VERSION_RE = re.compile(r"(?i)(?P<prefix>.*?)(?:[_\-.]v(?P<version>\d{1,3}))(?P<suffix>(?:[._-].*)?)$")
UID_RE = re.compile(r"uid://[a-z0-9]+", re.IGNORECASE)
GODOT_COMPANION_SUFFIXES = (".uid", ".import", ".remap")
TEXT_SUFFIXES = {
    ".gd", ".tscn", ".tres", ".cfg", ".godot", ".json", ".md", ".txt",
    ".yml", ".yaml", ".py", ".sh", ".cs", ".gdshader", ".svg",
    ".uid", ".import", ".remap",
}


@dataclass
class GitActivity:
    last_commit_unix: int | None
    age_days: int | None
    commit_count: int


@dataclass
class VersionMember:
    path: str
    version: int
    referenced_by_count: int
    git_age_days: int | None
    git_commit_count: int
    canonical: bool


def _git(args: list[str], *, check: bool = True) -> str:
    proc = subprocess.run(
        ["git", *args], cwd=ROOT, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    if check and proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"git {' '.join(args)} failed")
    return proc.stdout.strip()


def tracked_paths() -> list[str]:
    return [line for line in _git(["ls-files"]).splitlines() if line.strip()]


def load_manifest(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def case_collisions(paths: list[str]) -> list[list[str]]:
    buckets: dict[str, list[str]] = defaultdict(list)
    for path in paths:
        buckets[path.casefold()].append(path)
    return [sorted(values) for values in buckets.values() if len(values) > 1]


def godot_companion_map(paths: list[str]) -> dict[str, dict]:
    present = set(paths)
    result: dict[str, dict] = {}
    for path in paths:
        for suffix in GODOT_COMPANION_SUFFIXES:
            if not path.endswith(suffix):
                continue
            owner = path[: -len(suffix)]
            result[path] = {
                "owner": owner,
                "owner_tracked": owner in present,
                "kind": suffix[1:],
                "orphan": owner not in present,
            }
            break
    return result


def version_family_key(path: str) -> tuple[str, int] | None:
    p = Path(path)
    stem = p.stem
    match = VERSION_RE.match(stem)
    if not match:
        return None
    prefix = match.group("prefix").rstrip("_.-").casefold()
    suffix = (match.group("suffix") or "").casefold()
    family = (p.parent.as_posix().casefold() + "/" + prefix + suffix).strip("/")
    return family, int(match.group("version"))


def version_families(paths: list[str]) -> dict[str, list[tuple[str, int]]]:
    groups: dict[str, list[tuple[str, int]]] = defaultdict(list)
    for path in paths:
        parsed = version_family_key(path)
        if parsed is not None:
            family, version = parsed
            groups[family].append((path, version))
    return {key: sorted(values, key=lambda row: (row[1], row[0])) for key, values in groups.items() if len(values) >= 2}


def git_activity(path: str, now: int | None = None) -> GitActivity:
    now = int(time.time()) if now is None else now
    last_text = _git(["log", "-1", "--format=%ct", "--", path], check=False)
    count_text = _git(["rev-list", "--count", "HEAD", "--", path], check=False)
    last_commit = int(last_text) if last_text.isdigit() else None
    count = int(count_text) if count_text.isdigit() else 0
    age_days = None if last_commit is None else max(0, (now - last_commit) // 86400)
    return GitActivity(last_commit, age_days, count)


def conservative_reference_counts(paths: list[str]) -> dict[str, int]:
    """Use git grep; false positives are acceptable because this report never deletes."""
    counts = {path: 0 for path in paths}
    basename_counts: dict[str, int] = defaultdict(int)
    for path in paths:
        basename_counts[Path(path).name] += 1
    for target in paths:
        tokens = [target, f"res://{target}"]
        if basename_counts[Path(target).name] == 1:
            tokens.append(Path(target).name)
        sources: set[str] = set()
        for token in tokens:
            out = _git(["grep", "-l", "-F", "--", token, "--", ":(exclude)artifacts/**"], check=False)
            for source in out.splitlines():
                if source and source != target:
                    sources.add(source)
        counts[target] = len(sources)
    return counts


def _read_text(path: str) -> str:
    file_path = ROOT / path
    if file_path.suffix.lower() not in TEXT_SUFFIXES:
        return ""
    try:
        return file_path.read_text(encoding="utf-8", errors="strict")
    except (OSError, UnicodeDecodeError):
        return ""


def godot_uid_analysis(paths: list[str]) -> dict:
    """Report UID ownership and incoming references without making deletion decisions."""
    uid_occurrences: dict[str, set[str]] = defaultdict(set)
    for path in paths:
        for uid in UID_RE.findall(_read_text(path)):
            uid_occurrences[uid].add(path)

    uid_owners: dict[str, set[str]] = defaultdict(set)
    for uid, sources in uid_occurrences.items():
        for source in sources:
            suffix = Path(source).suffix.lower()
            if suffix in {".tscn", ".tres"}:
                # Header UIDs are indistinguishable by regex alone from dependency UIDs,
                # so this is intentionally advisory.
                first_line = _read_text(source).splitlines()[:1]
                if first_line and uid in first_line[0]:
                    uid_owners[uid].add(source)
            elif source.endswith(".uid"):
                uid_owners[uid].add(source[:-4])

    incoming: dict[str, set[str]] = defaultdict(set)
    for uid, owners in uid_owners.items():
        for source in uid_occurrences.get(uid, set()):
            for owner in owners:
                if source != owner and source != owner + ".uid":
                    incoming[owner].add(source)

    orphan_uids = sorted(uid for uid in uid_occurrences if uid not in uid_owners)
    return {
        "uid_count": len(uid_occurrences),
        "owner_uid_count": len(uid_owners),
        "uid_owners": {uid: sorted(values) for uid, values in sorted(uid_owners.items())},
        "incoming_uid_references": {path: sorted(values) for path, values in sorted(incoming.items())},
        "uids_without_detected_owner": orphan_uids,
        "automatic_action_allowed": False,
    }


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _sample_hash(path: Path, sample_size: int = 65536) -> str:
    size = path.stat().st_size
    digest = hashlib.sha256()
    digest.update(str(size).encode("ascii"))
    with path.open("rb") as handle:
        digest.update(handle.read(sample_size))
        if size > sample_size:
            handle.seek(max(0, size - sample_size))
            digest.update(handle.read(sample_size))
    return digest.hexdigest()


def optimized_duplicate_groups(paths: list[str]) -> list[list[str]]:
    """Size -> sample hash -> full SHA-256. Full equality still requires the final hash."""
    by_size: dict[int, list[str]] = defaultdict(list)
    for rel in paths:
        path = ROOT / rel
        if not path.is_file() or path.is_symlink():
            continue
        try:
            by_size[path.stat().st_size].append(rel)
        except OSError:
            continue

    results: list[list[str]] = []
    for same_size in by_size.values():
        if len(same_size) < 2:
            continue
        by_sample: dict[str, list[str]] = defaultdict(list)
        for rel in same_size:
            try:
                by_sample[_sample_hash(ROOT / rel)].append(rel)
            except OSError:
                continue
        for sampled in by_sample.values():
            if len(sampled) < 2:
                continue
            by_full: dict[str, list[str]] = defaultdict(list)
            for rel in sampled:
                try:
                    by_full[_sha256(ROOT / rel)].append(rel)
                except OSError:
                    continue
            results.extend(sorted(group) for group in by_full.values() if len(group) > 1)
    return sorted(results)


def canonical_suggestions(paths: list[str], manifest: dict, refs: dict[str, int]) -> dict[str, dict]:
    canonical = set(str(v) for v in manifest.get("canonical_paths", []))
    result: dict[str, dict] = {}
    now = int(time.time())
    for family, rows in version_families(paths).items():
        members: list[VersionMember] = []
        for path, version in rows:
            activity = git_activity(path, now)
            members.append(VersionMember(
                path=path,
                version=version,
                referenced_by_count=refs.get(path, 0),
                git_age_days=activity.age_days,
                git_commit_count=activity.commit_count,
                canonical=path in canonical,
            ))
        explicit = [m for m in members if m.canonical]
        if len(explicit) == 1:
            suggestion = explicit[0].path
            confidence = "very_strong"
            reason = "explicit_manifest_canonical"
        elif len(explicit) > 1:
            suggestion = None
            confidence = "conflict"
            reason = "multiple_explicit_canonical_members"
        else:
            ranked = sorted(
                members,
                key=lambda m: (
                    m.version,
                    m.referenced_by_count,
                    -(m.git_age_days if m.git_age_days is not None else 10**9),
                    m.git_commit_count,
                ),
                reverse=True,
            )
            suggestion = ranked[0].path if ranked else None
            confidence = "medium"
            reason = "highest_version_then_reference_and_git_activity"
        result[family] = {
            "suggested_canonical": suggestion,
            "confidence": confidence,
            "reason": reason,
            "members": [asdict(m) for m in members],
            "automatic_action_allowed": False,
        }
    return result


def analyze(manifest_path: Path = DEFAULT_MANIFEST) -> dict:
    paths = tracked_paths()
    manifest = load_manifest(manifest_path)
    refs = conservative_reference_counts(paths)
    companions = godot_companion_map(paths)
    collisions = case_collisions(paths)
    families = canonical_suggestions(paths, manifest, refs)
    uid_report = godot_uid_analysis(paths)
    duplicates = optimized_duplicate_groups(paths)
    return {
        "schema_version": 2,
        "tracked_file_count": len(paths),
        "case_collisions": collisions,
        "case_collision_count": len(collisions),
        "godot_companions": companions,
        "godot_orphans": sorted(path for path, row in companions.items() if row["orphan"]),
        "godot_uid": uid_report,
        "exact_duplicate_groups": duplicates,
        "exact_duplicate_group_count": len(duplicates),
        "version_families": families,
        "version_family_count": len(families),
        "guardrails": {
            "deletes_files": False,
            "canonical_suggestions_are_advisory": True,
            "case_collisions_require_review": True,
            "godot_orphans_require_review": True,
            "uid_references_require_review": True,
            "duplicates_require_full_sha256": True,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Advanced non-destructive repository intelligence for LITD file sorting.")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--fail-on-case-collision", action="store_true")
    args = parser.parse_args()
    report = analyze(args.manifest)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("LITD_FILE_INTELLIGENCE", json.dumps({
        "tracked": report["tracked_file_count"],
        "case_collisions": report["case_collision_count"],
        "godot_orphans": len(report["godot_orphans"]),
        "godot_uids": report["godot_uid"]["uid_count"],
        "duplicate_groups": report["exact_duplicate_group_count"],
        "version_families": report["version_family_count"],
    }, sort_keys=True))
    if args.fail_on_case_collision and report["case_collision_count"]:
        return 6
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
