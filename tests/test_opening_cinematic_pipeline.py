from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _load_module(path: str, name: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_opening_pipeline_contract_covers_all_production_tools() -> None:
    data = json.loads((ROOT / "data/cinematics/opening_pipeline.json").read_text(encoding="utf-8"))
    assert data["source_contract"] == "data/cinematics/opening_bird_intro.json"
    assert {"blender", "godot", "musescore", "reaper"}.issubset(data["tools"])
    assert data["rules"]["never_publish_without_human_approval"] is True
    assert data["rules"]["same_scene_handoff_required"] is True
    assert len(data["quality_gates"]) == 5


def test_storyboard_and_audio_generators_validate_without_external_software() -> None:
    for script in [
        "tools/cinematics/build_opening_storyboard.py",
        "tools/cinematics/prepare_opening_audio.py",
    ]:
        run = subprocess.run([sys.executable, script, "--check"], cwd=ROOT, capture_output=True, text=True)
        assert run.returncode == 0, run.stderr


def test_pipeline_has_resume_and_explicit_human_gates() -> None:
    module = _load_module("tools/cinematics/run_opening_pipeline.py", "opening_pipeline")
    stages = module.build_plan({"python":sys.executable,"blender":None,"godot":None,"musescore":None,"reaper":None})
    ids = [stage["id"] for stage in stages]
    assert ids == list(dict.fromkeys(ids))
    assert ids.index("preproduction_review") < ids.index("blender_proxy")
    assert ids.index("visual_review") < ids.index("publish_glb")
    assert ids.index("audio_listening_review") < ids.index("final_handoff_review")
    publish = next(stage for stage in stages if stage["id"] == "publish_glb")
    assert publish["approval"] == "art"
    source = (ROOT / "tools/cinematics/run_opening_pipeline.py").read_text(encoding="utf-8")
    assert "--no-resume" in source
    assert "--overwrite-approved" in source


def test_blender_builder_is_background_safe_and_marks_proxy_review() -> None:
    source = (ROOT / "tools/blender/build_opening_cinematic.py").read_text(encoding="utf-8")
    compile(source, "build_opening_cinematic.py", "exec")
    assert 'scene["litd_gameplay_authority"] = "Godot"' in source
    assert '"human_visual_review_required": True' in source
    assert "export_animations=True" in source
    assert "export_cameras=False" in source


def test_windows_launcher_exposes_supervised_pipeline_steps() -> None:
    launcher = (ROOT / "tools/workstation/LITD_OPENING_CINEMATIC.cmd").read_text(encoding="utf-8")
    for command in ["doctor", "prepare", "approve-preproduction", "approve-art", "approve-audio", "finalize"]:
        assert command in launcher
