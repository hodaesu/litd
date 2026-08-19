from __future__ import annotations

import json
from pathlib import Path

from tools.blender.generate_visual_vertical_slice_jobs import build_payload

ROOT = Path(__file__).resolve().parents[1]


def _load(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def test_visual_slice_locks_art_bible_priority_and_scope() -> None:
    data = _load("data/visual_vertical_slice.json")
    assert data["reference_rules"]["art_bible_is_authoritative"] is True
    assert data["slice"]["hero_id"] == "darius"
    assert data["slice"]["enemy_id"] == "enemy_01_goule_affamee"
    assert data["arena"]["size_m"] == [20.0, 30.0]
    assert "micro_details_sur_toute_la_surface" in data["art_direction"]["forbidden_drift"]
    assert data["art_direction"]["detail_distribution"]["micro_detail"] <= 0.2


def test_darius_and_ghoul_have_production_readability_contracts() -> None:
    data = _load("data/visual_vertical_slice.json")
    darius = data["characters"]["darius"]
    ghoul = data["characters"]["enemy_01_goule_affamee"]
    assert {"lamellar_armor", "large_shield", "sword", "lantern"} <= set(darius["mandatory_shapes"])
    assert {"elongated_forearms", "claws", "forward_head"} <= set(ghoul["mandatory_shapes"])
    assert len(darius["animation_minimum"]) >= 8
    assert len(ghoul["animation_minimum"]) >= 7
    assert darius["height_m"] > ghoul["effective_hunched_height_m"]


def test_vertical_slice_blender_jobs_are_deterministic_and_proxy_gated() -> None:
    generated = build_payload(ROOT)
    committed = _load("data/blender/visual_vertical_slice_jobs.json")
    assert generated == committed
    assert generated["status"] == "prepared_without_blender"
    assert len(generated["jobs"]) == 3
    assert all(job["proxy_only_until_reviewed"] is True for job in generated["jobs"])
    assert all(job["art_bible_authoritative"] is True for job in generated["jobs"])


def test_godot_proxy_and_shader_contract_exist() -> None:
    data = _load("data/visual_vertical_slice.json")
    assert (ROOT / "scenes/visual/visual_vertical_slice_proxy.tscn").exists()
    assert (ROOT / "scripts/world/visual_vertical_slice_proxy.gd").exists()
    shader = ROOT / data["shader"]["godot_path"].replace("res://", "")
    outline = ROOT / data["shader"]["outline_path"].replace("res://", "")
    assert shader.exists()
    assert outline.exists()
    shader_text = shader.read_text(encoding="utf-8")
    assert "diffuse_toon" in shader_text
    assert "specular_disabled" in shader_text
    assert "micro" not in shader_text.lower()


def test_pc_handoff_keeps_reference_ingest_manual() -> None:
    data = _load("data/visual_vertical_slice.json")
    refs = data["reference_rules"]
    assert refs["binary_reference_status"] == "pending_manual_pc_ingest"
    before_blender = data["pc_handoff"]["before_opening_blender"]
    assert "copy_approved_art_bible_to_repo_target" in before_blender
    assert "run_python_vertical_slice_job_generator" in before_blender
