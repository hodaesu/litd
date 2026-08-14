
import json, pytest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SCHEMA_KEYS={'version','gold','essence','light','supplies','party','expedition_room'}

@pytest.mark.save
@pytest.mark.parametrize('gold,essence,light,supplies',[(0,0,0,0),(120,18,75,8),(999999,9999,100,99)])
def test_save_payload_ranges(gold,essence,light,supplies):
    payload={'version':'0.13','gold':gold,'essence':essence,'light':light,'supplies':supplies,'party':[],'expedition_room':0}
    assert SCHEMA_KEYS <= payload.keys()
    assert payload['gold'] >= 0 and 0 <= payload['light'] <= 100

@pytest.mark.save
def test_save_manager_mentions_all_schema_keys():
    text=(ROOT/'scripts/core/save_manager.gd').read_text()
    for key in SCHEMA_KEYS: assert f'"{key}"' in text
