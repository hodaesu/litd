import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]

def load(path):
    return json.loads((ROOT / path).read_text())

def test_chapter_one_narrative_is_complete():
    d=load('data/levels/chapter_01_narrative_content.json')
    assert len(d['npcs']) == 6
    assert len(d['archives']['required']) == 3
    assert len(d['archives']['optional']) >= 5
    assert any(a['truth']=='false_lead' for a in d['archives']['optional'])
    assert d['ash_witness']['former_identity']['name']=='Ilyan Marek'
    assert len(d['ash_witness']['signature_animation']['beats']) == 5
    assert set(d['ash_witness']['outcomes']) == {'finish','stabilize','memory'}
    assert len(d['return_events']) >= 5
    assert set(d['unique_rewards']) == {'relic','equipment','knowledge','service'}
    assert d['chapter_02_unlock']['result']=='chapter_02_before_fall'

def test_creature_recruitment_is_narrative_not_loot():
    d=load('data/levels/chapter_01_narrative_content.json')
    assert 'butin' in d['creature_narrative']['rule']
    assert len(d['creature_narrative']['first_recruitment_effects']) >= 4
    assert d['creature_narrative']['chapter_02_hook']

def test_chapter_two_mirrors_reference_production_loop():
    d=load('data/levels/chapter_02_vertical_slice.json')
    assert len(d['stages']) == 8
    types=[s['type'] for s in d['stages']]
    assert 'exploration' in types and 'campfire' in types and 'miniboss' in types and 'boss' in types and 'return' in types
    assert {q['id'] for q in d['main_quests']} == {'c02_old_instruments','c02_deleted_pages','c02_false_accident'}
    assert d['investigation']['required_clues'] == 5
    assert d['investigation']['independent_sources_min'] >= 2
    assert len(d['final_choice']) == 3
    assert d['completion']['unlock_chapter']=='chapter_03_threshold'
