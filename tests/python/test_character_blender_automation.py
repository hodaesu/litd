import json
import unittest

from tools.blender.build_character_scene import build_character_plan, load_job
from tools.blender.generate_character_jobs import build_jobs


class CharacterBlenderAutomationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.jobs = build_jobs()

    def test_catalog_covers_every_character_source(self):
        self.assertEqual(len(self.jobs), 52)
        self.assertEqual(len({job["job_id"] for job in self.jobs}), 52)
        counts = {category: sum(job["category"] == category for job in self.jobs)
                  for category in ("hero", "enemy", "miniboss", "boss")}
        self.assertEqual(counts, {"hero": 4, "enemy": 37, "miniboss": 9, "boss": 2})

    def test_every_job_has_complete_production_contract(self):
        required = {"BODY", "ARMATURE", "EQUIPMENT", "COLLISION", "SOCKETS", "LIGHTING", "CAMERA"}
        for job in self.jobs:
            self.assertEqual(set(job["collections"]), required)
            self.assertEqual(job["lod_levels"], [0, 1, 2])
            self.assertEqual(job["collision"], "capsule")
            self.assertEqual(len(job["equipment_sockets"]), 5)
            self.assertGreater(job["height_m"], 1.4)

    def test_every_job_builds_a_compliant_scene_plan(self):
        for job in self.jobs:
            plan = build_character_plan(job)
            names = [obj["name"] for obj in plan["objects"]]
            self.assertTrue(any(name.startswith("SK_") for name in names))
            self.assertTrue(any(name.startswith("RIG_") for name in names))
            self.assertTrue(any(name.startswith("COL_") for name in names))
            self.assertEqual(sum(name.startswith("SOCKET_") for name in names), 5)
            self.assertIn("root", plan["bones"])
            self.assertIn("death", plan["animations"])

    def test_hostile_special_characters_are_not_recruitable(self):
        for job in self.jobs:
            if job["category"] in ("miniboss", "boss"):
                self.assertTrue(job["boss"])
                self.assertFalse(job["recruitable"])

    def test_generated_file_matches_sources(self):
        with open("data/blender/character_jobs.json", encoding="utf-8") as stream:
            payload = json.load(stream)
        self.assertEqual(payload["jobs"], self.jobs)

    def test_unknown_character_job_is_rejected(self):
        with self.assertRaises(KeyError):
            load_job("character_absent")
