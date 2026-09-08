#!/usr/bin/env python3
"""Quality gate for the LITD Les Veilleurs canonical cast and v46 animation matrix."""
from __future__ import annotations

import json
from pathlib import Path

from tools.blender.generate_animation_production_matrix_v46 import build_payload

ROOT = Path(__file__).resolve().parents[2]
CAST_PATH = ROOT / "data/blender/canonical_cast_v46.json"
BODY_PATH = ROOT / "data/body_visual_runtime_v42.json"
LEGACY_PATH = ROOT / "data/blender/character_jobs.json"
PRODUCTION_CONTRACT_PATH = ROOT / "data/blender/animation_production_matrix_v45.json"

EXPECTED_VEILLEURS = {"Nayra Orun", "Tarek Senn", "Aïsha Maren", "Idris Vael"}
EXPECTED_SPECIES = {
    "Délié Affamé", "Délié Boursouflé", "Censeur Fendu", "Flagellant Fendu",
    "Sentinelle du Seuil", "Exécuteur de Pierre", "Traque-Suie", "Brise-Os de Suie",
    "Écouteur Creux", "Porte-Signe", "Marcheur Aphone", "Reteneur de Souffle",
    "Veine Rampante", "Nœud-Écorché", "Porte-Sang", "Germe Artériel",
    "Marche-Pâle", "Porte-Linceul", "Effaceur de Traces", "Dormeur de Cendre",
    "Copie Lacunaire", "Rature Vivante", "Archiviste de Version", "Double du Seuil",
}
EXPECTED_BOSSES = {
    "Ishar, Gardien du Passage", "Orateur Sans Voix", "Mère des Veines",
    "Porte-Cendres Blanc", "Le Copiste",
}


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def audit() -> list[str]:
    errors: list[str] = []
    registry = _load(CAST_PATH)
    body = _load(BODY_PATH)
    legacy = _load(LEGACY_PATH)
    production_contract = _load(PRODUCTION_CONTRACT_PATH)
    payload = build_payload(ROOT)

    if int(registry.get("version", 0)) != 46:
        errors.append("canonical cast version must be 46")
    if registry.get("gameplay_neutral") is not True:
        errors.append("canonical casting registry must remain gameplay-neutral")
    if registry.get("legacy_source_ignored") != "data/blender/character_jobs.json":
        errors.append("legacy character_jobs exclusion must be explicit")

    cast = registry.get("cast", {})
    veilleurs = cast.get("veilleurs", [])
    species = cast.get("species", [])
    bosses = cast.get("bosses", [])
    expected_counts = registry.get("expected_counts", {})
    actual_counts = {
        "veilleurs": len(veilleurs),
        "species": len(species),
        "bosses": len(bosses),
        "total": len(veilleurs) + len(species) + len(bosses),
        "species_families": len({str(item.get("family", "")) for item in species}),
    }
    for key, expected in expected_counts.items():
        if int(actual_counts.get(key, -1)) != int(expected):
            errors.append(f"cast count mismatch {key}: expected {expected}, got {actual_counts.get(key)}")
    if actual_counts != {"veilleurs": 4, "species": 24, "bosses": 5, "total": 33, "species_families": 8}:
        errors.append(f"canonical 4+24+5 contract broken: {actual_counts}")

    if {str(item.get("name", "")) for item in veilleurs} != EXPECTED_VEILLEURS:
        errors.append("canonical Veilleur names do not match the master roster")
    if {str(item.get("name", "")) for item in species} != EXPECTED_SPECIES:
        errors.append("canonical 24-species roster does not match Anatomie_24")
    if {str(item.get("name", "")) for item in bosses} != EXPECTED_BOSSES:
        errors.append("canonical five-boss roster does not match Boss_Anatomie_5")

    all_items = [*veilleurs, *species, *bosses]
    ids = [str(item.get("id", "")) for item in all_items]
    names = [str(item.get("name", "")) for item in all_items]
    if any(not value for value in ids) or len(set(ids)) != 33:
        errors.append("all 33 canonical entities need a unique non-empty id")
    if any(not value for value in names) or len(set(names)) != 33:
        errors.append("all 33 canonical entities need a unique non-empty name")

    runtime_morphologies = set(body.get("morphologies", {}))
    for item in all_items:
        morphology = str(item.get("morphology", ""))
        if morphology not in runtime_morphologies:
            errors.append(f"unknown runtime morphology for {item.get('id')}: {morphology}")
    for boss in bosses:
        if boss.get("morphology") != "BOSS_CUSTOM" or not boss.get("anatomy_parts"):
            errors.append(f"boss needs BOSS_CUSTOM anatomy parts: {boss.get('id')}")

    aliases = registry.get("runtime_profile_aliases", {})
    for item in species:
        canonical = str(item.get("canonical_body_profile", ""))
        expected_runtime = str(aliases.get(canonical, canonical))
        if str(item.get("morphology", "")) != expected_runtime:
            errors.append(f"runtime profile alias mismatch for {item.get('id')}")

    rules = registry.get("rules", {})
    for key in (
        "species_are_full_playable_heroes_when_recruited",
        "permadeath_applies_to_recruited_species",
        "bosses_are_non_recruitable",
        "v46_animation_must_only_use_this_registry",
    ):
        if rules.get(key) is not True:
            errors.append(f"canonical rule must remain true: {key}")

    if int(payload.get("version", 0)) != 46 or int(payload.get("source_cast_version", 0)) != 46:
        errors.append("generated animation matrix must be v46 sourced from cast v46")
    if payload.get("legacy_character_jobs_used") is not False:
        errors.append("v46 matrix must never read legacy character_jobs")
    if int(payload.get("cast_count", 0)) != 33:
        errors.append(f"v46 matrix must cover exactly 33 entities, got {payload.get('cast_count')}")

    canonical_ids = set(ids)
    represented_ids = {str(item.get("character_id", "")) for item in payload.get("requests", [])}
    if represented_ids != canonical_ids:
        errors.append(
            f"v46 casting coverage mismatch missing={sorted(canonical_ids - represented_ids)} "
            f"extra={sorted(represented_ids - canonical_ids)}"
        )

    legacy_ids = {str(job.get("character_id", "")) for job in legacy.get("jobs", [])}
    leaked_legacy = represented_ids & (legacy_ids - canonical_ids)
    if leaked_legacy:
        errors.append(f"legacy cast leaked into v46: {sorted(leaked_legacy)}")

    requests = payload.get("requests", [])
    masters = payload.get("masters", [])
    if not requests or not masters:
        errors.append("v46 must generate systemic requests and master clips")
    if int(payload.get("requested_actions", -1)) != len(requests):
        errors.append("requested_actions count mismatch")
    if int(payload.get("master_clips", -1)) != len(masters):
        errors.append("master_clips count mismatch")

    minimum_reuse = float(production_contract.get("quality_gates", {}).get("minimum_reuse_ratio", 0.0))
    if float(payload.get("reuse_ratio", 0.0)) < minimum_reuse:
        errors.append(
            f"v46 reuse ratio below v45 production gate: {payload.get('reuse_ratio')} < {minimum_reuse}"
        )

    signatures = payload.get("signature_backlog", [])
    if len(signatures) != 37 or int(payload.get("signature_count", 0)) != 37:
        errors.append(f"expected 37 canonical signature slots, got {len(signatures)}")
    if int(payload.get("hero_ultimate_slots", 0)) != 12:
        errors.append("expected 12 Veilleur ultimate slots")
    if int(payload.get("boss_ultimate_slots", 0)) != 15:
        errors.append("expected 15 boss ultimate slots")
    if int(payload.get("boss_signature_slots", 0)) != 5:
        errors.append("expected 5 boss signature slots")
    if int(payload.get("boss_phase_slots", 0)) != 5:
        errors.append("expected 5 boss phase-transition slots")

    signature_ids = {str(item.get("character_id", "")) for item in signatures}
    allowed_signature_ids = {str(item.get("id", "")) for item in [*veilleurs, *bosses]}
    if not signature_ids.issubset(allowed_signature_ids):
        errors.append(f"signature backlog contains non-canonical ids: {sorted(signature_ids - allowed_signature_ids)}")

    priority = payload.get("priority_summary", {})
    if int(priority.get("P0", 0)) <= 0 or int(priority.get("P1", 0)) <= 0:
        errors.append("v46 must preserve non-empty P0 and P1 production tiers")
    if int(priority.get("P2", 0)) < 37:
        errors.append("v46 P2 must include at least the 37 canonical signatures")

    return errors


def main() -> int:
    errors = audit()
    if errors:
        for error in errors:
            print(f"V46_AUDIT_ERROR: {error}")
        return 1
    payload = build_payload(ROOT)
    print(
        "CANONICAL_CAST_V46_AUDIT_OK "
        f"cast={payload['cast_count']} requests={payload['requested_actions']} "
        f"masters={payload['master_clips']} signatures={payload['signature_count']} "
        f"avoided={payload['avoided_duplicate_clips']} reuse={payload['reuse_ratio']:.1%} "
        f"P0={payload['priority_summary']['P0']} P1={payload['priority_summary']['P1']} "
        f"P2={payload['priority_summary']['P2']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
