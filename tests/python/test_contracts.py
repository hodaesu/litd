
from pathlib import Path
import json, pytest, yaml
from tools.qa.contracts import DATA_FILES, duplicate_ids, load_json, missing_fields
ROOT=Path(__file__).resolve().parents[2]

@pytest.mark.data
@pytest.mark.parametrize('filename', sorted(DATA_FILES))
def test_data_file_exists(filename): assert (ROOT/'data'/filename).is_file()

@pytest.mark.data
@pytest.mark.parametrize('filename', sorted(DATA_FILES))
def test_data_file_is_list(filename): assert isinstance(load_json(ROOT/'data'/filename),list)

@pytest.mark.data
@pytest.mark.parametrize('filename', sorted(DATA_FILES))
def test_ids_are_unique(filename): assert not duplicate_ids(load_json(ROOT/'data'/filename))

@pytest.mark.data
@pytest.mark.parametrize('filename', sorted(DATA_FILES))
def test_required_fields(filename):
    for item in load_json(ROOT/'data'/filename):
        if isinstance(item,dict): assert not missing_fields(filename,item)

@pytest.mark.assets
@pytest.mark.parametrize('hero', load_json(ROOT/'data/heroes.json'))
def test_hero_stats(hero):
    assert 0 <= hero['hp'] <= hero['max_hp']
    assert all(0 <= hero[k] <= 100 for k in ('fear','madness','hope'))

@pytest.mark.assets
@pytest.mark.parametrize('enemy', load_json(ROOT/'data/enemies.json'))
def test_enemy_contract(enemy):
    assert enemy['hp'] > 0
    assert len(enemy['damage']) == 2 and 0 <= enemy['damage'][0] <= enemy['damage'][1]
    assert (ROOT/'assets/enemies'/enemy['art']).is_file()

@pytest.mark.assets
@pytest.mark.parametrize('clazz', load_json(ROOT/'data/classes.json'))
def test_class_contract(clazz):
    assert clazz['hp'] > 0
    assert len(clazz['damage']) == 2 and clazz['damage'][0] <= clazz['damage'][1]
    assert (ROOT/'assets/heroes'/clazz['art']).is_file()

@pytest.mark.workflow
@pytest.mark.parametrize('workflow', sorted((ROOT/'.github/workflows').glob('*.yml')))
def test_workflow_yaml(workflow): assert isinstance(yaml.safe_load(workflow.read_text()),dict)
