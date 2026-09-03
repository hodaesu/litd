from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LOADER = ROOT / "scripts" / "core" / "data_loader.gd"


def test_data_loader_loads_acts_i_ii_catalog():
    text = LOADER.read_text(encoding="utf-8")
    assert "var les_veilleurs_acts_1_2: Dictionary = {}" in text
    assert 'load_json("res://data/canon/les_veilleurs_acts_1_2.json")' in text


def test_data_loader_exposes_narrative_queries():
    text = LOADER.read_text(encoding="utf-8")
    for signature in [
        "func les_veilleurs_act(act_id: String) -> Dictionary:",
        "func les_veilleurs_zone(zone_id: String) -> Dictionary:",
        "func les_veilleurs_recruit_event_chain(chain_id: String) -> Dictionary:",
        "func les_veilleurs_hub_stage(stage_id: String) -> Dictionary:",
        "func les_veilleurs_remanence_bundle(bundle_id: String) -> Dictionary:",
        "func les_veilleurs_runtime_pending() -> Array[String]:",
    ]:
        assert signature in text
