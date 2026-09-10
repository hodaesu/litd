from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("litd_file_sorter.py")
spec = importlib.util.spec_from_file_location("litd_file_sorter", MODULE_PATH)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = mod
spec.loader.exec_module(mod)


def base_manifest() -> dict:
    return {
        "policy": {"minimum_delete_confidence": 0.95},
        "canonical_paths": [],
        "obsolete_records": [],
        "protected_patterns": [],
        "active_patterns": [],
        "generated_patterns": [],
        "legacy_candidate_regexes": [],
    }


class SorterSafetyTests(unittest.TestCase):
    def test_patterns_do_not_delete(self) -> None:
        manifest = base_manifest()
        manifest["legacy_candidate_regexes"] = [r"(^|/)legacy(/|_|\.|-)"]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "legacy_file.gd"
            path.write_text("extends Node\n", encoding="utf-8")
            old_root = mod.ROOT
            try:
                mod.ROOT = root
                records = mod.classify([path], manifest)
            finally:
                mod.ROOT = old_root
        self.assertEqual(records[0].status, mod.STATUS_REVIEW)
        self.assertFalse(records[0].deletable)

    def test_legacy_signal_overrides_active_pattern_for_review(self) -> None:
        manifest = base_manifest()
        manifest["active_patterns"] = ["scripts/**"]
        manifest["legacy_candidate_regexes"] = [r"(_|-)v[0-9]{1,3}([._-]|$)"]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "scripts" / "combat_v12.gd"
            path.parent.mkdir()
            path.write_text("extends Node\n", encoding="utf-8")
            old_root = mod.ROOT
            try:
                mod.ROOT = root
                records = mod.classify([path], manifest)
            finally:
                mod.ROOT = old_root
        self.assertEqual(records[0].status, mod.STATUS_REVIEW)
        self.assertFalse(records[0].deletable)

    def test_explicit_obsolete_with_reference_is_not_deletable(self) -> None:
        manifest = base_manifest()
        manifest["obsolete_records"] = [{
            "path": "old.gd",
            "replacement": "new.gd",
            "reason": "superseded",
            "evidence": ["ADR-TEST"],
            "confidence": 1.0,
        }]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            old = root / "old.gd"
            new = root / "new.gd"
            user = root / "user.gd"
            old.write_text("extends Node\n", encoding="utf-8")
            new.write_text("extends Node\n# replacement\n", encoding="utf-8")
            user.write_text('const OLD = preload("res://old.gd")\n', encoding="utf-8")
            old_root = mod.ROOT
            try:
                mod.ROOT = root
                records = mod.classify([old, new, user], manifest)
            finally:
                mod.ROOT = old_root
        record = next(r for r in records if r.path == "old.gd")
        self.assertEqual(record.status, mod.STATUS_OBSOLETE)
        self.assertFalse(record.deletable)
        self.assertIn("user.gd", record.referenced_by)

    def test_evidence_and_confidence_are_required(self) -> None:
        manifest = base_manifest()
        manifest["obsolete_records"] = [{
            "path": "old.gd",
            "retired_without_replacement": True,
            "reason": "unused prototype",
            "evidence": [],
            "confidence": 0.7,
        }]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "old.gd"
            path.write_text("extends Node\n", encoding="utf-8")
            old_root = mod.ROOT
            try:
                mod.ROOT = root
                records = mod.classify([path], manifest)
                errors = mod.validate_manifest(manifest, [path])
            finally:
                mod.ROOT = old_root
        self.assertFalse(records[0].deletable)
        self.assertTrue(any(e.startswith("obsolete_missing_evidence:") for e in errors))
        self.assertTrue(any(e.startswith("obsolete_low_confidence:") for e in errors))

    def test_canonical_wins_over_obsolete_and_manifest_reports_conflict(self) -> None:
        manifest = base_manifest()
        manifest["canonical_paths"] = ["core.gd"]
        manifest["obsolete_records"] = [{
            "path": "core.gd",
            "retired_without_replacement": True,
            "reason": "bad declaration",
            "evidence": ["test"],
            "confidence": 1.0,
        }]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "core.gd"
            path.write_text("extends Node\n", encoding="utf-8")
            old_root = mod.ROOT
            try:
                mod.ROOT = root
                records = mod.classify([path], manifest)
                errors = mod.validate_manifest(manifest, [path])
            finally:
                mod.ROOT = old_root
        self.assertEqual(records[0].status, mod.STATUS_CANONICAL)
        self.assertFalse(records[0].deletable)
        self.assertTrue(any(e.startswith("canonical_and_obsolete:") for e in errors))

    def test_delete_plan_rejects_changed_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = root / "obsolete.txt"
            target.write_text("v1", encoding="utf-8")
            expected = mod.file_sha256(target)
            plan = root / "plan.json"
            plan.write_text(
                '{"schema_version":2,"candidates":[{"path":"obsolete.txt","sha256":"%s"}]}' % expected,
                encoding="utf-8",
            )
            target.write_text("v2", encoding="utf-8")
            old_root = mod.ROOT
            try:
                mod.ROOT = root
                with self.assertRaises(RuntimeError):
                    mod.delete_from_plan(plan)
            finally:
                mod.ROOT = old_root

    def test_exact_duplicates_are_detected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            a = root / "a.txt"
            b = root / "b.txt"
            a.write_text("same", encoding="utf-8")
            b.write_text("same", encoding="utf-8")
            old_root = mod.ROOT
            try:
                mod.ROOT = root
                duplicates = mod.duplicate_index([a, b])
            finally:
                mod.ROOT = old_root
        self.assertEqual(len(duplicates), 1)
        self.assertEqual(next(iter(duplicates.values())), ["a.txt", "b.txt"])


if __name__ == "__main__":
    unittest.main()
