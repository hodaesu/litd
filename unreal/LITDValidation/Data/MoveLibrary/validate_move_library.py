from __future__ import annotations

import csv
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent
FILES = [
    ROOT / "unarmed_moves.csv",
    ROOT / "weapon_moves.csv",
    ROOT / "magic_moves.csv",
    ROOT / "politics_moves.csv",
]
ALLOWED_INPUTS = {"Light", "Heavy", "Parry", "Dodge", "SkillAttack"}
EXPECTED_COUNTS = {"unarmed": 40, "weapon": 72, "magic": 48, "politics": 60}
POLITICS_SCHOOLS = {
    "Autorite", "Condamnation", "Commandements", "Lois", "Sentences", "Tyrannie"
}
REQUIRED = {
    "id", "domain", "family_or_school", "name", "input", "role_or_form", "range",
    "tempo", "commitment", "damage_nature", "locomotion_or_gesture", "targeting",
    "finisher_candidate", "inspiration_tags", "animation_note"
}


def main() -> None:
    seen: set[str] = set()
    counts = {key: 0 for key in EXPECTED_COUNTS}
    politics_inputs: set[str] = set()
    politics_schools: Counter[str] = Counter()
    politics_finishers = 0

    for path in FILES:
        with path.open(encoding="utf-8", newline="") as handle:
            reader = csv.DictReader(handle)
            missing = REQUIRED - set(reader.fieldnames or [])
            if missing:
                raise SystemExit(f"{path.name}: colonnes manquantes: {sorted(missing)}")
            for row in reader:
                move_id = row["id"]
                if move_id in seen:
                    raise SystemExit(f"ID dupliqué: {move_id}")
                seen.add(move_id)

                if row["input"] not in ALLOWED_INPUTS:
                    raise SystemExit(f"{move_id}: input interdit {row['input']}")

                domain = row["domain"]
                if domain not in counts:
                    raise SystemExit(f"{move_id}: domaine inconnu {domain}")
                counts[domain] += 1

                if not row["inspiration_tags"].strip() or not row["animation_note"].strip():
                    raise SystemExit(f"{move_id}: inspiration/animation_note obligatoire")

                if domain == "politics":
                    politics_inputs.add(row["input"])
                    politics_schools[row["family_or_school"]] += 1
                    if row["finisher_candidate"].strip().lower() == "true":
                        politics_finishers += 1

    if counts != EXPECTED_COUNTS:
        raise SystemExit(f"Comptages invalides: {counts} != {EXPECTED_COUNTS}")

    if politics_inputs != ALLOWED_INPUTS:
        raise SystemExit(
            f"Politique doit exploiter les cinq inputs: {politics_inputs} != {ALLOWED_INPUTS}"
        )

    if set(politics_schools) != POLITICS_SCHOOLS:
        raise SystemExit(
            f"Familles Politique invalides: {set(politics_schools)} != {POLITICS_SCHOOLS}"
        )

    bad_school_counts = {school: count for school, count in politics_schools.items() if count != 10}
    if bad_school_counts:
        raise SystemExit(f"Chaque famille Politique doit avoir 10 animations: {bad_school_counts}")

    if politics_finishers < 3:
        raise SystemExit("Politique doit posséder au moins 3 candidats finisher/burst.")

    print(f"Move Library OK: {sum(counts.values())} mouvements ({counts})")


if __name__ == "__main__":
    main()
