#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
V06 = ROOT / "data" / "veilleurs" / "v06"
V07 = ROOT / "data" / "veilleurs" / "v07"
DUNGEON_FILES = [
    "dungeon_khar_sen_expanded.json",
    "dungeon_02_seuil_erode.json",
    "dungeon_03_cloitre_voix.json",
    "dungeon_04_jardin_mues.json",
    "dungeon_tribunal_cendres.json",
    "dungeon_archives_aveugles.json",
]
ALLOWED_BANDS = {"LOW", "STANDARD", "HIGH", "SEVERE"}


def load(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def check(condition, message, failures):
    if not condition:
        failures.append(message)


def validate_dungeon(dungeon, boss_ids, failures):
    dungeon_id = dungeon.get("dungeon_id", "")
    nodes = dungeon.get("nodes", [])
    node_ids = {row.get("node_id") for row in nodes}
    check(dungeon_id != "", "dungeon id missing", failures)
    check(dungeon.get("entry_node") in node_ids, f"{dungeon_id} entry missing", failures)
    check(len(node_ids) == len(nodes), f"{dungeon_id} duplicate/empty node ids", failures)
    terminal_count = 0
    boss_nodes = []
    for row in nodes:
        for next_id in row.get("next", []):
            check(next_id in node_ids, f"{dungeon_id} orphan edge {row.get('node_id')}->{next_id}", failures)
        if not row.get("next", []):
            terminal_count += 1
        if row.get("encounter") and row.get("kind") != "boss":
            check(row.get("band") in ALLOWED_BANDS, f"{dungeon_id} invalid band at {row.get('node_id')}", failures)
            check(row.get("variant") in (1, 2), f"{dungeon_id} invalid variant at {row.get('node_id')}", failures)
        if row.get("kind") == "boss":
            boss_nodes.append(row)
            check(row.get("boss_id", dungeon.get("boss_id")) in boss_ids, f"{dungeon_id} invalid boss ref", failures)
    check(terminal_count >= 1, f"{dungeon_id} has no terminal node", failures)
    if dungeon.get("boss_id"):
        check(len(boss_nodes) == 1, f"{dungeon_id} must contain exactly one boss node", failures)
        check(boss_nodes[0].get("boss_id", dungeon.get("boss_id")) == dungeon.get("boss_id"), f"{dungeon_id} boss node mismatch", failures)


def main():
    failures = []
    enemies = load(V06 / "enemies_24_definitions.json")["enemies"]
    enemy_ids = {row["entity_id"] for row in enemies}
    watchers = load(V06 / "watchers.json")["watchers"]
    watcher_ids = {row["entity_id"] for row in watchers}
    watcher_trees = load(V06 / "watcher_tree_catalog.json")
    enemy_trees = load(V07 / "enemy_tree_catalog.json")
    profiles = load(V07 / "enemy_skill_profiles.json")["profiles"]
    bosses = load(V07 / "bosses_5_definitions.json")["bosses"]
    boss_ids = {row["entity_id"] for row in bosses}
    boss_trees = load(V07 / "boss_tree_catalog.json")
    ultimates = load(V07 / "ultimates_99.json")
    recruitment = load(V07 / "recruitment_rules.json")
    progression = load(V07 / "progression_1_50.json")
    archives = load(V07 / "archives_system.json")
    economy = load(V07 / "economy_refuge_rules.json")
    roadmap = load(V07 / "dungeon_roadmap.json")
    dungeons = [load(V07 / filename) for filename in DUNGEON_FILES]

    check(len(watcher_ids) == 4, "expected four Watchers", failures)
    check(len(enemy_ids) == 24, "expected 24 standard enemies", failures)
    check(len(enemy_trees["trees"]) == 72, "expected 72 enemy trees", failures)
    check(enemy_trees.get("skill_count") == 1080, "expected 1080 enemy skills", failures)
    check(len(boss_ids) == 5, "expected five bosses", failures)
    check(len(boss_trees["trees"]) == 15, "expected 15 boss trees", failures)
    check(boss_trees.get("skill_count") == 225, "expected 225 boss skills", failures)
    check(watcher_trees.get("skill_count") == 180, "expected 180 Watcher skills", failures)
    check(180 + 1080 + 225 == 1485, "normal skill arithmetic mismatch", failures)

    seen_tree_ids = set()
    seen_prefixes = set()
    enemy_partition = {entity_id: 0 for entity_id in enemy_ids}
    boss_partition = {entity_id: 0 for entity_id in boss_ids}
    for row in enemy_trees["trees"]:
        tree_id = row.get("tree_id")
        profile = row.get("profile")
        check(tree_id not in seen_tree_ids, f"duplicate tree {tree_id}", failures)
        seen_tree_ids.add(tree_id)
        check(row.get("prefix") not in seen_prefixes, f"duplicate prefix {row.get('prefix')}", failures)
        seen_prefixes.add(row.get("prefix"))
        check(row.get("entity_id") in enemy_ids, f"unknown enemy owner {row.get('entity_id')}", failures)
        check(profile in profiles, f"missing profile {profile}", failures)
        if row.get("entity_id") in enemy_partition:
            enemy_partition[row["entity_id"]] += 1
    for row in boss_trees["trees"]:
        tree_id = row.get("tree_id")
        profile = row.get("profile")
        check(tree_id not in seen_tree_ids, f"duplicate tree {tree_id}", failures)
        seen_tree_ids.add(tree_id)
        check(row.get("prefix") not in seen_prefixes, f"duplicate prefix {row.get('prefix')}", failures)
        seen_prefixes.add(row.get("prefix"))
        check(row.get("entity_id") in boss_ids, f"unknown boss owner {row.get('entity_id')}", failures)
        check(profile in profiles, f"missing boss profile {profile}", failures)
        if row.get("entity_id") in boss_partition:
            boss_partition[row["entity_id"]] += 1

    for entity_id, count in enemy_partition.items():
        check(count == 3, f"enemy {entity_id} has {count} trees", failures)
    for entity_id, count in boss_partition.items():
        check(count == 3, f"boss {entity_id} has {count} trees", failures)

    for profile_id, profile in profiles.items():
        for key in ("names", "activation", "action"):
            check(len(profile.get(key, [])) == 15, f"profile {profile_id} invalid {key}", failures)
        check(int(profile.get("range", 0)) >= 1, f"profile {profile_id} invalid range", failures)

    all_entity_ids = watcher_ids | enemy_ids | boss_ids
    ultimate_rows = ultimates.get("ultimates", [])
    check(ultimates.get("count") == 99 and len(ultimate_rows) == 99, "expected 99 Ultimates", failures)
    ultimate_ids = [row.get("ultimate_id") for row in ultimate_rows]
    check(len(set(ultimate_ids)) == 99, "Ultimate IDs must be unique", failures)
    ultimate_partition = {entity_id: [] for entity_id in all_entity_ids}
    for row in ultimate_rows:
        entity_id = row.get("entity_id")
        check(entity_id in all_entity_ids, f"unknown Ultimate owner {entity_id}", failures)
        if entity_id in ultimate_partition:
            ultimate_partition[entity_id].append(row)
        check(row.get("unlock_level") == 16, f"{row.get('ultimate_id')} unlock must be 16", failures)
        check(row.get("charges_by_level") == {"16": 1, "32": 2, "48": 3}, f"{row.get('ultimate_id')} charge schedule mismatch", failures)
        if entity_id in enemy_ids | boss_ids:
            check(row.get("telegraph_required") is True, f"{row.get('ultimate_id')} must telegraph", failures)
            check(row.get("counterplay_required") is True, f"{row.get('ultimate_id')} needs counterplay", failures)
    for entity_id, rows in ultimate_partition.items():
        check(len(rows) == 3, f"{entity_id} must have three Ultimates", failures)
        check(sorted(row.get("tree_slot") for row in rows) == [1, 2, 3], f"{entity_id} Ultimate slots invalid", failures)

    check(all(not bool(row.get("recruitable", True)) for row in bosses), "boss recruitment must be disabled", failures)
    check(recruitment.get("max_recruits_per_expedition") == 2, "recruit cap per expedition must be 2", failures)
    check(recruitment.get("refuge_recruit_cap") == 12, "refuge recruit cap must be 12", failures)
    check(set(recruitment.get("families", {}).keys()) == {"GOULES","PORTE_CENDRES","ECHOS","PARASITES","BETES_ALTEREES","HUMAINS_DEVOYES"}, "recruitment family coverage incomplete", failures)
    check(progression.get("level_cap") == 50, "level cap must be 50", failures)
    check(progression.get("ultimates", {}).get("charges_by_level") == {"16": 1, "32": 2, "48": 3}, "ultimate charge schedule mismatch", failures)
    check(len(archives.get("tabs", [])) == 5, "Archives must expose five core tabs", failures)
    check(economy.get("emergency_reserve", {}).get("cannot_generate_profit") is True, "emergency reserve must be non-profitable", failures)

    check(len(dungeons) == 6, "exactly six production dungeon files required", failures)
    dungeon_ids = {row.get("dungeon_id") for row in dungeons}
    check(len(dungeon_ids) == 6, "production dungeon IDs must be unique", failures)
    for dungeon in dungeons:
        validate_dungeon(dungeon, boss_ids, failures)
    khar = dungeons[0]
    check(len(khar.get("nodes", [])) == 18, "expanded Khar-Sen must contain 18 nodes", failures)
    check(len(roadmap.get("dungeons", [])) == 6, "dungeon roadmap must contain six dungeons", failures)
    roadmap_bosses = {row.get("boss_id") for row in roadmap["dungeons"] if row.get("boss_id")}
    check(roadmap_bosses == boss_ids, "roadmap must assign every canonical boss exactly once", failures)

    if failures:
        for failure in failures:
            print("FAIL:", failure)
        raise SystemExit(1)
    print("VEILLEURS_V07_CONTENT_AUDIT_OK")
    print("4 Watchers | 24 enemies | 5 bosses")
    print("72 enemy trees | 15 boss trees | 1485 normal skills")
    print("99 Ultimates | 6 validated dungeon graphs")
    print("Recruitment, progression, Archives and Refuge contracts valid")


if __name__ == "__main__":
    main()
