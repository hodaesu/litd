from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKILL_DIR = ROOT / "data" / "veilleurs" / "skills"
WATCHERS = {
    "nayra_orun": ("Nayra Orun", ["Bastion", "Brisure", "Serment"]),
    "tarek_senn": ("Tarek Senn", ["Traque", "Entaille", "Disparition"]),
    "aisha_maren": ("Aïsha Maren", ["Anatomie", "Suture", "Hémocorde"]),
    "idris_vael": ("Idris Vael", ["Sentence", "Concorde", "Dissidence"]),
}
EXPECTED_LEVELS = [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 35, 39, 44, 49]
SOURCE_SHA = "0b543d9b9433405ecc230f86de5c522f16b7a29d9db9d60f301b6d45a2b5b1b4"
CORPSE_SKILLS = {"AÏ-ANA-12", "TA-DIS-12"}
EXPECTED_TREE_RESOLVERS = {
    "Bastion", "Brisure", "Serment", "Traque", "Entaille", "Disparition",
    "Anatomie", "Suture", "Hémocorde", "Sentence", "Concorde", "Dissidence",
}


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _row(fields: list, values: list) -> dict:
    return {str(fields[i]): values[i] for i in range(min(len(fields), len(values)))}


def _tags(text: object) -> list[str]:
    return [part.strip() for part in str(text or "").split(";") if part.strip()]


def _fingerprint(row: dict, override: dict | None = None) -> str:
    override = override or {}
    tags_text = override.get("Tags", row.get("Tags", ""))
    canonical = {
        "id": str(row.get("ID", "")),
        "tree": str(row.get("Arbre", "")),
        "level": int(row.get("Niveau", 0)),
        "name": str(row.get("Nom", "")),
        "type": str(row.get("Type", "")),
        "target": str(row.get("Cible", "")),
        "tags": _tags(tags_text),
    }
    body = json.dumps(canonical, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    return hashlib.sha256(body.encode("utf-8")).hexdigest()


def audit() -> list[str]:
    errors: list[str] = []
    contract = _load(SKILL_DIR / "source_contract.json")
    resolver = _load(SKILL_DIR / "resolver_contract.json")
    overrides = _load(SKILL_DIR / "canonical_overrides.json")
    polish = _load(ROOT / "data" / "veilleurs" / "polish_manifest.json")
    skill_overrides = overrides.get("skill_overrides", {})

    if contract.get("source_sha256") != SOURCE_SHA:
        errors.append("source_sha_changed")
    if contract.get("levels") != EXPECTED_LEVELS:
        errors.append("source_level_sequence_changed")
    if set(contract.get("watchers", {})) != set(WATCHERS):
        errors.append("source_watcher_set_changed")
    if "aurelien" in json.dumps(contract, ensure_ascii=False).lower():
        errors.append("aurelien_must_not_be_in_veilleurs_contract")

    all_ids: set[str] = set()
    all_types: set[str] = set()
    actual_ultimates: dict[str, str] = {}
    skill_rows: dict[str, dict] = {}
    total_skills = total_trees = total_ults = 0

    for watcher_id, (watcher_name, trees) in WATCHERS.items():
        path = SKILL_DIR / f"{watcher_id}.json"
        data = _load(path)
        if data.get("watcher_id") != watcher_id:
            errors.append(f"wrong_watcher_id:{watcher_id}")
        if data.get("watcher_name") != watcher_name:
            errors.append(f"wrong_watcher_name:{watcher_id}")
        if len(data.get("tree_order", [])) != 3:
            errors.append(f"tree_order_count:{watcher_id}")
        fields = data.get("fields", [])
        tree_map = data.get("trees", {})
        actual_tree_names = [str(tree_map.get(str(key), {}).get("name", "")) for key in data.get("tree_order", [])]
        if actual_tree_names != trees:
            errors.append(f"tree_order_names:{watcher_id}:{actual_tree_names}")

        source_watcher = contract.get("watchers", {}).get(watcher_id, {})
        if source_watcher.get("name") != watcher_name:
            errors.append(f"source_name:{watcher_id}")
        if source_watcher.get("tree_order") != trees:
            errors.append(f"source_tree_order:{watcher_id}")
        expected_fingerprints = source_watcher.get("skills", {})
        watcher_count = 0

        for key in data.get("tree_order", []):
            tree = tree_map.get(str(key), {})
            tree_name = str(tree.get("name", ""))
            rows = tree.get("skills", [])
            total_trees += 1
            if len(rows) != 15:
                errors.append(f"tree_skill_count:{watcher_id}:{tree_name}:{len(rows)}")
            levels: list[int] = []
            for values in rows:
                row = _row(fields, values)
                skill_id = str(row.get("ID", ""))
                if not skill_id:
                    errors.append(f"empty_skill_id:{watcher_id}:{tree_name}")
                    continue
                if skill_id in all_ids:
                    errors.append(f"duplicate_skill_id:{skill_id}")
                all_ids.add(skill_id)
                skill_rows[skill_id] = row
                watcher_count += 1
                total_skills += 1
                levels.append(int(row.get("Niveau", 0)))
                all_types.add(str(row.get("Type", "")))
                if str(row.get("Veilleur", "")) != watcher_name:
                    errors.append(f"skill_watcher:{skill_id}")
                if str(row.get("Arbre", "")) != tree_name:
                    errors.append(f"skill_tree:{skill_id}")
                expected = expected_fingerprints.get(skill_id)
                actual = _fingerprint(row, skill_overrides.get(skill_id))
                if expected is None:
                    errors.append(f"skill_missing_source_fingerprint:{skill_id}")
                elif expected != actual:
                    errors.append(f"skill_source_drift:{skill_id}")
            if levels != EXPECTED_LEVELS:
                errors.append(f"level_sequence:{watcher_id}:{tree_name}:{levels}")

            ultimate = tree.get("ultimate", {})
            total_ults += 1
            ultimate_name = str(ultimate.get("name", ""))
            actual_ultimates[tree_name] = ultimate_name
            expected_ultimate = source_watcher.get("ultimates", {}).get(tree_name)
            if ultimate_name != expected_ultimate:
                errors.append(f"ultimate_name:{watcher_id}:{tree_name}")
            charges = str(ultimate.get("charges", ""))
            if "N16=1" not in charges or "N32=2" not in charges or "N48=3" not in charges:
                errors.append(f"ultimate_charges:{watcher_id}:{tree_name}")
            limit = str(ultimate.get("combat_limit", "")).lower()
            if "1 fois par rencontre" not in limit:
                errors.append(f"ultimate_encounter_limit:{watcher_id}:{tree_name}")
            guardrail = str(ultimate.get("guardrail", "")).lower()
            if "invuln" not in guardrail or "résurrection" not in guardrail:
                errors.append(f"ultimate_guardrail:{watcher_id}:{tree_name}")

        if watcher_count != 45:
            errors.append(f"watcher_skill_count:{watcher_id}:{watcher_count}")
        if set(expected_fingerprints) != {sid for sid, row in skill_rows.items() if str(row.get("Veilleur", "")) == watcher_name}:
            errors.append(f"source_fingerprint_id_set:{watcher_id}")

    if total_trees != 12:
        errors.append(f"total_trees:{total_trees}")
    if total_skills != 180:
        errors.append(f"total_skills:{total_skills}")
    if total_ults != 12:
        errors.append(f"total_ultimates:{total_ults}")

    resolver_policy = resolver.get("policy", {})
    if resolver_policy.get("no_silent_generic_fallback") is not True:
        errors.append("resolver_generic_fallback_forbidden")
    if set(resolver.get("tree_families", {})) != EXPECTED_TREE_RESOLVERS:
        errors.append("resolver_tree_families_incomplete")
    activation = resolver.get("activation_by_type", {})
    if not all_types <= set(activation):
        errors.append(f"resolver_types_missing:{sorted(all_types - set(activation))}")
    exact = resolver.get("skill_overrides", {})
    if set(exact) != CORPSE_SKILLS:
        errors.append(f"implemented_skill_override_set:{sorted(exact)}")
    for skill_id in CORPSE_SKILLS:
        item = exact.get(skill_id, {})
        if item.get("status") != "implemented" or item.get("activation_mode") != "context_action":
            errors.append(f"corpse_resolver_not_implemented:{skill_id}")
    if str(skill_rows.get("AÏ-ANA-12", {}).get("Cible", "")).lower() != "cadavre":
        errors.append("aisha_corpse_target_changed")
    tarek_tags = _tags(skill_overrides.get("TA-DIS-12", {}).get("Tags", skill_rows.get("TA-DIS-12", {}).get("Tags", "")))
    if "CADAVRE" not in tarek_tags:
        errors.append("tarek_corpse_tag_missing")

    input_parity = polish.get("input_parity", {})
    for key in ("same_gameplay_all_platforms", "irreversible_action_requires_second_confirmation"):
        if input_parity.get(key) is not True:
            errors.append(f"polish_required:{key}")
    for key in ("long_press_required", "hover_required", "controller_pointer_required"):
        if input_parity.get(key) is not False:
            errors.append(f"polish_forbidden:{key}")
    if int(input_parity.get("touch_target_min_points", 0)) < 48:
        errors.append("touch_target_below_48")
    if int(input_parity.get("vs001_primary_target_points", 0)) < 54:
        errors.append("vs001_primary_target_below_54")

    perf = polish.get("performance_baselines", {})
    soft, hard = int(perf.get("corpse_visible_soft_budget", 0)), int(perf.get("corpse_visible_hard_budget", 0))
    if soft <= 0 or hard < soft:
        errors.append("corpse_visual_budget_invalid")
    ultimate_assets = polish.get("ultimate_assets", [])
    if len(ultimate_assets) != 12:
        errors.append(f"polish_ultimate_count:{len(ultimate_assets)}")
    polish_names = set()
    for item in ultimate_assets:
        polish_names.add(str(item.get("name", "")))
        beats = item.get("beats", [])
        if len(beats) != 8 or any(not str(beat).strip() for beat in beats):
            errors.append(f"ultimate_beats:{item.get('name','?')}")
        slots = item.get("asset_slots", {})
        if set(slots) != {"animation", "camera", "audio", "haptic", "vfx"} or any(value != "required" for value in slots.values()):
            errors.append(f"ultimate_asset_slots:{item.get('name','?')}")
    if polish_names != set(actual_ultimates.values()):
        errors.append("polish_ultimate_names_do_not_match_catalog")

    project_text = (ROOT / "project.godot").read_text(encoding="utf-8")
    for autoload in ("VeilleursSkillCatalog", "VeilleursSkillResolverRouter", "VeilleursCorpseInteractionRuntime"):
        if f"{autoload}=" not in project_text:
            errors.append(f"missing_autoload:{autoload}")

    playable = (ROOT / "scenes" / "world" / "veilleurs" / "voices_under_sanctuary_playable.tscn").read_text(encoding="utf-8")
    for token in ("veilleurs_corpse_context_ui.gd", "veilleurs_skill_tree_overlay.gd"):
        if token not in playable:
            errors.append(f"playable_ui_missing:{token}")

    corpse_ui = (ROOT / "scripts" / "ui" / "veilleurs_corpse_context_ui.gd").read_text(encoding="utf-8")
    for token in ("CONFIRMER", "ANNULER", "custom_minimum_size = Vector2(320, 58)"):
        if token not in corpse_ui:
            errors.append(f"corpse_confirmation_ui:{token}")
    if "long_press" in corpse_ui.lower() or "hover" in corpse_ui.lower():
        errors.append("corpse_ui_must_not_require_long_press_or_hover")

    persistence = (ROOT / "scripts" / "world" / "veilleurs_vs001_persistence_layer.gd").read_text(encoding="utf-8")
    if "corpse_offset" not in persistence or "materialize_corpses" not in persistence:
        errors.append("corpse_physical_persistence_missing")

    skill_ui = (ROOT / "scripts" / "ui" / "veilleurs_skill_tree_overlay.gd").read_text(encoding="utf-8")
    if "HeroSkillManager.branches_for" not in skill_ui or "resolver_status" not in skill_ui:
        errors.append("canonical_skill_ui_contract_missing")

    return errors


def main() -> int:
    errors = audit()
    print(json.dumps({"system": "veilleurs_canonical_skills", "ok": not errors, "errors": errors}, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
