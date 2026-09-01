import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "data/art/characters/litd1_five_heroes_3d_production.json"


def load_contract():
    return json.loads(CONTRACT.read_text(encoding="utf-8"))


def test_exactly_five_heroes_have_master_sheets():
    data = load_contract()
    heroes = data["heroes"]
    assert len(heroes) == 5
    assert {h["id"] for h in heroes} == {"ilyan_orme", "sela_ven", "varek_sorn", "nara_deilen", "effrie"}
    assert all(h["master_sheet"] == "approved_model_sheet" for h in heroes)


def test_pipeline_is_complete_and_ordered():
    data = load_contract()
    assert data["shared_pipeline"] == [
        "01_anatomical_blockout",
        "02_clothing_armor_blockout",
        "03_weapons_accessories",
        "04_highpoly_detail",
        "05_game_retopology",
        "06_uv_unwrap",
        "07_pbr_bake_and_textures",
        "08_game_hair",
        "09_humanoid_rig_and_skinning",
        "10_facial_expressions",
        "11_combat_and_locomotion_animation",
        "12_lod_generation",
        "13_godot_import_validation",
    ]


def test_sheet_uv_and_rig_are_never_treated_as_real_assets():
    data = load_contract()
    assert data["mesh_rules"]["no_fake_uv_from_sheet"] is True
    assert data["rig"]["sheet_rig_is_reference_only"] is True


def test_effrie_identity_is_locked_for_3d():
    data = load_contract()
    effrie = next(h for h in data["heroes"] if h["id"] == "effrie")
    assert effrie["height_m"] == 1.80
    assert effrie["primary_weapon"] == "war spear"
    assert "fire-red hair with gold nuances" in effrie["signature"]
    assert "fire-red base with visible gold nuances" in data["hair"]["effrie_rule"]


def test_godot_handoff_and_lods_are_defined():
    data = load_contract()
    assert data["godot_handoff"]["format"] == "glTF/GLB"
    assert data["lod"]["levels"] == ["LOD0", "LOD1", "LOD2", "LOD3"]
    assert len(data["animation_minimum"]) >= 10
