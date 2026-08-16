import json
import struct
import tempfile
import unittest
from pathlib import Path

from tools.blender.build_material_library import build_material_plan, load_profiles
from tools.blender.validate_character_glb import DEFAULT_ANIMATIONS, validate_character_glb
from tools.blender.validate_glb import JSON_CHUNK


def write_glb(path: Path, document: dict) -> None:
    payload = json.dumps(document, separators=(",", ":")).encode("utf-8")
    payload += b" " * ((4 - len(payload) % 4) % 4)
    total = 12 + 8 + len(payload)
    path.write_bytes(struct.pack("<4sII", b"glTF", 2, total) + struct.pack("<II", len(payload), JSON_CHUNK) + payload)


def valid_character_document() -> dict:
    animations = [
        {"name": name, "channels": [{"sampler": 0, "target": {"node": 0, "path": "rotation"}}],
         "samplers": [{"input": 0, "output": 1}]}
        for name in DEFAULT_ANIMATIONS
    ]
    return {
        "asset": {"version": "2.0"},
        "nodes": [{"name": "RIG_aurelien", "skin": 0, "mesh": 0}],
        "meshes": [{"name": "SK_aurelien_body_LOD0", "primitives": []}],
        "skins": [{"joints": [0]}], "animations": animations,
    }


class MaterialPipelineTests(unittest.TestCase):
    def test_library_is_mobile_safe_and_complete(self):
        plan = build_material_plan(load_profiles())
        self.assertEqual(plan["art_direction"], "dark_fantasy_cel_shading")
        self.assertEqual(len(plan["materials"]), 8)
        self.assertEqual({item["family"] for item in plan["materials"]}, {"character", "environment", "effects"})
        for material in plan["materials"]:
            self.assertTrue(material["material"].startswith("M_"))
            self.assertEqual(material["texture_set"]["width"], 3)
            self.assertTrue(material["texture_set"]["packed"])
            self.assertTrue(material["godot"]["mobile_safe"])

    def test_cel_palette_keeps_three_distinct_steps(self):
        plan = build_material_plan(load_profiles())
        for material in plan["materials"]:
            colors = material["texture_set"]["colors"]
            self.assertEqual(len(colors), 3)
            self.assertEqual(len({tuple(color) for color in colors}), 3)


class CharacterAnimationValidationTests(unittest.TestCase):
    def test_complete_rig_and_animation_export_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "hero.glb"
            write_glb(path, valid_character_document())
            report = validate_character_glb(path)
            self.assertTrue(report.valid, report.errors)
            self.assertEqual(report.stats["animations"], 6)

    def test_missing_skin_rig_mesh_and_animations_fail(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "broken.glb"
            write_glb(path, {"asset": {"version": "2.0"}, "nodes": [], "meshes": [], "animations": []})
            report = validate_character_glb(path)
            self.assertFalse(report.valid)
            self.assertIn("character export contains no skin", report.errors)
            self.assertIn("missing RIG_ armature node", report.errors)
            self.assertIn("missing SK_ skinned mesh", report.errors)
            self.assertTrue(any("missing required animation" in error for error in report.errors))

    def test_empty_animation_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "empty.glb"
            document = valid_character_document()
            document["animations"][0]["channels"] = []
            write_glb(path, document)
            report = validate_character_glb(path)
            self.assertFalse(report.valid)
            self.assertTrue(any("has no channels or samplers" in error for error in report.errors))
