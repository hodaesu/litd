from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LORE = ROOT / "universe" / "lore"


def load(name: str) -> dict:
    return json.loads((LORE / name).read_text(encoding="utf-8"))


def run() -> dict:
    fates = load("legendary_seven_post_campaign_fates.json")
    manifest = load("legendary_seven_post_campaign_manifest.json")
    biographies = load("legendary_seven_biographies.json")
    relationships = load("legendary_seven_relationships.json")

    errors: list[str] = []
    expected_order = ["hero.zeje", "hero.anouk", "hero.marec", "hero.mathilde", "hero.effrie", "hero.aurelien", "hero.lya"]

    if fates.get("formation_order") != expected_order:
        errors.append("fates: formation order changed")
    if biographies.get("formation_order") != expected_order:
        errors.append("biographies: source formation order changed")

    heroes = fates.get("heroes", [])
    ids = [hero.get("id") for hero in heroes]
    if ids != expected_order:
        errors.append(f"fates: expected exact Seven order, got {ids}")

    rules = fates.get("rules", {})
    false_rules = [
        "seven_become_permanent_government",
        "seven_found_hereditary_order",
        "seven_receive_sovereignty_as_reward",
        "seven_remain_permanent_field_party",
        "group_breakup_is_single_betrayal",
        "romance_is_inferred_from_post_campaign_closeness",
        "exact_death_dates_locked",
        "all_late_endpoints_closed",
    ]
    for key in false_rules:
        if rules.get(key) is not False:
            errors.append(f"fates: {key} must remain false")
    for key in [
        "wounds_remain_historical_constraints",
        "legend_can_distort_trajectory",
        "ordinary_collaborators_remain_part_of_history",
        "effrie_unknowns_remain_unknown",
        "anouk_trame_origin_remains_unconfirmed",
        "future_story_can_continue_after_last_secure_attestation",
    ]:
        if rules.get(key) is not True:
            errors.append(f"fates: {key} must remain true")

    for hero in heroes:
        for field in ["post_campaign_role", "trajectory", "body_continuity", "public_legend", "author_truth", "secure_late_legacy", "late_endpoint"]:
            if not hero.get(field):
                errors.append(f"{hero.get('id')}: missing {field}")
        if len(hero.get("trajectory", [])) < 3:
            errors.append(f"{hero.get('id')}: trajectory too thin")
        if not str(hero.get("late_endpoint", "")).startswith("open_"):
            errors.append(f"{hero.get('id')}: late endpoint must remain open")
        if hero.get("public_legend") == hero.get("author_truth"):
            errors.append(f"{hero.get('id')}: legend and author truth must remain distinct")

    by_id = {hero.get("id"): hero for hero in heroes}
    anouk = by_id.get("hero.anouk", {})
    if anouk.get("metaphysics") != "origin_of_la_trame_still_unconfirmed":
        errors.append("Anouk: La Trame origin must remain unconfirmed")

    effrie = by_id.get("hero.effrie", {})
    expected_effrie_unknowns = {
        "tribe_name", "exact_territory", "language", "theology", "rites", "symbols",
        "dragon_pact", "dragon_ancestry", "power_origin", "veil_link"
    }
    if set(effrie.get("protected_unknowns", [])) != expected_effrie_unknowns:
        errors.append("Èffrie: protected unknowns changed")

    if "Conseil des Sept" not in fates.get("shared_fate", {}).get("what_they_do_not_create", []):
        errors.append("shared fate: Council of Seven prohibition missing")

    if manifest.get("complete") is not True:
        errors.append("manifest: explicit fate resolution not complete")
    if manifest.get("death_dates_locked") is not False:
        errors.append("manifest: death dates must remain open")
    if manifest.get("romances_locked_by_this_pass") is not False:
        errors.append("manifest: this pass must not lock romances")
    supersedes = " ".join(manifest.get("source_precedence", {}).get("supersedes_only", []))
    for token in ["post_campaign_fates_are_not_invented", "fate_after_campaign=open", "destins après la campagne"]:
        if token not in supersedes:
            errors.append(f"manifest: missing explicit precedence token {token}")

    relationship_rules = relationships.get("rules", {})
    if relationship_rules.get("romance_is_never_inferred_from_trust") is not True:
        errors.append("relationships: romance guardrail changed")

    still_open = set(fates.get("still_open", []))
    for required in ["dates de mort des Sept", "dernière rencontre exacte des sept ensemble", "cause ontologique de La Trame"]:
        if required not in still_open:
            errors.append(f"fates: required future space missing: {required}")

    return {"ok": not errors, "errors": errors, "hero_count": len(heroes)}


def main() -> int:
    report = run()
    if report["ok"]:
        print("Legendary Seven post-campaign audit: PASS")
        print(f"- heroes: {report['hero_count']}")
        return 0
    print("Legendary Seven post-campaign audit: FAIL")
    for error in report["errors"]:
        print(f"ERROR: {error}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
