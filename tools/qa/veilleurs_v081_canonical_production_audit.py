#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
V06 = ROOT / "data" / "veilleurs" / "v06"
V08 = ROOT / "data" / "veilleurs" / "v08"
WATCHERS = V06 / "watchers.json"
TREES = V06 / "watcher_tree_catalog.json"
ULTIMATES = V08 / "canonical_watcher_ultimates_12.json"
OVERLAY = ROOT / "scripts" / "core" / "veilleurs_content_db_v081_canonical.gd"
ULTIMATE_RUNTIME = ROOT / "scripts" / "core" / "veilleurs_ultimate_runtime.gd"

EXPECTED_WATCHERS = {
    "ENT_WATCHER_SAHEN": {
        "TREE_SAHEN_BRISEUR_LIGNES": ("ULT_WATCHER_SAHEN_BRISEUR_LIGNES", "La Ligne Cède"),
        "TREE_SAHEN_GARDIEN_MARTIAL": ("ULT_WATCHER_SAHEN_GARDIEN_MARTIAL", "Je Reste"),
        "TREE_SAHEN_MAITRISE_CORPS": ("ULT_WATCHER_SAHEN_MAITRISE_CORPS", "Un Corps N’Est Pas Une Armure"),
    },
    "ENT_WATCHER_MIRA": {
        "TREE_MIRA_OEIL_VEILLEUR": ("ULT_WATCHER_MIRA_OEIL_VEILLEUR", "Je Vois l’Ouverture"),
        "TREE_MIRA_DANSE_INTERVALLES": ("ULT_WATCHER_MIRA_DANSE_INTERVALLES", "Entre Deux Battements"),
        "TREE_MIRA_ANATOMIE_MOUVEMENT": ("ULT_WATCHER_MIRA_ANATOMIE_MOUVEMENT", "Plus Aucun Appui"),
    },
    "ENT_WATCHER_NAREM": {
        "TREE_NAREM_BASTION_VIVANT": ("ULT_WATCHER_NAREM_BASTION_VIVANT", "Sur Moi"),
        "TREE_NAREM_DISCIPLINE_EPREUVE": ("ULT_WATCHER_NAREM_DISCIPLINE_EPREUVE", "La Douleur Passe"),
        "TREE_NAREM_GARDIEN_AUTRES": ("ULT_WATCHER_NAREM_GARDIEN_AUTRES", "Personne Ne Tombe"),
    },
    "ENT_WATCHER_YSRA": {
        "TREE_YSRA_LECTURE_INTENTIONS": ("ULT_WATCHER_YSRA_LECTURE_INTENTIONS", "Je Savais Que Tu Ferais Cela"),
        "TREE_YSRA_REMANENCE_CONSCIENTE": ("ULT_WATCHER_YSRA_REMANENCE_CONSCIENTE", "Nous Nous Souvenons"),
        "TREE_YSRA_PAROLE_BRISE": ("ULT_WATCHER_YSRA_PAROLE_BRISE", "Le Doute Entre"),
    },
}
EXPECTED_LEVELS = [1, 3, 5, 7, 9, 11, 13, 18, 21, 24, 28, 33, 38, 44, 50]
FORBIDDEN = {
    "ENT_WATCHER_NAYRA", "ENT_WATCHER_TAREK", "ENT_WATCHER_AISHA", "ENT_WATCHER_IDRIS",
    "TREE_NAYRA_BASTION", "TREE_TAREK_TRAQUE", "TREE_AISHA_ANATOMIE", "TREE_IDRIS_SENTENCE",
}
SUPPORTED_PROFILES = {"signature_control", "signature_mastery", "survival_or_execution", "boss_signature"}


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    errors: list[str] = []
    for path in [WATCHERS, TREES, ULTIMATES, OVERLAY, ULTIMATE_RUNTIME]:
        if not path.is_file():
            errors.append(f"missing:{path.relative_to(ROOT)}")
    if errors:
        return fail(errors)

    watchers = load(WATCHERS)
    trees = load(TREES)
    ultimates = load(ULTIMATES)

    watcher_rows = watchers.get("watchers", [])
    watcher_ids = {row.get("entity_id") for row in watcher_rows}
    if watcher_ids != set(EXPECTED_WATCHERS):
        errors.append(f"watcher_ids:{sorted(watcher_ids)}")
    if watchers.get("count") != 4:
        errors.append("watcher_count")

    levels = trees.get("unlock_levels", [])
    if levels != EXPECTED_LEVELS:
        errors.append(f"unlock_levels:{levels}")
    tree_rows = trees.get("trees", [])
    if len(tree_rows) != 12:
        errors.append(f"tree_count:{len(tree_rows)}")
    if trees.get("skill_count") != 180:
        errors.append("skill_count_contract")

    tree_by_id = {row.get("tree_id"): row for row in tree_rows}
    generated_skill_ids: set[str] = set()
    counts: dict[str, int] = {watcher_id: 0 for watcher_id in EXPECTED_WATCHERS}
    for watcher_id, expected_trees in EXPECTED_WATCHERS.items():
        for tree_id in expected_trees:
            row = tree_by_id.get(tree_id)
            if not row:
                errors.append(f"missing_tree:{tree_id}")
                continue
            if row.get("entity_id") != watcher_id:
                errors.append(f"tree_owner:{tree_id}")
            names = row.get("names", [])
            if len(names) != 15:
                errors.append(f"tree_skill_count:{tree_id}:{len(names)}")
            prefix = row.get("prefix", "")
            for index in range(1, 16):
                skill_id = f"{prefix}_{index:02d}"
                if skill_id in generated_skill_ids:
                    errors.append(f"duplicate_skill:{skill_id}")
                generated_skill_ids.add(skill_id)
                counts[watcher_id] += 1
    if any(count != 45 for count in counts.values()):
        errors.append(f"watcher_skill_partition:{counts}")
    if len(generated_skill_ids) != 180:
        errors.append(f"generated_skill_count:{len(generated_skill_ids)}")

    ultimate_rows = ultimates.get("ultimates", [])
    if ultimates.get("count") != 12 or len(ultimate_rows) != 12:
        errors.append(f"ultimate_count:{len(ultimate_rows)}")
    ultimate_ids: set[str] = set()
    per_watcher: dict[str, int] = {watcher_id: 0 for watcher_id in EXPECTED_WATCHERS}
    for row in ultimate_rows:
        uid = str(row.get("ultimate_id", ""))
        owner = str(row.get("entity_id", ""))
        tree_id = str(row.get("tree_id", ""))
        if uid in ultimate_ids:
            errors.append(f"duplicate_ultimate:{uid}")
        ultimate_ids.add(uid)
        if owner not in EXPECTED_WATCHERS:
            errors.append(f"ultimate_owner:{uid}:{owner}")
            continue
        per_watcher[owner] += 1
        expected = EXPECTED_WATCHERS[owner].get(tree_id)
        if not expected:
            errors.append(f"ultimate_tree:{uid}:{tree_id}")
        else:
            expected_id, expected_name = expected
            if uid != expected_id:
                errors.append(f"ultimate_id:{tree_id}:{uid}")
            if row.get("name_fr") != expected_name:
                errors.append(f"ultimate_name:{uid}")
        if int(row.get("unlock_level", 0)) != 16:
            errors.append(f"ultimate_level:{uid}")
        if row.get("charges_by_level") != {"16": 1, "32": 2, "48": 3}:
            errors.append(f"ultimate_charges:{uid}")
        if row.get("source_normal_skill_id") not in generated_skill_ids:
            errors.append(f"ultimate_source:{uid}")
        if row.get("profile") not in SUPPORTED_PROFILES:
            errors.append(f"unsupported_profile:{uid}:{row.get('profile')}")
        for key in ["resolver_required", "prevent_generic_fallback", "consumes_charge_only_on_success", "resolver_trace_required"]:
            if row.get(key) is not True:
                errors.append(f"ultimate_contract:{uid}:{key}")
        if row.get("resolver_id") != "veilleurs_ultimate_runtime_v07":
            errors.append(f"ultimate_resolver:{uid}")
        if row.get("missing_resolver_behavior") != "block_execution_and_report_validation_error":
            errors.append(f"ultimate_missing_resolver_behavior:{uid}")
    if any(count != 3 for count in per_watcher.values()):
        errors.append(f"ultimate_partition:{per_watcher}")

    active_text = WATCHERS.read_text(encoding="utf-8") + TREES.read_text(encoding="utf-8") + ULTIMATES.read_text(encoding="utf-8")
    for forbidden in FORBIDDEN:
        if forbidden in active_text:
            errors.append(f"forbidden_active_id:{forbidden}")

    overlay_text = OVERLAY.read_text(encoding="utf-8")
    for marker in ["CANONICAL_WATCHER_ULTIMATES_PATH", "canonical_watcher_ultimate_count", "_index_canonical_or_production_ultimate"]:
        if marker not in overlay_text:
            errors.append(f"overlay_marker:{marker}")
    runtime_text = ULTIMATE_RUNTIME.read_text(encoding="utf-8")
    for marker in ["ultimate_for_tree", "ultimate_charges", "charge_spent"]:
        if marker not in runtime_text:
            errors.append(f"runtime_marker:{marker}")

    if errors:
        return fail(errors)
    print("VEILLEURS_V081_CANONICAL_AUDIT_OK: watchers=4 trees=12 normal_skills=180 ultimates=12 levels=canonical")
    return 0


def fail(errors: list[str]) -> int:
    for error in errors:
        print("FAIL", error)
    print(f"VEILLEURS_V081_CANONICAL_AUDIT_FAILED: {len(errors)}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
