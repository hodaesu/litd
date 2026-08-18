from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_chapter_two_save_version_and_runtime_contracts():
    save = (ROOT / 'scripts/core/save_manager.gd').read_text()
    runtime = (ROOT / 'scripts/world/chapter_02_runtime.gd').read_text()
    router = (ROOT / 'scripts/world/ashlands_scene_router.gd').read_text()
    journal = (ROOT / 'scripts/ui/quest_journal_ui.gd').read_text()
    assert 'SAVE_VERSION := "0.30"' in save
    assert '"chapter_02": Chapter02Runtime.serialize()' in save
    assert 'func independent_source_count()' in runtime
    assert 'func choose_final_outcome(choice_id: String)' in runtime
    assert 'func start_chapter_02()' in router
    assert '_stage_header(parent,"CHAPITRE II",Chapter02Runtime)' in journal
