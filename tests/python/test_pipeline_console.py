import json
import tempfile
import unittest
from pathlib import Path

from tools.blender.pipeline_console import (
    blender_command, build_session, execute_session, interactive_request,
    load_manifest, normalize_request, request_from_json, select_jobs,
)


class PipelineInputTests(unittest.TestCase):
    def test_direct_options_are_normalized(self):
        request = normalize_request({"stages": "props", "job_ids": "prop_campfire", "execute": True})
        self.assertEqual(request["stages"], ["props"])
        self.assertEqual(request["job_ids"], ["prop_campfire"])
        self.assertTrue(request["execute"])

    def test_json_request_is_supported(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "request.json"
            path.write_text(json.dumps({"stages": ["characters"], "job_ids": ["character_aurelien"]}), encoding="utf-8")
            request = request_from_json(path)
            self.assertEqual(request["stages"], ["characters"])
            self.assertTrue(request["resume"])

    def test_interactive_request_is_supported(self):
        answers = iter(["props", "prop_campfire", "non"])
        request = interactive_request(lambda _prompt: next(answers))
        self.assertEqual(request["stages"], ["props"])
        self.assertEqual(request["job_ids"], ["prop_campfire"])
        self.assertFalse(request["execute"])

    def test_unknown_stage_is_rejected(self):
        with self.assertRaises(ValueError):
            normalize_request({"stages": ["cinematics"]})


class PipelineSelectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = load_manifest()

    def test_all_stages_select_100_jobs(self):
        jobs = select_jobs(self.manifest, normalize_request({}))
        self.assertEqual(len(jobs), 100)

    def test_specific_character_automatically_adds_material_dependency(self):
        request = normalize_request({"stages": ["characters"], "job_ids": ["character_aurelien"]})
        jobs = select_jobs(self.manifest, request)
        self.assertEqual([job["job_id"] for job in jobs], ["material_library", "character_aurelien"])

    def test_unknown_job_is_rejected(self):
        with self.assertRaises(ValueError):
            select_jobs(self.manifest, normalize_request({"job_ids": ["absent"]}))

    def test_job_and_stage_mismatch_is_rejected(self):
        with self.assertRaises(ValueError):
            select_jobs(self.manifest, normalize_request({"stages": ["props"], "job_ids": ["character_aurelien"]}))


class PipelineResumeTests(unittest.TestCase):
    def test_completed_job_with_outputs_is_skipped(self):
        manifest = {"stages": [{"stage": "materials", "job_id": "material_library", "depends_on": [],
                                "command": ["builder.py"], "outputs": ["builds/library.blend"]}]}
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "builds").mkdir()
            (root / "builds/library.blend").write_text("done", encoding="utf-8")
            (root / "reports").mkdir()
            (root / "reports/state.json").write_text('{"completed":["material_library"]}', encoding="utf-8")
            session = build_session(manifest, {"stages": ["materials"], "state_path": "reports/state.json"}, root)
            self.assertEqual(session["summary"], {"selected": 1, "pending": 0, "skipped": 1})

    def test_missing_output_is_rebuilt_even_when_state_says_completed(self):
        manifest = {"stages": [{"stage": "materials", "job_id": "material_library", "depends_on": [],
                                "command": ["builder.py"], "outputs": ["builds/library.blend"]}]}
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "state.json").write_text('{"completed":["material_library"]}', encoding="utf-8")
            session = build_session(manifest, {"stages": ["materials"], "state_path": "state.json"}, root)
            self.assertEqual(session["summary"]["pending"], 1)

    def test_execution_persists_progress(self):
        job = {"stage": "materials", "job_id": "material_library", "depends_on": [],
               "command": ["builder.py", "--output", "x.blend"], "outputs": ["x.blend"]}
        calls = []
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            session = {"request": normalize_request({"state_path": "state.json", "execute": True}),
                       "pending": [job], "skipped": [], "summary": {"selected": 1, "pending": 1, "skipped": 0}}
            result = execute_session(session, root, lambda *args, **kwargs: calls.append((args, kwargs)))
            self.assertEqual(result["completed"], ["material_library"])
            self.assertEqual(json.loads((root / "state.json").read_text())["completed"], ["material_library"])
            self.assertEqual(len(calls), 1)

    def test_blender_command_uses_background_python_mode(self):
        job = {"command": ["builder.py", "asset"]}
        command = blender_command(job, "/Applications/Blender", Path("/project"))
        self.assertEqual(command[:4], ["/Applications/Blender", "--background", "--python", "/project/builder.py"])
