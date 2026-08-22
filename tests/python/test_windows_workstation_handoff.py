from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def test_windows_handoff_has_setup_check_import_and_launch():
    base = ROOT / "tools" / "workstation"
    required = [
        "LITD_PC_SETUP.ps1",
        "pc_preflight.py",
        "LITD_PC_PREPARE.cmd",
        "LITD_PC_TEST.cmd",
        "LITD_PC_IMPORT.cmd",
        "LITD_PC_LAUNCH.cmd",
    ]
    for name in required:
        assert (base / name).exists(), name

def test_setup_covers_required_workstation_software_and_backup():
    setup = (ROOT / "tools" / "workstation" / "LITD_PC_SETUP.ps1").read_text(encoding="utf-8")
    for value in ["Git.Git", "Python.Python.3.12", "GodotEngine.GodotEngine", "BlenderFoundation.Blender", "MuseScore.MuseScore", "Cockos.REAPER"]:
        assert value in setup
    assert "git bundle create" in setup
    assert "local\\backups" in setup

def test_preflight_records_pc_only_human_validation():
    preflight = (ROOT / "tools" / "workstation" / "pc_preflight.py").read_text(encoding="utf-8")
    assert "pc_preflight.json" in preflight
    assert "real touchscreen double-tap" in preflight
    assert "audio render and listening review" in preflight
    assert "GLB deformation review" in preflight

def test_first_session_checklist_covers_game_audio_and_blender():
    checklist = (ROOT / "docs" / "production" / "PC_FIRST_SESSION.md").read_text(encoding="utf-8")
    assert "3,5 secondes" in checklist
    assert "210 WAV" in checklist
    assert "Croisé et Chasseur" in checklist
    assert "premier GLB" in checklist
