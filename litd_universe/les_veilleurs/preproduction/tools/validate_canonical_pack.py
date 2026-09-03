#!/usr/bin/env python3
"""Static validation for the extracted LITD: Les Veilleurs canonical pre-PC pack.

Usage:
    python validate_canonical_pack.py /path/to/litd_canonical_pack_2026-09-03

This validates source structure only. It does not replace Godot runtime tests.
"""

from __future__ import annotations

import argparse
import collections
import json
import os
import sys
from pathlib import Path

SOURCE_WORKBOOK = "LITD_Les_Veilleurs_Referentiel_Combat_Maitre_Narratif.xlsx"
EXPECTED_LEVELS = [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 35, 39, 44, 49]


def load(base: Path, name: str) -> dict:
    with (base / "current" / name).open(encoding="utf-8") as handle:
        return json.load(handle)


def records(base: Path, name: str) -> list[dict]:
    return load(base, name)["records"]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("pack_dir", type=Path, help="Directory containing current/, legacy/ and MANIFEST.json")
    args = parser.parse_args()
    root = args.pack_dir.resolve()
    current = root / "current"

    issues: list[str] = []
    notes: list[str] = []

    def check(condition: bool, message: str) -> None:
        if not condition:
            issues.append(message)

    def unique(rows: list[dict], key: str, label: str) -> None:
        values = [str(row.get(key, "")) for row in rows]
        check(all(values), f"{label}: blank {key}")
        duplicates = [value for value, count in collections.Counter(values).items() if count > 1]
        check(not duplicates, f"{label}: duplicate {key}: {duplicates[:10]}")

    check(current.is_dir(), f"Missing current/ directory: {current}")
    check((root / "MANIFEST.json").is_file(), "Missing MANIFEST.json")
    if issues:
        for issue in issues:
            print("FAIL", issue)
        return 1

    hero = records(root, "competences_180.json")
    hero_ult = records(root, "ultimes_12.json")
    check(len(hero) == 180, f"hero skills {len(hero)} != 180")
    unique(hero, "ID", "hero skills")
    check(len(hero_ult) == 12, f"hero ultimes {len(hero_ult)} != 12")

    hero_trees: dict[tuple[str, str], list[dict]] = collections.defaultdict(list)
    for row in hero:
        hero_trees[(row["Veilleur"], row["Arbre"])].append(row)
    check(len(hero_trees) == 12, f"hero trees {len(hero_trees)} != 12")
    for key, rows in hero_trees.items():
        check(len(rows) == 15, f"hero tree {key} has {len(rows)} rows, expected 15")
        levels = sorted(int(row["Niveau"]) for row in rows)
        check(levels == EXPECTED_LEVELS, f"hero tree {key} levels {levels} != {EXPECTED_LEVELS}")

    progression = records(root, "progression_1_50.json")
    check(len(progression) == 50, "progression does not contain 50 rows")
    check([int(row["Niveau"]) for row in progression] == list(range(1, 51)), "progression levels are not exactly 1..50")
    charges = {int(row["Niveau"]): int(row["Charges ultime"]) for row in progression}
    check(charges.get(16) == 1 and charges.get(32) == 2 and charges.get(48) == 3, "ultimate charge milestones mismatch")

    bestiary_1 = records(root, "bestiaire_confirme.json")
    skills_1 = records(root, "comp_bestiaire_585.json")
    ult_1 = records(root, "ult_bestiaire_39.json")
    check(len(bestiary_1) == 39, f"bestiaire_confirmé rows {len(bestiary_1)} != 39")
    check(len(skills_1) == 585, f"comp_bestiaire rows {len(skills_1)} != 585")
    check(len(ult_1) == 39, f"ult_bestiaire rows {len(ult_1)} != 39")

    # Known source property: 15 raw IDs are reused by two Act-I entities.
    # The composite key (Entité, ID) is unique and must be the importer key basis.
    raw_counts = collections.Counter(str(row["ID"]) for row in skills_1)
    raw_duplicate_ids = sorted(value for value, count in raw_counts.items() if count > 1)
    check(len(raw_duplicate_ids) == 15, f"expected 15 known duplicated raw Act-I IDs, got {len(raw_duplicate_ids)}")
    composite_1 = [(str(row["Entité"]), str(row["ID"])) for row in skills_1]
    check(len(composite_1) == len(set(composite_1)), "Act-I composite (Entité, ID) key is not unique")
    notes.append(f"Act-I raw source IDs duplicated globally: {len(raw_duplicate_ids)}; composite keys unique")

    entities_1: dict[str, list[dict]] = collections.defaultdict(list)
    for row in bestiary_1:
        entities_1[row["Entité"]].append(row)
    check(len(entities_1) == 13, f"Act-I/boss entities {len(entities_1)} != 13")
    for entity, rows in entities_1.items():
        check(len(rows) == 3, f"{entity}: {len(rows)} tree descriptors != 3")

    skills_1_trees: dict[tuple[str, str], list[dict]] = collections.defaultdict(list)
    for row in skills_1:
        skills_1_trees[(row["Entité"], row["Arbre"])].append(row)
    check(len(skills_1_trees) == 39, f"Act-I/boss skill trees {len(skills_1_trees)} != 39")
    for key, rows in skills_1_trees.items():
        check(len(rows) == 15, f"Act-I/boss tree {key} has {len(rows)} skills != 15")

    bestiary_2 = records(root, "actes_ii_v_bestiaire.json")
    skills_2 = records(root, "comp_ii_v_720.json")
    ult_2 = records(root, "ult_ii_v_48.json")
    check(len(bestiary_2) == 48, f"Acts II-V bestiary rows {len(bestiary_2)} != 48")
    check(len(skills_2) == 720, f"Acts II-V skills {len(skills_2)} != 720")
    unique(skills_2, "ID", "Acts II-V skills")
    check(len(ult_2) == 48, f"Acts II-V ultimes {len(ult_2)} != 48")

    entities_2: dict[str, list[dict]] = collections.defaultdict(list)
    for row in bestiary_2:
        entities_2[row["Ennemi"]].append(row)
    check(len(entities_2) == 16, f"Acts II-V entities {len(entities_2)} != 16")
    for entity, rows in entities_2.items():
        check(len(rows) == 3, f"{entity}: {len(rows)} tree descriptors != 3")

    skills_2_trees: dict[tuple[str, str], list[dict]] = collections.defaultdict(list)
    for row in skills_2:
        skills_2_trees[(row["Ennemi"], row["Arbre"])].append(row)
    check(len(skills_2_trees) == 48, f"Acts II-V skill trees {len(skills_2_trees)} != 48")
    for key, rows in skills_2_trees.items():
        check(len(rows) == 15, f"Acts II-V tree {key} has {len(rows)} skills != 15")

    ordinary_1 = [entity for entity, rows in entities_1.items() if rows[0]["Catégorie"] == "Ennemi"]
    bosses = [entity for entity, rows in entities_1.items() if rows[0]["Catégorie"] != "Ennemi"]
    check(len(ordinary_1) == 8, f"Act-I ordinary enemies {len(ordinary_1)} != 8")
    check(len(bosses) == 5, f"bosses {len(bosses)} != 5")
    check(len(ordinary_1) + len(entities_2) == 24, "ordinary enemy total != 24")
    check(len(ordinary_1) + len(entities_2) + len(bosses) == 29, "entity total != 29")
    check(len(skills_1) + len(skills_2) == 1305, "enemy/boss normal skill total != 1305")
    check(len(ult_1) + len(ult_2) == 87, "enemy/boss ultimate total != 87")
    check(len(hero) + len(skills_1) + len(skills_2) == 1485, "total normal skills != 1485")
    check(len(hero_ult) + len(ult_1) + len(ult_2) == 99, "total ultimates != 99")
    check(len(hero_trees) + len(skills_1_trees) + len(skills_2_trees) == 99, "total skill trees != 99")

    expected_rows = {
        "compositions_64.json": 64,
        "boss_5_phases.json": 16,
        "dangers_combat.json": 12,
        "tests_48.json": 48,
        "remanence_blessures.json": 30,
        "traces_psychologiques.json": 60,
        "bestiaire_narratif_29.json": 29,
        "rencontres_narratives_64.json": 64,
        "barks_veilleurs.json": 68,
        "dialogues_boss.json": 30,
        "evenements_narratifs.json": 15,
        "localisation_fr.json": 667,
    }
    for file_name, expected in expected_rows.items():
        actual = len(records(root, file_name))
        check(actual == expected, f"{file_name}: rows {actual} != {expected}")

    phases = records(root, "boss_5_phases.json")
    phase_counts = collections.Counter(row["Boss"] for row in phases)
    check(sorted(phase_counts.values()) == [3, 3, 3, 3, 4], f"boss phase distribution unexpected: {dict(phase_counts)}")

    encounters = records(root, "compositions_64.json")
    encounter_distribution = collections.Counter(str(row["Acte"]).split("—")[0].strip() for row in encounters)
    notes.append(f"Encounter distribution: {dict(encounter_distribution)}")

    rewards = load(root, "recompenses_capture.json")
    check("Essence cible" in rewards["columns"], "Recompenses_capture is missing the canonical Essence cible column")

    for file_name in os.listdir(current):
        if not file_name.endswith(".json"):
            continue
        data = load(root, file_name)
        if "source_workbook" in data:
            check(data["source_workbook"] == SOURCE_WORKBOOK, f"{file_name}: source workbook mismatch")

    print(f"ISSUES {len(issues)}")
    for issue in issues:
        print("FAIL", issue)
    for note in notes:
        print("NOTE", note)

    if issues:
        return 1

    print("PASS static canonical pack validation")
    return 0


if __name__ == "__main__":
    sys.exit(main())
