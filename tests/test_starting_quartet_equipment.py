import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_starting_quartet_has_two_weapons_and_one_armor_each():
    heroes = json.loads((ROOT / "data/heroes.json").read_text(encoding="utf-8"))
    base_equipment = json.loads((ROOT / "data/equipment.json").read_text(encoding="utf-8"))
    quartet_equipment = json.loads((ROOT / "data/equipment_starting_quartet.json").read_text(encoding="utf-8"))
    equipment = base_equipment + quartet_equipment

    for hero in heroes:
        class_id = hero["class_id"]
        test_items = [
            item
            for item in equipment
            if item.get("class_id") == class_id and item.get("test_level") is True
        ]
        weapons = [item for item in test_items if item.get("slot") == "weapon"]
        armors = [item for item in test_items if item.get("slot") == "armor"]
        assert len(weapons) >= 2, f"{hero['name']} must have at least two test weapons"
        assert len(armors) >= 1, f"{hero['name']} must have at least one test armor"
