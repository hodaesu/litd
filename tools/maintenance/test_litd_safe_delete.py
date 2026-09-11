from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("litd_safe_delete.py")
spec = importlib.util.spec_from_file_location("litd_safe_delete", MODULE_PATH)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = mod
spec.loader.exec_module(mod)


class SafeDeleteUnitTests(unittest.TestCase):
    def test_companion_without_owner_is_rejected(self) -> None:
        tracked = {"asset.png", "asset.png.import"}
        self.assertIn(
            "companion_without_owner:asset.png.import:asset.png",
            mod.validate_companion_coherence({"asset.png.import"}, tracked),
        )

    def test_owner_without_companion_is_rejected(self) -> None:
        tracked = {"asset.png", "asset.png.import"}
        self.assertIn(
            "owner_without_companion:asset.png:asset.png.import",
            mod.validate_companion_coherence({"asset.png"}, tracked),
        )

    def test_owner_and_companion_may_move_together(self) -> None:
        tracked = {"asset.png", "asset.png.import"}
        self.assertEqual(
            mod.validate_companion_coherence({"asset.png", "asset.png.import"}, tracked),
            [],
        )

    def test_safe_repo_path_rejects_option_like_path(self) -> None:
        with self.assertRaises(RuntimeError):
            mod._safe_repo_path("--force")

    def test_load_plan_rejects_non_list_candidates(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "plan.json"
            path.write_text(json.dumps({"candidates": {}}), encoding="utf-8")
            with self.assertRaises(RuntimeError):
                mod.load_plan(path)

    def test_uid_regex_detects_godot_uid(self) -> None:
        text = '[ext_resource type="Script" uid="uid://c123abc" path="res://x.gd" id="1"]'
        self.assertEqual(set(mod.UID_RE.findall(text)), {"uid://c123abc"})


if __name__ == "__main__":
    unittest.main()
