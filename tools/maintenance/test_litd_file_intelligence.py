from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("litd_file_intelligence.py")
spec = importlib.util.spec_from_file_location("litd_file_intelligence", MODULE_PATH)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = mod
spec.loader.exec_module(mod)


class FileIntelligenceTests(unittest.TestCase):
    def test_case_collision_detection(self) -> None:
        collisions = mod.case_collisions(["scripts/Foo.gd", "scripts/foo.gd", "README.md"])
        self.assertEqual(collisions, [["scripts/Foo.gd", "scripts/foo.gd"]])

    def test_godot_companion_orphan_detection(self) -> None:
        rows = mod.godot_companion_map(["scripts/a.gd", "scripts/a.gd.uid", "art/x.png.import"])
        self.assertFalse(rows["scripts/a.gd.uid"]["orphan"])
        self.assertTrue(rows["art/x.png.import"]["orphan"])

    def test_version_family_detection(self) -> None:
        groups = mod.version_families([
            "scripts/main_v1.gd",
            "scripts/main_v2.gd",
            "scripts/other.gd",
        ])
        self.assertEqual(len(groups), 1)
        members = next(iter(groups.values()))
        self.assertEqual([v for _p, v in members], [1, 2])

    def test_explicit_canonical_wins_family_suggestion(self) -> None:
        paths = ["scripts/main_v1.gd", "scripts/main_v2.gd"]
        manifest = {"canonical_paths": ["scripts/main_v1.gd"]}
        original = mod.git_activity
        try:
            mod.git_activity = lambda path, now=None: mod.GitActivity(100, 1, 1)
            result = mod.canonical_suggestions(paths, manifest, {p: 0 for p in paths})
        finally:
            mod.git_activity = original
        family = next(iter(result.values()))
        self.assertEqual(family["suggested_canonical"], "scripts/main_v1.gd")
        self.assertEqual(family["confidence"], "very_strong")
        self.assertFalse(family["automatic_action_allowed"])

    def test_multiple_explicit_canonicals_become_conflict(self) -> None:
        paths = ["scripts/main_v1.gd", "scripts/main_v2.gd"]
        manifest = {"canonical_paths": paths}
        original = mod.git_activity
        try:
            mod.git_activity = lambda path, now=None: mod.GitActivity(100, 1, 1)
            result = mod.canonical_suggestions(paths, manifest, {p: 0 for p in paths})
        finally:
            mod.git_activity = original
        family = next(iter(result.values()))
        self.assertIsNone(family["suggested_canonical"])
        self.assertEqual(family["confidence"], "conflict")


if __name__ == "__main__":
    unittest.main()
