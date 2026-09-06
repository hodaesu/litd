from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "veilleurs" / "v06"
EXPECTED_WATCHERS = ["ENT_WATCHER_SAHEN", "ENT_WATCHER_MIRA", "ENT_WATCHER_NAREM", "ENT_WATCHER_YSRA"]
STATS = {"FOR", "TEC", "PRE", "MOB", "GAR", "RES", "PER", "VIG"}
ZONES = {"head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"}
LEVELS = [1, 3, 5, 7, 9, 11, 13, 18, 21, 24, 28, 33, 38, 44, 50]


def load(name: str):
    return json.loads((DATA / name).read_text(encoding="utf-8"))


def main() -> int:
    results: list[tuple[str, bool]] = []

    def test(name: str, condition: bool) -> None:
        results.append((name, bool(condition)))

    watchers_path = DATA / "watchers.json"
    enemies_path = DATA / "enemies_24_definitions.json"
    constants_path = DATA / "combat_constants.json"
    catalog_path = DATA / "watcher_tree_catalog.json"
    loadouts_path = DATA / "starter_loadouts_watchers.json"

    test("01 watchers file", watchers_path.is_file())
    test("02 enemies file", enemies_path.is_file())
    test("03 combat constants file", constants_path.is_file())
    test("04 tree catalog file", catalog_path.is_file())
    test("05 starter loadouts file", loadouts_path.is_file())

    watchers_payload = load("watchers.json")
    enemies_payload = load("enemies_24_definitions.json")
    constants = load("combat_constants.json")
    catalog = load("watcher_tree_catalog.json")
    loadouts = load("starter_loadouts_watchers.json")
    test("06 all JSON parsed", all(isinstance(x, dict) for x in [watchers_payload, enemies_payload, constants, catalog, loadouts]))

    watchers = watchers_payload["watchers"]
    enemies = enemies_payload["enemies"]
    watcher_ids = [w["entity_id"] for w in watchers]
    test("07 four Watchers", len(watchers) == 4)
    test("08 canonical Watcher IDs", watcher_ids == EXPECTED_WATCHERS)
    test("09 Watcher names", all(w.get("name_fr") for w in watchers))
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

    trees = catalog["trees"]
    test("25 12 Watcher trees", len(trees) == 12 and catalog.get("tree_count") == 12)
    test("26 15 names per tree", all(len(t.get("names", [])) == 15 for t in trees))
    test("27 15 activation modes per tree", all(len(t.get("activation", [])) == 15 for t in trees))
    test("28 15 action types per tree", all(len(t.get("action", [])) == 15 for t in trees))
    prefixes = [t.get("prefix") for t in trees]
    test("29 unique tree prefixes", len(prefixes) == len(set(prefixes)))

    skill_ids: list[str] = []
    skills_by_owner = {wid: 0 for wid in EXPECTED_WATCHERS}
    for tree in trees:
        prefix = tree["prefix"]
        owner = tree["entity_id"]
        for index in range(1, 16):
            skill_ids.append(f"{prefix}_{index:02d}")
            skills_by_owner[owner] += 1
    test("30 unique generated skill IDs", len(skill_ids) == len(set(skill_ids)))
    test("31 exactly 180 generated skills", len(skill_ids) == 180 and catalog.get("skill_count") == 180)
    test("32 45 skills per Watcher", all(count == 45 for count in skills_by_owner.values()))
    test("33 canonical unlock levels", catalog.get("unlock_levels") == LEVELS)
    test("34 unlock levels strictly increase", all(a < b for a, b in zip(LEVELS, LEVELS[1:])))
    test("35 level cap reached", LEVELS[-1] == 50)
    test("36 first skill at level 1", LEVELS[0] == 1)
    tree_owner_counts = {wid: sum(1 for t in trees if t.get("entity_id") == wid) for wid in EXPECTED_WATCHERS}
    test("37 three catalog trees per Watcher", all(count == 3 for count in tree_owner_counts.values()))
    test("38 two anatomy trees", sum(1 for t in trees if t.get("profile") == "anatomy") == 2)
    test("39 three observation trees", sum(1 for t in trees if t.get("profile") == "observe") == 3)
    test("40 two guard trees", sum(1 for t in trees if t.get("profile") == "guard") == 2)

    corpus = watchers_path.read_text(encoding="utf-8") + catalog_path.read_text(encoding="utf-8")
    legacy_names = ["Nayra Orun", "Tarek Senn", "Aïsha Maren", "Idris Vael"]
    test("41 no legacy Watcher identities in v0.6 data", not any(name in corpus for name in legacy_names))
    test("42 four starter loadouts", len(loadouts) == 4)
    test("43 starter loadouts reference canonical Watchers", set(loadouts) == set(EXPECTED_WATCHERS))

    test("44 BodyComponent exists", (ROOT / "scripts/core/veilleurs_body_component.gd").is_file())
    test("45 TacticalGrid exists", (ROOT / "scripts/core/veilleurs_tactical_grid.gd").is_file())
    test("46 TacticalRuntime exists", (ROOT / "scripts/core/veilleurs_tactical_combat_runtime.gd").is_file())
    test("47 TacticalSession exists", (ROOT / "scripts/core/veilleurs_tactical_session.gd").is_file())
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
