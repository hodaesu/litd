import json
import unittest

from tools.blender.build_prop_scene import build_prop_plan, load_job
from tools.blender.generate_prop_jobs import build_jobs
from tools.blender.run_full_pipeline import build_pipeline_plan


class PropAutomationTests(unittest.TestCase):
    def test_equipment_and_gameplay_props_are_covered(self):
        jobs = build_jobs()
        self.assertEqual(len(jobs), 32)
        self.assertEqual(sum(job["category"] == "equipment" for job in jobs), 27)
        self.assertEqual(sum(job["category"] != "equipment" for job in jobs), 5)
        self.assertEqual(len({job["job_id"] for job in jobs}), 32)

    def test_every_prop_plan_has_mesh_collision_socket_and_material(self):
        for job in build_jobs():
            plan = build_prop_plan(job)
            names = [obj["name"] for obj in plan["objects"]]
            self.assertTrue(any(name.startswith("SM_prop_") for name in names))
            self.assertTrue(any(name.startswith("COL_prop_") for name in names))
            self.assertTrue(any(name.startswith("SOCKET_") for name in names))
            self.assertTrue(plan["material_profile"])
            self.assertEqual(plan["lod_levels"], [0, 1, 2])

    def test_generated_prop_catalog_matches_sources(self):
        with open("data/blender/prop_jobs.json", encoding="utf-8") as stream:
            self.assertEqual(json.load(stream)["jobs"], build_jobs())

    def test_unknown_prop_is_rejected(self):
        with self.assertRaises(KeyError):
            load_job("absent")


class FullPipelineTests(unittest.TestCase):
    def test_pipeline_covers_all_production_domains(self):
        plan = build_pipeline_plan()
        self.assertEqual(plan["summary"], {
            "total_jobs": 101, "materials": 1, "environments": 16, "characters": 52, "props": 32,
        })
        self.assertEqual(len(plan["stages"]), 101)
        self.assertEqual(len({job["job_id"] for job in plan["stages"]}), 101)

    def test_non_material_jobs_depend_on_library(self):
        plan = build_pipeline_plan()
        for job in plan["stages"]:
            if job["stage"] == "materials":
                self.assertEqual(job["depends_on"], [])
            else:
                self.assertEqual(job["depends_on"], ["material_library"])
                self.assertEqual(len(job["outputs"]), 2)

    def test_saved_manifest_matches_current_plan(self):
        with open("data/blender/full_pipeline_manifest.json", encoding="utf-8") as stream:
            self.assertEqual(json.load(stream), build_pipeline_plan())
