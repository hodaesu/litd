import json
import unittest

from tools.blender.generate_visual_review_queue import build_queue
from tools.blender.record_asset_review import build_summary, record_review
from tools.blender.render_asset_preview import build_render_plan, load_review


class VisualReviewQueueTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.queue = build_queue()

    def test_queue_covers_all_godot_assets(self):
        self.assertEqual(self.queue["review_count"], 100)
        self.assertEqual(len(self.queue["reviews"]), 100)
        self.assertEqual(len({review["job_id"] for review in self.queue["reviews"]}), 100)

    def test_environment_reviews_use_four_isometric_views(self):
        reviews = [review for review in self.queue["reviews"] if review["category"] == "environments"]
        self.assertEqual(len(reviews), 16)
        for review in reviews:
            self.assertEqual(review["preview"]["type"], "isometric_quadrants")
            self.assertEqual(review["preview"]["angles_degrees"], [45, 135, 225, 315])
            self.assertIn("critical_path", review["gates"])

    def test_characters_and_props_use_eight_angle_turntables(self):
        reviews = [review for review in self.queue["reviews"] if review["category"] != "environments"]
        self.assertEqual(len(reviews), 84)
        for review in reviews:
            self.assertEqual(review["preview"]["type"], "turntable")
            self.assertEqual(len(review["preview"]["angles_degrees"]), 8)

    def test_saved_queue_matches_sources(self):
        with open("data/blender/visual_review_queue.json", encoding="utf-8") as stream:
            self.assertEqual(json.load(stream), self.queue)


class PreviewPlanTests(unittest.TestCase):
    def test_character_preview_plan_has_unique_png_outputs(self):
        plan = build_render_plan(load_review("character_aurelien"))
        self.assertEqual(len(plan["shots"]), 8)
        self.assertEqual(len({shot["output"] for shot in plan["shots"]}), 8)
        self.assertTrue(all(shot["output"].endswith(".png") for shot in plan["shots"]))

    def test_environment_preview_plan_uses_large_resolution(self):
        plan = build_render_plan(load_review("ashlands_01_faubourg_ruins"))
        self.assertEqual(plan["resolution"], [1024, 1024])
        self.assertEqual(len(plan["shots"]), 4)


class ApprovalTests(unittest.TestCase):
    def setUp(self):
        self.queue = build_queue()
        self.review = next(item for item in self.queue["reviews"] if item["job_id"] == "character_aurelien")
        self.passing = {gate: True for gate in self.review["gates"]}

    def test_approval_requires_every_gate(self):
        failing = dict(self.passing)
        failing["silhouette"] = False
        with self.assertRaises(ValueError):
            record_review("character_aurelien", failing, "approved", "", queue=self.queue)

    def test_approval_is_recorded_with_history(self):
        decisions = record_review("character_aurelien", self.passing, "approved", "validé",
                                  queue=self.queue, timestamp="2026-08-16T00:00:00Z")
        record = decisions["reviews"]["character_aurelien"]
        self.assertEqual(record["status"], "approved")
        self.assertEqual(record["history"][0]["note"], "validé")
        self.assertEqual(build_summary(decisions, self.queue), {
            "total": 100, "approved": 1, "changes_requested": 0, "pending": 99,
        })

    def test_incomplete_gate_map_is_rejected(self):
        with self.assertRaises(ValueError):
            record_review("character_aurelien", {"silhouette": True}, "approved", "", queue=self.queue)
