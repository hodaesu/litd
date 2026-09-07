from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
V06 = ROOT / "data" / "veilleurs" / "v06"
CANON = ROOT / "data" / "veilleurs" / "skills"

EXPECTED = {
    "ENT_WATCHER_NAYRA": ("Nayra Orun", "nayra_orun.json"),
    "ENT_WATCHER_TAREK": ("Tarek Senn", "tarek_senn.json"),
    "ENT_WATCHER_AISHA": ("Aïsha Maren", "aisha_maren.json"),
    "ENT_WATCHER_IDRIS": ("Idris Vael", "idris_vael.json"),
}
ALTERNATE_TOKENS = [
    "ENT_WATCHER_SAHEN", "ENT_WATCHER_MIRA", "ENT_WATCHER_NAREM", "ENT_WATCHER_YSRA",
    "Sahen Varo", "Mira Sen", "Narem Osh", "Ysra Nahal",
    "SK_SAHEN_", "SK_MIRA_", "SK_NAREM_", "SK_YSRA_",
]
ACTIVE_PATHS = [
    V06 / "watchers.json",
    V06 / "watcher_tree_catalog.json",
    V06 / "starter_loadouts_watchers.json",
    ROOT / "scripts" / "core" / "content_db.gd",
    ROOT / "scripts" / "core" / "veilleurs_tactical_combat_runtime.gd",
    ROOT / "scripts" / "core" / "veilleurs_v06_tactical_smoke_test.gd",
    ROOT / "scripts" / "core" / "veilleurs_v061_systems_smoke_test.gd",
    ROOT / "scripts" / "ui" / "veilleurs_tactical_demo.gd",
    ROOT / "scripts" / "ui" / "veilleurs_tactical_demo_v2.gd",
    ROOT / "tools" / "qa" / "veilleurs_v061_balance_sim.py",
]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    errors: list[str] = []
    watchers = load(V06 / "watchers.json").get("watchers", [])
    ids = [row.get("entity_id") for row in watchers]
    if ids != list(EXPECTED):
        errors.append(f"watcher_ids:{ids}")
    for entity_id, (name, _file) in EXPECTED.items():
        row = next((w for w in watchers if w.get("entity_id") == entity_id), {})
        if row.get("name_fr") != name:
            errors.append(f"watcher_name:{entity_id}:{row.get('name_fr')}")

    manifest = load(V06 / "watcher_tree_catalog.json")
    if manifest.get("tree_count") != 12 or manifest.get("skill_count") != 180:
        errors.append("manifest_counts")
    if manifest.get("unlock_levels") != [1,4,7,10,13,16,19,22,25,28,31,35,39,44,49]:
        errors.append("manifest_unlock_levels")

    skill_ids: list[str] = []
    names: list[str] = []
    for _entity_id, (_name, filename) in EXPECTED.items():
        payload = load(CANON / filename)
        fields = payload.get("fields", [])
        try:
            id_i = fields.index("ID")
            name_i = fields.index("Nom")
        except ValueError:
            errors.append(f"canonical_fields:{filename}")
            continue
        owner_count = 0
        for tree_key in payload.get("tree_order", []):
            rows = payload.get("trees", {}).get(tree_key, {}).get("skills", [])
            if len(rows) != 15:
                errors.append(f"tree_size:{filename}:{tree_key}:{len(rows)}")
            owner_count += len(rows)
            for row in rows:
                skill_ids.append(str(row[id_i]))
                names.append(str(row[name_i]))
        if owner_count != 45:
            errors.append(f"owner_skill_count:{filename}:{owner_count}")
    if len(skill_ids) != 180 or len(set(skill_ids)) != 180:
        errors.append(f"canonical_skill_ids:{len(skill_ids)}:{len(set(skill_ids))}")

    required_examples = {"NA-BAS-01", "NA-BRI-01", "TA-TRA-01", "TA-ENT-01", "AÏ-ANA-01", "AÏ-HÉM-01", "ID-SEN-01", "ID-DIS-01"}
    if not required_examples.issubset(set(skill_ids)):
        errors.append("canonical_examples_missing")

    for path in ACTIVE_PATHS:
        if not path.is_file():
            errors.append(f"active_path_missing:{path.relative_to(ROOT)}")
            continue
        text = path.read_text(encoding="utf-8")
        for token in ALTERNATE_TOKENS:
            # Smoke/audit files are allowed to mention the forbidden IDs only when they explicitly
            # assert their absence. Runtime/data/demo/simulation files may never depend on them.
            if token in text and "smoke_test" not in path.name:
                errors.append(f"alternate_token:{path.relative_to(ROOT)}:{token}")

    runtime_text = (ROOT / "scripts" / "core" / "veilleurs_tactical_combat_runtime.gd").read_text(encoding="utf-8")
    for entity_id in EXPECTED:
        if entity_id not in runtime_text:
            errors.append(f"runtime_missing:{entity_id}")

    content_text = (ROOT / "scripts" / "core" / "content_db.gd").read_text(encoding="utf-8")
    for _entity_id, (_name, filename) in EXPECTED.items():
        if filename not in content_text:
            errors.append(f"content_db_source_missing:{filename}")

    if errors:
        for error in errors:
            print("FAIL", error)
        print(f"VEILLEURS_V062_CANONICAL_AUDIT_FAILED: {len(errors)}")
        return 1
    print("VEILLEURS_V062_CANONICAL_AUDIT_OK: quartet=4 trees=12 skills=180 alternate_runtime=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
