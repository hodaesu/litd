from __future__ import annotations

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent
FILES = [ROOT / "unarmed_moves.csv", ROOT / "weapon_moves.csv", ROOT / "magic_moves.csv"]
ALLOWED_INPUTS = {"Light", "Heavy", "Parry", "Dodge", "SkillAttack"}
EXPECTED_COUNTS = {"unarmed": 40, "weapon": 72, "magic": 48}
REQUIRED = {
    "id", "domain", "family_or_school", "name", "input", "role_or_form", "range",
    "tempo", "commitment", "damage_nature", "locomotion_or_gesture", "targeting",
    "finisher_candidate", "inspiration_tags", "animation_note"
}


def main() -> None:
    seen: set[str] = set()
    counts = {key: 0 for key in EXPECTED_COUNTS}
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
    if counts != EXPECTED_COUNTS:
        raise SystemExit(f"Comptages invalides: {counts} != {EXPECTED_COUNTS}")
    print(f"Move Library OK: {sum(counts.values())} mouvements ({counts})")


if __name__ == "__main__":
    main()
