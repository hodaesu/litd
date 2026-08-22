from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_v33_preserves_loadout_and_ports_focused_skill_tree_ui():
    ui = (ROOT / "scripts/ui/main_v33.gd").read_text(encoding="utf-8")
    scene = (ROOT / "scenes/Main.tscn").read_text(encoding="utf-8")

    for marker in (
        "selected_skill_branch",
        "selected_skill_id",
        "4 COMPÉTENCES ÉQUIPÉES",
        "TECHNIQUES DE BASE",
        "POINTS DISPONIBLES",
        "PALIER %02d",
        "NIVEAU REQUIS",
        "PRÉREQUIS",
        "DÉBLOQUER",
        "DISPONIBLE",
        "VERROUILLÉ",
        "ACQUIS",
        "_equip_selected_combat_skill",
        "_decorate_loadout_tooltips",
        "multi_tree_enabled",
    ):
        assert marker in ui

    assert "tree.columns = 3" in ui
    assert "_skill_branch_color" in ui
    assert 'res://scripts/ui/main_v33.gd' in scene
