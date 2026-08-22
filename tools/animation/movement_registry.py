#!/usr/bin/env python3
import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "data" / "movement_registry.json"

REQUIRED = {"id","category","owner","trigger","motion_family","markers","variants","rig","status","gameplay_authority","root_motion","notes"}
STATUSES = {"prepared","proxy","planned_blender","imported","validated"}

def load():
    return json.loads(REGISTRY.read_text(encoding="utf-8"))

def sources():
    def read(name):
        return json.loads((ROOT / "data" / name).read_text(encoding="utf-8"))
    return read("heroes.json"), read("enemies.json"), read("equipment.json"), read("boss_design_contracts.json")

def audit(data):
    errors = []
    entries = data.get("entries", [])
    ids = [item.get("id") for item in entries]
    if len(ids) != len(set(ids)):
        errors.append("duplicate movement ids")
    for index, item in enumerate(entries):
        missing = REQUIRED - set(item)
        if missing:
            errors.append(f"entry {index} missing {sorted(missing)}")
        if item.get("status") not in STATUSES:
            errors.append(f"{item.get('id')} invalid status")
        if item.get("gameplay_authority") != "Godot":
            errors.append(f"{item.get('id')} changes gameplay authority")
        if item.get("category") in {"combat","hero_skill","enemy","boss"} and not item.get("markers"):
            errors.append(f"{item.get('id')} missing markers")

    heroes, enemies, equipment, bosses = sources()
    by_owner = defaultdict(list)
    for item in entries:
        by_owner[str(item.get("owner"))].append(item)
    for hero in heroes:
        movements = [x for x in entries if x.get("category") == "hero_skill" and x.get("owner") == hero["id"]]
        if len(movements) != 45:
            errors.append(f"{hero['id']} has {len(movements)} skill movements, expected 45")
        for branch in ("offense","defense","special"):
            branch_entries = [x for x in movements if f"_{branch}_" in x["id"]]
            if len(branch_entries) != 15:
                errors.append(f"{hero['id']} {branch} has {len(branch_entries)} movements")
            ultimates = [x for x in branch_entries if "ultimate_signature" in x.get("variants", [])]
            if len(ultimates) != 1:
                errors.append(f"{hero['id']} {branch} has {len(ultimates)} ultimate signatures, expected 1")
            elif ultimates[0].get("ultimate_uses_by_level") != {"16": 1, "32": 2, "48": 3}:
                errors.append(f"{hero['id']} {branch} invalid ultimate uses")
    for enemy in enemies:
        owner = f"enemy_{int(enemy['id']):02d}"
        if len(by_owner[owner]) < 5:
            errors.append(f"{owner} incomplete enemy movement set")
    for boss in bosses.get("bosses", []):
        if len(by_owner[boss["id"]]) < 5:
            errors.append(f"{boss['id']} incomplete boss movement set")
    weapons = [x for x in equipment if x.get("slot") == "weapon"]
    for weapon in weapons:
        if not any(x["id"].startswith(f"equipment.{weapon['id']}.") for x in entries):
            errors.append(f"{weapon['id']} missing equipment variants")
    return errors

def report(data):
    entries = data["entries"]
    status = Counter(x["status"] for x in entries)
    category = Counter(x["category"] for x in entries)
    rig = Counter(x["rig"] for x in entries)
    return {
        "total": len(entries),
        "status": dict(sorted(status.items())),
        "category": dict(sorted(category.items())),
        "rig": dict(sorted(rig.items())),
        "blender_remaining": sum(v for k,v in status.items() if k in {"prepared","proxy","planned_blender"}),
    }

def blender_queue(data):
    return [x for x in data["entries"] if x["status"] in {"prepared","proxy","planned_blender"}]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["audit","stats","blender-todo"])
    parser.add_argument("--output")
    args = parser.parse_args()
    data = load()
    if args.command == "audit":
        errors = audit(data)
        if errors:
            print("\n".join(errors))
            return 1
        print(f"MOVEMENT_REGISTRY_OK: {len(data['entries'])} movements")
        return 0
    payload = report(data) if args.command == "stats" else blender_queue(data)
    text = json.dumps(payload, ensure_ascii=False, indent=2)
    if args.output:
        Path(args.output).write_text(text + "\n", encoding="utf-8")
    else:
        print(text)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
