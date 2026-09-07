from __future__ import annotations

import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
V06 = ROOT / "data" / "veilleurs" / "v06"

EXPECTED = {
    "ENT_WATCHER_SAHEN": "Sahen Varo",
    "ENT_WATCHER_MIRA": "Mira Sen",
    "ENT_WATCHER_NAREM": "Narem Osh",
    "ENT_WATCHER_YSRA": "Ysra Nahal",
}
LEVELS = [1, 3, 5, 7, 9, 11, 13, 18, 21, 24, 28, 33, 38, 44, 50]
OBSOLETE_TOKENS = [
    "ENT_WATCHER_NAYRA", "ENT_WATCHER_TAREK", "ENT_WATCHER_AISHA", "ENT_WATCHER_IDRIS",
    "Nayra Orun", "Tarek Senn", "Aïsha Maren", "Idris Vael",
    "NA-BAS-", "TA-TRA-", "AÏ-ANA-", "ID-SEN-",
]
ACTIVE_PATHS = [
    V06 / "watchers.json",
    V06 / "watcher_tree_catalog.json",
    V06 / "starter_loadouts_watchers.json",
    ROOT / "scripts" / "core" / "content_db.gd",
    ROOT / "scripts" / "core" / "veilleurs_tactical_combat_runtime.gd",
    ROOT / "scripts" / "core" / "veilleurs_content_db_v07.gd",
    ROOT / "scripts" / "core" / "veilleurs_content_db_v07_runtime.gd",
    ROOT / "scripts" / "core" / "veilleurs_tactical_combat_runtime_v07.gd",
]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    errors: list[str] = []

    watchers_payload = load(V06 / "watchers.json")
    watchers = watchers_payload.get("watchers", [])
    ids = [row.get("entity_id") for row in watchers]
    if ids != list(EXPECTED):
        errors.append(f"watcher_ids:{ids}")
    for entity_id, name in EXPECTED.items():
        row = next((watcher for watcher in watchers if watcher.get("entity_id") == entity_id), {})
        if row.get("name_fr") != name:
            errors.append(f"watcher_name:{entity_id}:{row.get('name_fr')}")
    if watchers_payload.get("canonical_watchers") is not True:
        errors.append("watchers_not_marked_canonical")

    manifest = load(V06 / "watcher_tree_catalog.json")
    trees = manifest.get("trees", [])
    if manifest.get("canonical_watchers") is not True:
        errors.append("manifest_not_marked_canonical")
    if manifest.get("tree_count") != 12 or manifest.get("skill_count") != 180 or len(trees) != 12:
        errors.append("manifest_counts")
    if manifest.get("unlock_levels") != LEVELS:
        errors.append("manifest_unlock_levels")

    owner_counts: Counter[str] = Counter()
    tree_ids: list[str] = []
    skill_ids: list[str] = []
    for tree in trees:
        owner = str(tree.get("entity_id", ""))
        tree_id = str(tree.get("tree_id", ""))
        prefix = str(tree.get("prefix", ""))
        names = tree.get("names", [])
        activations = tree.get("activation", [])
        actions = tree.get("action", [])
        tree_ids.append(tree_id)
        if len(names) != 15 or len(activations) != 15 or len(actions) != 15:
            errors.append(f"tree_size:{tree_id}:{len(names)}:{len(activations)}:{len(actions)}")
        owner_counts[owner] += len(names)
        for index in range(len(names)):
            skill_ids.append(f"{prefix}_{index + 1:02d}")

    if set(owner_counts) != set(EXPECTED):
        errors.append(f"manifest_owners:{sorted(owner_counts)}")
    for entity_id in EXPECTED:
        if owner_counts.get(entity_id, 0) != 45:
            errors.append(f"owner_skill_count:{entity_id}:{owner_counts.get(entity_id, 0)}")
    if len(tree_ids) != len(set(tree_ids)) or len(set(tree_ids)) != 12:
        errors.append("tree_ids_not_unique")
    if len(skill_ids) != 180 or len(set(skill_ids)) != 180:
        errors.append(f"canonical_skill_ids:{len(skill_ids)}:{len(set(skill_ids))}")
    if not all(skill_id.startswith(("SK_SAHEN_", "SK_MIRA_", "SK_NAREM_", "SK_YSRA_")) for skill_id in skill_ids):
        errors.append("canonical_skill_prefix")

    watcher_tree_ids = {tree_id for watcher in watchers for tree_id in watcher.get("tree_ids", [])}
    if watcher_tree_ids != set(tree_ids):
        errors.append("watcher_tree_linkage")

    loadouts = load(V06 / "starter_loadouts_watchers.json")
    loadout_ids = {key for key in loadouts if not key.startswith("_")}
    if loadout_ids != set(EXPECTED):
        errors.append(f"starter_loadouts:{sorted(loadout_ids)}")

    for path in ACTIVE_PATHS:
        if not path.is_file():
            errors.append(f"active_path_missing:{path.relative_to(ROOT)}")
            continue
        text = path.read_text(encoding="utf-8")
        for token in OBSOLETE_TOKENS:
            if token in text:
                errors.append(f"obsolete_token:{path.relative_to(ROOT)}:{token}")

    runtime_text = (ROOT / "scripts" / "core" / "veilleurs_tactical_combat_runtime.gd").read_text(encoding="utf-8")
    for entity_id in EXPECTED:
        if entity_id not in runtime_text:
            errors.append(f"runtime_missing:{entity_id}")

    content_text = (ROOT / "scripts" / "core" / "content_db.gd").read_text(encoding="utf-8")
    for entity_id in EXPECTED:
        if entity_id not in content_text:
            errors.append(f"content_db_missing:{entity_id}")

    if errors:
        for error in errors:
            print("FAIL", error)
        print(f"VEILLEURS_V062_CANONICAL_AUDIT_FAILED: {len(errors)}")
        return 1
    print("VEILLEURS_V062_CANONICAL_AUDIT_OK: quartet=4 trees=12 skills=180 obsolete_active_runtime=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
