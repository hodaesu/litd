
from __future__ import annotations
from pathlib import Path
import json

DATA_FILES = {
    "classes.json", "races.json", "heroes.json", "enemies.json",
    "skills.json", "equipment.json", "equipment_rarities.json", "equipment_affixes.json",
    "quests.json", "events.json", "dialogues.json"
}

REQUIRED_FIELDS = {
    "classes.json": {"id", "name", "hp", "damage", "art"},
    "races.json": {"id", "name", "passive"},
    "heroes.json": {"id", "name", "class_id", "race_id", "hp", "max_hp"},
    "enemies.json": {"id", "name", "hp", "damage", "art"},
    "skills.json": {"id", "name", "power", "target"},
    "equipment.json": {"id", "name", "slot", "base_bonuses"},
    "equipment_rarities.json": {"id", "name", "rank", "base_multiplier", "affix_multiplier", "affix_count", "special_affix_count"},
    "equipment_affixes.json": {"id", "name", "stat", "base_range", "unit", "special"},
    "quests.json": {"id", "name", "description"},
    "events.json": {"id", "name", "text", "choices"},
}

def load_json(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)

def duplicate_ids(items):
    seen, duplicates = set(), set()
    for item in items:
        value = item.get("id")
        if value is None:
            continue
        if value in seen:
            duplicates.add(value)
        seen.add(value)
    return duplicates

def missing_fields(filename: str, item: dict):
    return REQUIRED_FIELDS.get(filename, set()) - set(item)
