from __future__ import annotations

import json
import unicodedata
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "veilleurs" / "v06"
EXPECTED_WATCHERS = ["ENT_WATCHER_NAYRA", "ENT_WATCHER_TAREK", "ENT_WATCHER_AISHA", "ENT_WATCHER_IDRIS"]
EXPECTED_NAMES = ["Nayra Orun", "Tarek Senn", "Aïsha Maren", "Idris Vael"]
OBSOLETE_TOKENS = [
    "ENT_WATCHER_SAHEN", "ENT_WATCHER_MIRA", "ENT_WATCHER_NAREM", "ENT_WATCHER_YSRA",
    "Sahen Varo", "Mira Sen", "Narem Osh", "Ysra Nahal",
]
STATS = {"FOR", "TEC", "PRE", "MOB", "GAR", "RES", "PER", "VIG"}
ZONES = {"head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"}
LEVELS = [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 35, 39, 44, 49]


def load(name: str):
    return json.loads((DATA / name).read_text(encoding="utf-8"))


def _ascii_upper(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    return "".join(char for char in normalized if not unicodedata.combining(char)).upper().replace(" ", "_")


def _source_path(source: str) -> Path:
    text = source.removeprefix("res://")
    return ROOT / text


def main() -> int:
    results: list[tuple[str, bool]] = []

    def test(name: str, condition: bool) -> None:
        results.append((name, bool(condition)))

    watchers_path = DATA / "watchers.json"
    enemies_path = DATA / "enemies_24_definitions.json"
    constants_path = DATA / "combat_constants.json"
    catalog_path = DATA / "watcher_tree_catalog.json"
    loadouts_path = DATA / "starter_loadouts_watchers.json"
    encounters_path = DATA / "encounters_64.json"

    test("01 watchers file", watchers_path.is_file())
    test("02 enemies file", enemies_path.is_file())
    test("03 combat constants file", constants_path.is_file())
    test("04 canonical tree manifest file", catalog_path.is_file())
    test("05 starter loadouts file", loadouts_path.is_file())

    watchers_payload = load("watchers.json")
    enemies_payload = load("enemies_24_definitions.json")
    constants = load("combat_constants.json")
    manifest = load("watcher_tree_catalog.json")
    loadouts = load("starter_loadouts_watchers.json")
    test("06 all core JSON parsed", all(isinstance(x, dict) for x in [watchers_payload, enemies_payload, constants, manifest, loadouts]))

    watchers = watchers_payload.get("watchers", [])
    enemies = enemies_payload.get("enemies", [])
    watcher_ids = [w.get("entity_id") for w in watchers]
    watcher_names = [w.get("name_fr") for w in watchers]
    test("07 four Watchers", len(watchers) == 4)
    test("08 canonical Watcher IDs", watcher_ids == EXPECTED_WATCHERS)
    test("09 canonical Watcher names", watcher_names == EXPECTED_NAMES)
    test("10 eight Watcher stats", all(set(w.get("stats", {})) == STATS for w in watchers))
    test("11 six Watcher body zones", all(set(w.get("body_integrity", {})) == ZONES for w in watchers))
    test("12 three tree IDs per Watcher", all(len(w.get("tree_ids", [])) == 3 for w in watchers))

    enemy_ids = [e.get("entity_id") for e in enemies]
    test("13 24 enemies", len(enemies) == 24)
    test("14 unique enemy IDs", len(enemy_ids) == len(set(enemy_ids)))
    test("15 positive ThreatValue", all(float(e.get("threat_value", 0)) > 0 for e in enemies))
    test("16 eight enemy stats", all(set(e.get("stats", {})) == STATS for e in enemies))
    test("17 six enemy body zones", all(set(e.get("body_integrity", {})) == ZONES for e in enemies))
    test("18 six enemy families", len({e.get("family") for e in enemies}) == 6)

    grid = constants.get("grid", {})
    test("19 grid width 6", grid.get("width") == 6)
    test("20 grid height 5", grid.get("height") == 5)
    test("21 hit minimum 10", constants.get("hit_clamp", {}).get("min_percent") == 10)
    test("22 hit maximum 97", constants.get("hit_clamp", {}).get("max_percent") == 97)
    test("23 six zone modifiers", set(constants.get("zone_accuracy_mod", {})) == ZONES)
    memory = constants.get("memory_caps", {})
    test("24 bounded memory", memory.get("observations") == 8 and memory.get("events") == 6 and memory.get("relations") == 4)

    manifest_watchers = manifest.get("watchers", [])
    source_payloads: dict[str, dict] = {}
    source_load_ok = True
    for row in manifest_watchers:
        entity_id = str(row.get("entity_id", ""))
        path = _source_path(str(row.get("source", "")))
        try:
            source_payloads[entity_id] = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            source_load_ok = False

    generated_skill_ids: list[str] = []
    generated_tree_ids: set[str] = set()
    owner_counts: Counter[str] = Counter()
    all_tree_rows: list[tuple[str, str, dict]] = []
    canonical_ownership_ok = source_load_ok
    for row in manifest_watchers:
        entity_id = str(row.get("entity_id", ""))
        payload = source_payloads.get(entity_id, {})
        owner_name = str(payload.get("watcher_name", ""))
        short_id = entity_id.removeprefix("ENT_WATCHER_")
        trees = payload.get("trees", {})
        order = payload.get("tree_order", [])
        if not isinstance(trees, dict) or not isinstance(order, list):
            canonical_ownership_ok = False
            continue
        for tree_key in order:
            tree = trees.get(tree_key, {})
            all_tree_rows.append((entity_id, str(tree_key), tree))
            generated_tree_ids.add(f"TREE_{short_id}_{_ascii_upper(str(tree_key))}")
            for skill in tree.get("skills", []):
                if not isinstance(skill, list) or len(skill) < 4:
                    canonical_ownership_ok = False
                    continue
                generated_skill_ids.append(str(skill[0]))
                owner_counts[entity_id] += 1
                if str(skill[1]) != owner_name:
                    canonical_ownership_ok = False

    test(
        "25 canonical bridge markers",
        str(watchers_payload.get("schema_version", "")).startswith("0.6.2-canonical")
        and str(manifest.get("schema_version", "")).startswith("0.6.2-canonical")
        and source_load_ok,
    )
    test("26 twelve canonical trees", len(all_tree_rows) == 12 and manifest.get("tree_count") == 12)
    test("27 fifteen authored skills per tree", all(len(tree.get("skills", [])) == 15 for _, _, tree in all_tree_rows))
    test("28 exactly 180 canonical skills", len(generated_skill_ids) == 180 and manifest.get("skill_count") == 180)
    test("29 unique canonical skill IDs", len(generated_skill_ids) == len(set(generated_skill_ids)))
    test("30 45 skills per canonical Watcher", all(owner_counts.get(entity_id, 0) == 45 for entity_id in EXPECTED_WATCHERS))
    test("31 canonical unlock levels", manifest.get("unlock_levels") == LEVELS and all(sorted({int(skill[3]) for skill in tree.get("skills", [])}) == LEVELS for _, _, tree in all_tree_rows))
    test("32 unlock schedule is ordered and unique", len(LEVELS) == 15 and LEVELS == sorted(set(LEVELS)))
    test("33 first skill at level 1", LEVELS[0] == 1)
    test("34 final tree skill at level 49", LEVELS[-1] == 49)
    test("35 character cap remains 50", all(1 <= level <= 50 for level in LEVELS))

    watcher_tree_ids = {tree_id for watcher in watchers for tree_id in watcher.get("tree_ids", [])}
    test("36 exact canonical tree IDs", generated_tree_ids == watcher_tree_ids and len(generated_tree_ids) == 12)
    test("37 canonical skill ownership", canonical_ownership_ok and all(bool(skill_id) for skill_id in generated_skill_ids))
    test("38 canonical manifest maps four owners", {str(row.get("entity_id", "")) for row in manifest_watchers} == set(EXPECTED_WATCHERS) and set(owner_counts) == set(EXPECTED_WATCHERS))
    test("39 three manifest trees per Watcher", all(len(row.get("trees", [])) == 3 for row in manifest_watchers))
    test("40 canonical tree IDs unique", len(generated_tree_ids) == 12)

    active_paths = [
        watchers_path,
        catalog_path,
        loadouts_path,
        ROOT / "scripts" / "core" / "content_db.gd",
        ROOT / "scripts" / "core" / "veilleurs_tactical_combat_runtime.gd",
    ]
    active_corpus = "\n".join(path.read_text(encoding="utf-8") for path in active_paths if path.is_file())
    test("41 obsolete Watcher identities absent from active v0.6 data", not any(token in active_corpus for token in OBSOLETE_TOKENS))

    loadout_rows = {key: value for key, value in loadouts.items() if not key.startswith("_")}
    test("42 four starter loadouts", len(loadout_rows) == 4)
    test("43 starter loadouts reference canonical Watchers", set(loadout_rows) == set(EXPECTED_WATCHERS))

    runtime_paths = [
        "scripts/core/veilleurs_body_component.gd",
        "scripts/core/veilleurs_tactical_grid.gd",
        "scripts/core/veilleurs_tactical_combat_runtime.gd",
        "scripts/core/veilleurs_tactical_session.gd",
        "scripts/core/veilleurs_enemy_ai_v2.gd",
        "scripts/core/veilleurs_tactical_save_bridge.gd",
        "scripts/core/veilleurs_hybrid_generation_bridge.gd",
        "scripts/core/veilleurs_refuge_runtime.gd",
    ]
    test("44 tactical runtime components exist", all((ROOT / path).is_file() for path in runtime_paths))

    encounters_payload = load("encounters_64.json") if encounters_path.is_file() else {}
    encounters = encounters_payload.get("encounters", [])
    encounter_ids = [row.get("encounter_id") for row in encounters]
    archetypes = {row.get("archetype") for row in encounters}
    tiers_by_archetype = {
        archetype: {int(row.get("tier", 0)) for row in encounters if row.get("archetype") == archetype}
        for archetype in archetypes
    }
    test(
        "45 exactly 64 encounters across eight 1-8 archetypes",
        encounters_payload.get("count") == 64
        and len(encounters) == 64
        and len(encounter_ids) == len(set(encounter_ids)) == 64
        and len(archetypes) == 8
        and all(tiers == set(range(1, 9)) for tiers in tiers_by_archetype.values()),
    )

    threat_by_enemy = {row["entity_id"]: float(row["threat_value"]) for row in enemies}
    encounter_refs_valid = True
    for row in encounters:
        ids = row.get("enemy_ids", [])
        if not ids or not all(enemy_id in threat_by_enemy for enemy_id in ids):
            encounter_refs_valid = False
            break
        computed = sum(threat_by_enemy[enemy_id] for enemy_id in ids)
        if abs(computed - float(row.get("threat_budget", computed))) > 0.75:
            encounter_refs_valid = False
            break
        if not bool(row.get("retreat_viable", False)) or not str(row.get("counterplay", "")).strip():
            encounter_refs_valid = False
            break
        if row.get("archetype") == "mixed_memory" and not bool(row.get("memoriel_allowed", False)):
            encounter_refs_valid = False
            break
    test("46 encounter references threat retreat and counterplay valid", encounter_refs_valid)

    playable_paths = [
        "scripts/ui/veilleurs_tactical_demo.gd",
        "scripts/ui/veilleurs_tactical_ui.gd",
        "scenes/veilleurs/v06_tactical_demo.tscn",
        "scenes/veilleurs/v06_tactical_combat.tscn",
        "scripts/core/veilleurs_tactical_save_bridge.gd",
    ]
    test("47 playable save surface exists", all((ROOT / path).is_file() for path in playable_paths))
    test("48 Godot smoke scene exists", (ROOT / "scenes/tests/veilleurs_v06_tactical_smoke.tscn").is_file())

    if len(results) != 48:
        raise RuntimeError(f"Tests_48 contract drifted: {len(results)} checks")

    failed = [name for name, ok in results if not ok]
    for name, ok in results:
        print(f"{'PASS' if ok else 'FAIL'} {name}")
    if failed:
        print(f"VEILLEURS_V06_TESTS48_FAILED: {len(failed)}")
        return 1
    print("VEILLEURS_V06_TESTS48_OK: 48/48")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
