import json
import struct
import tempfile
import unittest
from pathlib import Path

from tools.blender.generate_godot_import_registry import build_registry
from tools.blender.validate_glb import JSON_CHUNK
from tools.blender.validate_production_readiness import build_report, validate_asset, validate_contract


def write_glb(path: Path, document: dict) -> None:
    payload = json.dumps(document, separators=(",", ":")).encode("utf-8")
    payload += b" " * ((4 - len(payload) % 4) % 4)
    total = 12 + 8 + len(payload)
    path.write_bytes(struct.pack("<4sII", b"glTF", 2, total) + struct.pack("<II", len(payload), JSON_CHUNK) + payload)


class GodotImportRegistryTests(unittest.TestCase):
    def test_registry_covers_every_glb_output(self):
        registry = build_registry()
        self.assertEqual(registry["asset_count"], 75)
        self.assertEqual(len(registry["assets"]), 75)
        self.assertEqual(len({asset["job_id"] for asset in registry["assets"]}), 75)
        self.assertEqual(len({asset["godot_path"] for asset in registry["assets"]}), 75)
        self.assertTrue(all(asset["godot_path"].startswith("res://assets/3d/") for asset in registry["assets"]))

    def test_saved_registry_matches_pipeline(self):
        with open("data/blender/godot_import_registry.json", encoding="utf-8") as stream:
            self.assertEqual(json.load(stream), build_registry())
        self.assertEqual(validate_contract(), [])

    def test_preproduction_report_marks_outputs_as_missing_not_blocked(self):
        report = build_report()
        self.assertEqual(report["summary"], {"total": 75, "ready": 0, "missing": 75, "blocked": 0})


class MobileBudgetTests(unittest.TestCase):
    def test_valid_environment_export_passes_gate(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "zone.glb"
            write_glb(path, {
                "asset": {"version": "2.0"},
                "nodes": [{"name": "SM_ruins_LOD0", "mesh": 0}, {"name": "COL_ruins"}, {"name": "SOCKET_entry"}],
                "meshes": [{"name": "SM_ruins_LOD0", "primitives": [{"material": 0}]}],
                "materials": [{"name": "M_ashlands_stone"}],
            })
            result = validate_asset(path, "environments", {"max_glb_mb": 1, "max_nodes": 10, "max_meshes": 4, "max_materials": 3})
            self.assertTrue(result["valid"], result["errors"])
            self.assertEqual(result["status"], "ready")

    def test_mobile_budget_overrun_blocks_export(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "zone.glb"
            write_glb(path, {
                "asset": {"version": "2.0"},
                "nodes": [{"name": "SM_ruins_LOD0", "mesh": 0}, {"name": "COL_ruins"}],
                "meshes": [{"name": "SM_ruins_LOD0", "primitives": []}], "materials": [],
            })
            result = validate_asset(path, "environments", {"max_glb_mb": 1, "max_nodes": 1, "max_meshes": 4, "max_materials": 3})
            self.assertFalse(result["valid"])
            self.assertEqual(result["status"], "blocked")
            self.assertTrue(any("mobile budget exceeded: nodes" in error for error in result["errors"]))
