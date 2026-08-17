from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def test_rpg_skill_tree_ui_has_focus_states_and_details():
    ui=(ROOT/'scripts/ui/main.gd').read_text()
    for marker in ('selected_skill_branch','selected_skill_id','PALIER %02d','POINTS DISPONIBLES','NIVEAU REQUIS','PRÉREQUIS','DÉBLOQUER','DISPONIBLE','VERROUILLÉ','ACQUIS'):
        assert marker in ui
    assert 'tree.columns=3' in ui
    assert '_skill_branch_color' in ui
