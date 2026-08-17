from __future__ import annotations

import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def load(name: str):
    return json.loads((ROOT / "data" / name).read_text(encoding="utf-8"))


class RandomEquipmentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.equipment = load("equipment.json")
        cls.rarities = load("equipment_rarities.json")
        cls.affixes = load("equipment_affixes.json")

    def test_test_level_has_two_weapons_and_one_armor_per_playable_class(self):
        expected = {"occultist", "breaker", "vestal", "watcher"}
        for class_id in expected:
            items = [item for item in self.equipment if item.get("test_level") and item.get("class_id") == class_id]
            self.assertEqual(2, sum(item["slot"] == "weapon" for item in items), class_id)
            self.assertEqual(1, sum(item["slot"] == "armor" for item in items), class_id)

    def test_every_test_weapon_has_a_valid_class_specific_affix_pool(self):
        affix_ids = {affix["id"] for affix in self.affixes if not affix["special"]}
        for weapon in (item for item in self.equipment if item.get("test_level") and item["slot"] == "weapon"):
            self.assertGreaterEqual(len(weapon["allowed_affixes"]), 5)
            self.assertTrue(set(weapon["allowed_affixes"]) <= affix_ids)

    def test_rarity_power_is_strictly_proportional(self):
        expected = {
            "common": (1.0, 1, 0),
            "uncommon": (1.5, 1, 0),
            "rare": (2.0, 2, 0),
            "epic": (3.0, 3, 0),
            "legendary": (4.0, 2, 1),
        }
        by_id = {rarity["id"]: rarity for rarity in self.rarities}
        self.assertEqual(set(expected), set(by_id))
        previous = 0.0
        for rarity_id in expected:
            multiplier, regular, special = expected[rarity_id]
            rarity = by_id[rarity_id]
            self.assertEqual(multiplier, rarity["base_multiplier"])
            self.assertEqual(multiplier, rarity["affix_multiplier"])
            self.assertEqual(regular, rarity["affix_count"])
            self.assertEqual(special, rarity["special_affix_count"])
            self.assertGreater(rarity["base_multiplier"], previous)
            previous = rarity["base_multiplier"]

    def test_legendary_has_one_special_affix_for_each_playable_class(self):
        specials = [affix for affix in self.affixes if affix["special"]]
        covered = {class_id for affix in specials for class_id in affix.get("classes", [])}
        self.assertEqual({"occultist", "breaker", "vestal", "watcher"}, covered)

    def test_runtime_serializes_seed_counter_instances_and_equipped_slots(self):
        script = (ROOT / "scripts/core/equipment_manager.gd").read_text(encoding="utf-8")
        for key in ("instance_id", "seed", "drop_counter", "generation_seed", "equipped_by_hero"):
            self.assertIn(f'"{key}"', script)
        self.assertIn("func serialize()", script)
        self.assertIn("func deserialize(data: Dictionary)", script)

    def test_save_manager_persists_equipment_without_regeneration(self):
        script = (ROOT / "scripts/core/save_manager.gd").read_text(encoding="utf-8")
        self.assertIn('"equipment": EquipmentManager.serialize()', script)
        self.assertIn('EquipmentManager.deserialize(payload.get("equipment", {}))', script)

    def test_four_test_rooms_award_the_four_class_bundles_in_order(self):
        script = (ROOT / "scripts/ui/main.gd").read_text(encoding="utf-8")
        self.assertIn("GameState.expedition_room - 2", script)
        self.assertIn("EquipmentManager.grant_test_level_bundle", script)


if __name__ == "__main__":
    unittest.main(verbosity=2)
