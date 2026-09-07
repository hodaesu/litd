#!/usr/bin/env python3
"""Audit du handoff final des assets de LITD : Les Veilleurs."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data/veilleurs/final_asset_handoff_contract.json"
REPORT_PATH = ROOT / "build/automation/veilleurs_final_asset_handoff_status.json"

EXPECTED_STATE = "spec_ready_pc_production_pending"
REQUIRED_ULTIMATE_SLOTS = {"animation", "camera", "vfx", "audio", "haptic", "ui"}
REQUIRED_VALIDATION_TARGETS = {
    "phone", "tablet", "desktop", "reduced_motion", "reduced_gore",
    "haptics_off", "short_ultimate_mode",
}
REQUIRED_GROUPS = {
    "watchers_4", "enemies_24", "bosses_5", "dungeons_6",
    "refuge_hub", "ui_2d", "body_damage_and_corpses",
}


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    errors: list[str] = []
    checks: dict[str, bool] = {}
    contract = load_json(CONTRACT_PATH)

    checks["stage"] = contract.get("stage") == EXPECTED_STATE
    if not checks["stage"]:
        errors.append(f"stage inattendu: {contract.get('stage')}")

    rules = contract.get("rules", {})
    critical = [
        "presentation_never_decides_gameplay",
        "final_asset_validation_requires_real_hardware",
        "no_baked_ui_text",
        "mobile_first",
        "lod_required_for_3d_combat_assets",
        "collision_proxy_separate_from_render_mesh",
        "body_damage_variants_preserve_anatomy_state",
        "corpse_visuals_may_lod_but_logical_remanence_persists",
    ]
    checks["critical_rules"] = all(rules.get(key) is True for key in critical)
    if not checks["critical_rules"]:
        errors.append("une ou plusieurs règles critiques de handoff sont absentes")

    source_map = contract.get("authoritative_sources", {})
    missing_sources = [value for value in source_map.values() if not (ROOT / value).is_file()]
    checks["authoritative_sources"] = not missing_sources
    if missing_sources:
        errors.append("sources autoritatives absentes: " + ", ".join(missing_sources))

    watchers = load_json(ROOT / source_map["watchers"])
    enemies = load_json(ROOT / source_map["enemies"])
    bosses = load_json(ROOT / source_map["bosses"])
    wave3 = load_json(ROOT / source_map["dungeons"])
    canonical = load_json(ROOT / source_map["canonical_ultimates"])
    choreography = load_json(ROOT / source_map["ultimate_choreography"])

    counts = {
        "watchers_4": len(watchers.get("watchers", [])),
        "enemies_24": len(enemies.get("enemies", [])),
        "bosses_5": len(bosses.get("bosses", [])),
        "dungeons_6": len(wave3.get("vertical_slice", {}).get("dungeon_ids", [])),
    }
    expected_counts = {"watchers_4": 4, "enemies_24": 24, "bosses_5": 5, "dungeons_6": 6}
    checks["canonical_entity_counts"] = counts == expected_counts
    if not checks["canonical_entity_counts"]:
        errors.append(f"comptes canoniques inattendus: {counts}")

    slot_contract = contract.get("ultimate_slot_contract", {})
    checks["ultimate_slot_contract"] = set(slot_contract.get("required_slots", [])) == REQUIRED_ULTIMATE_SLOTS
    checks["ultimate_validation_targets"] = REQUIRED_VALIDATION_TARGETS.issubset(
        set(slot_contract.get("validation_targets", []))
    )
    if not checks["ultimate_slot_contract"]:
        errors.append("les six slots finaux des ultimes ne sont pas verrouillés")
    if not checks["ultimate_validation_targets"]:
        errors.append("les cibles de validation finale des ultimes sont incomplètes")

    groups = contract.get("production_groups", [])
    group_ids = [str(row.get("group_id", "")) for row in groups]
    checks["production_groups"] = set(group_ids) == REQUIRED_GROUPS and len(group_ids) == len(set(group_ids))
    if not checks["production_groups"]:
        errors.append(f"groupes de production invalides: {group_ids}")
    for row in groups:
        group_id = str(row.get("group_id", ""))
        if row.get("state") != EXPECTED_STATE:
            errors.append(f"{group_id}: état de handoff invalide")
        if not str(row.get("output_root", "")).startswith("res://assets/veilleurs/production/"):
            errors.append(f"{group_id}: output_root hors namespace Veilleurs")
        slots = row.get("required_slots", [])
        if not slots or len(slots) != len(set(slots)):
            errors.append(f"{group_id}: slots absents ou dupliqués")
        if group_id in counts and int(row.get("expected_count", -1)) != counts[group_id]:
            errors.append(f"{group_id}: expected_count différent de la source canonique")

    canonical_rows = canonical.get("ultimates", [])
    canonical_by_id = {str(row.get("ultimate_id", "")): row for row in canonical_rows}
    canonical_ids = set(canonical_by_id)
    checks["canonical_ultimate_count"] = len(canonical_rows) == 12 and len(canonical_ids) == 12
    if not checks["canonical_ultimate_count"]:
        errors.append(f"registre canonique des ultimes invalide: {len(canonical_rows)}")

    packages = contract.get("ultimate_packages", [])
    package_ids = [str(row.get("ultimate_id", "")) for row in packages]
    checks["ultimate_packages"] = len(packages) == 12 and set(package_ids) == canonical_ids
    if not checks["ultimate_packages"]:
        errors.append("les 12 packages d'ultimes ne correspondent pas au registre canonique")

    choreography_rows = choreography.get("ultimates", {})
    roots: set[str] = set()
    for package in packages:
        ultimate_id = str(package.get("ultimate_id", ""))
        canonical_row = canonical_by_id.get(ultimate_id, {})
        runtime_id = str(package.get("runtime_id", ""))
        tree = str(package.get("tree", ""))
        choreography_key = f"{runtime_id}:{tree}"

        if package.get("production_state") != EXPECTED_STATE:
            errors.append(f"{ultimate_id}: état de production invalide")
        if str(package.get("watcher_id", "")) != str(canonical_row.get("entity_id", "")):
            errors.append(f"{ultimate_id}: propriétaire différent du canon")
        if str(package.get("resolver_id", "")) != str(canonical_row.get("resolver_id", "")):
            errors.append(f"{ultimate_id}: resolver différent du canon")
        if str(package.get("name_fr", "")) != str(canonical_row.get("name_fr", "")):
            errors.append(f"{ultimate_id}: nom différent du canon")
        if not bool(canonical_row.get("resolver_required", False)):
            errors.append(f"{ultimate_id}: resolver signature non requis dans le registre canonique")
        if choreography_key not in choreography_rows:
            errors.append(f"{ultimate_id}: chorégraphie absente ({choreography_key})")
        elif str(choreography_rows[choreography_key].get("name", "")) != str(canonical_row.get("name_fr", "")):
            errors.append(f"{ultimate_id}: nom de chorégraphie incohérent")

        naming = package.get("naming", {})
        if set(naming) != REQUIRED_ULTIMATE_SLOTS or any(not str(naming.get(slot, "")).strip() for slot in REQUIRED_ULTIMATE_SLOTS):
            errors.append(f"{ultimate_id}: conventions de nommage incomplètes")

        output_root = str(package.get("output_root", ""))
        if not output_root.startswith("res://assets/veilleurs/production/ultimates/"):
            errors.append(f"{ultimate_id}: output_root invalide")
        if output_root in roots:
            errors.append(f"{ultimate_id}: output_root dupliqué")
        roots.add(output_root)

    checks["package_contracts"] = not errors

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    report = {
        "ok": not errors,
        "stage": contract.get("stage"),
        "checks": checks,
        "counts": counts,
        "ultimate_packages": len(packages),
        "errors": errors,
        "message": "VEILLEURS_FINAL_ASSET_HANDOFF_READY_FOR_PC_PRODUCTION"
        if not errors else "VEILLEURS_FINAL_ASSET_HANDOFF_BLOCKED",
    }
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if errors:
        print("VEILLEURS_FINAL_ASSET_HANDOFF_FAILED")
        for error in errors:
            print("ERROR:", error)
        return 1

    print("VEILLEURS_FINAL_ASSET_HANDOFF_OK")
    print(f"Production groups: {len(groups)} | Ultimate packages: {len(packages)}")
    print("Final assets remain intentionally pending PC/DCC/hardware production.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
