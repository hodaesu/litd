import json
import struct
import tempfile
import unittest
from pathlib import Path

from tools.blender.validate_glb import JSON_CHUNK, validate_glb


def write_glb(path: Path, document: dict) -> None:
    payload = json.dumps(document, separators=(",", ":")).encode("utf-8")
    payload += b" " * ((4 - len(payload) % 4) % 4)
    total = 12 + 8 + len(payload)
    path.write_bytes(struct.pack("<4sII", b"glTF", 2, total) + struct.pack("<II", len(payload), JSON_CHUNK) + payload)


class BlenderPipelineTests(unittest.TestCase):
    def test_valid_modular_export_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "module.glb"
            write_glb(path, {
                "asset": {"version": "2.0"},
                "nodes": [{"name": "SM_ruins_wall_a_LOD0", "mesh": 0}, {"name": "COL_wall"}, {"name": "SOCKET_vfx"}],
                "meshes": [{"name": "SM_ruins_wall_a_LOD0", "primitives": [{"material": 0}]}],
                "materials": [{"name": "M_stone_ash"}],
            })
            report = validate_glb(path, require_lods=1, require_collision=True)
            self.assertTrue(report.valid, report.errors)

    def test_generic_blender_names_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "bad.glb"
            write_glb(path, {
                "asset": {"version": "2.0"},
                "nodes": [{"name": "Cube", "mesh": 0}],
                "meshes": [{"name": "Cube", "primitives": [{"material": 0}]}],
                "materials": [{"name": "Material.001"}],
            })
            report = validate_glb(path)
            self.assertFalse(report.valid)
            self.assertTrue(any("generic Blender name" in error for error in report.errors))

    def test_missing_lod_and_collision_are_rejected_when_required(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "incomplete.glb"
            write_glb(path, {
                "asset": {"version": "2.0"},
                "nodes": [{"name": "SM_ruins_wall_a", "mesh": 0}],
                "meshes": [{"name": "SM_ruins_wall_a", "primitives": []}],
                "materials": [],
            })
            report = validate_glb(path, require_lods=3, require_collision=True)
            self.assertFalse(report.valid)
            self.assertTrue(any("missing required LOD2" in error for error in report.errors))
            self.assertTrue(any("missing required COL_" in error for error in report.errors))
