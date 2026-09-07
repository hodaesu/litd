from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "veilleurs" / "v06"
CANON = ROOT / "data" / "veilleurs" / "skills"
EXPECTED_WATCHERS = ["ENT_WATCHER_NAYRA", "ENT_WATCHER_TAREK", "ENT_WATCHER_AISHA", "ENT_WATCHER_IDRIS"]
EXPECTED_NAMES = ["Nayra Orun", "Tarek Senn", "Aïsha Maren", "Idris Vael"]
CANONICAL_FILES = ["nayra_orun.json", "tarek_senn.json", "aisha_maren.json", "idris_vael.json"]
STATS = {"FOR", "TEC", "PRE", "MOB", "GAR", "RES", "PER", "VIG"}
ZONES = {"head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"}
LEVELS = [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 35, 39, 44, 49]


def load(name: str):
    return json.loads((DATA / name).read_text(encoding="utf-8"))


def load_canon(name: str):
    return json.loads((CANON / name).read_text(encoding="utf-8"))


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

    watchers = watchers_payload["watchers"]
    enemies = enemies_payload["enemies"]
    watcher_ids = [w["entity_id"] for w in watchers]
    watcher_names = [w["name_fr"] for w in watchers]
    test("07 four Watchers", len(watchers) == 4)
    test("08 canonical Watcher IDs", watcher_ids == EXPECTED_WATCHERS)
    test("09 canonical Watcher names", watcher_names == EXPECTED_NAMES)
    test("10 eight Watcher stats", all(set(w.get("stats", {})) == STATS for w in watchers))
    test("11 six Watcher body zones", all(set(w.get("body_integrity", {})) == ZONES for w in watchers))
    test("12 three tree IDs per Watcher", all(len(w.get("tree_ids", [])) == 3 for w in watchers))

    enemy_ids = [e["entity_id"] for e in enemies]
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

    canonical_payloads = [load_canon(name) for name in CANONICAL_FILES]
    tree_rows: list[tuple[str, dict]] = []
    skill_ids: list[str] = []
    skill_levels: list[int] = []
    owner_counts: list[int] = []
    for payload in canonical_payloads:
        owner_count = 0
        for tree_key in payload.get("tree_order", []):
            tree = payload.get("trees", {}).get(tree_key, {})
            tree_rows.append((tree_key, tree))
            fields = payload.get("fields", [])
            id_index = fields.index("ID")
            level_index = fields.index("Niveau")
            rows = tree.get("skills", [])
            owner_count += len(rows)
            for row in rows:
                skill_ids.append(str(row[id_index]))
                skill_levels.append(int(row[level_index]))
        owner_counts.append(owner_count)
    test("25 four canonical source files", len(canonical_payloads) == 4 and all((CANON / f).is_file() for f in CANONICAL_FILES))
    test("26 twelve canonical trees", len(tree_rows) == 12 and manifest.get("tree_count") == 12)
    test("27 fifteen skills per canonical tree", all(len(tree.get("skills", [])) == 15 for _, tree in tree_rows))
    test("28 exactly 180 canonical skills", len(skill_ids) == 180 and manifest.get("skill_count") == 180)
    test("29 unique canonical skill IDs", len(skill_ids) == len(set(skill_ids)))
    test("30 45 skills per canonical Watcher", owner_counts == [45, 45, 45, 45])
    test("31 canonical unlock levels", manifest.get("unlock_levels") == LEVELS)
    test("32 every tree follows canonical levels", all([int(row[payload.get("fields", []).index("Niveau")]) for row in tree.get("skills", [])] == LEVELS for payload in canonical_payloads for tree in [payload.get("trees", {}).get(key, {}) for key in payload.get("tree_order", [])]))
    test("33 first skill at level 1", min(skill_levels) == 1)
    test("34 final tree skill at level 49", max(skill_levels) == 49)
    test("35 character cap remains 50", 50 > max(skill_levels))
    expected_tree_names = {"Bastion","Brisure","Serment","Traque","Entaille","Disparition","Anatomie","Suture","Hémocorde","Sentence","Concorde","Dissidence"}
    test("36 exact canonical tree names", {str(tree.get("name", "")) for _, tree in tree_rows} == expected_tree_names)
    test("37 canonical skill ID families", any(x.startswith("NA-BAS-") for x in skill_ids) and any(x.startswith("TA-TRA-") for x in skill_ids) and any(x.startswith("AÏ-ANA-") for x in skill_ids) and any(x.startswith("ID-SEN-") for x in skill_ids))
    test("38 canonical manifest maps four owners", [row.get("entity_id") for row in manifest.get("watchers", [])] == EXPECTED_WATCHERS)
    test("39 three manifest trees per Watcher", all(len(row.get("trees", [])) == 3 for row in manifest.get("watchers", [])))
    test("40 canonical source paths unique", len({row.get("source") for row in manifest.get("watchers", [])}) == 4)

    active_corpus = watchers_path.read_text(encoding="utf-8") + catalog_path.read_text(encoding="utf-8")
    alternate_names = ["Sahen Varo", "Mira Sen", "Narem Osh", "Ysra Nahal"]
    test("41 alternate Watcher identities absent from active v0.6 data", not any(name in active_corpus for name in alternate_names))
    test("42 four starter loadouts", len(loadouts) == 4)
    test("43 starter loadouts reference canonical Watchers", set(loadouts) == set(EXPECTED_WATCHERS))

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
    test("44 tactical runtime components exist", all((ROOT / p).is_file() for p in runtime_paths))

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
    test("47 playable save surface exists", all((ROOT / p).is_file() for p in playable_paths))
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
