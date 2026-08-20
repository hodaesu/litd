from __future__ import annotations

from tools.blender.vertical_slice_session import blender_commands, preflight


def test_vertical_slice_preflight_ci_skips_local_reference_images() -> None:
    assert preflight(require_references=False) == []


def test_vertical_slice_session_prints_three_blender_commands() -> None:
    commands = blender_commands()
    assert len(commands) == 3
    assert "character_darius" in commands[0]
    assert "character_enemy_01_goule_affamee" in commands[1]
    assert "build_ashlands_scene.py" in commands[2]
