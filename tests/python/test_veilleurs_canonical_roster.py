import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HEROES_PATH = ROOT / "data" / "heroes.json"
ROSTER_PATH = ROOT / "data" / "veilleurs" / "canonical_roster.json"
GAME_STATE_PATH = ROOT / "scripts" / "core" / "game_state.gd"

INVALIDATED_QUARTETS = [
    ["Nayra Orun", "Tarek Senn", "Aïsha Maren", "Idris Vael"],
    ["Sahen Varo", "Mira Sen", "Narem Osh", "Ysra Nahal"],
    ["Aurélien", "Malvor", "Lysandra", "Darius"],
]
OLD_CANONICAL_IDS = {"sahen_varo", "mira_sen", "narem_osh", "ysra_nahal"}
OLD_RUNTIME_IDS = {"aurelien", "malvor", "lysandra", "darius"}
TECHNICAL_SLOTS = [f"starter_slot_{index:02d}" for index in range(1, 5)]


def _load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def test_starting_quartet_is_unassigned():
    roster = _load_json(ROSTER_PATH)
    assert roster["status"] == "reset_unassigned"
    assert roster["heroes"] == []
    assert roster["rules"]["starting_quartet_assigned"] is False
    assert roster["design_status"] == "to_design_from_blank_slate"


def test_every_previous_starting_quartet_is_invalidated():
    roster = _load_json(ROSTER_PATH)
    assert roster["invalidated_starting_quartets"] == INVALIDATED_QUARTETS


def test_runtime_uses_only_neutral_technical_slots():
    heroes = _load_json(HEROES_PATH)
    assert [hero["id"] for hero in heroes] == TECHNICAL_SLOTS
    assert all(hero["canonical_id"] == "" for hero in heroes)
    assert all(hero["canon_status"] == "unassigned_starting_slot" for hero in heroes)
    assert all(hero["class_id"] == "unassigned" for hero in heroes)
    assert all(hero["race_id"] == "unassigned" for hero in heroes)


def test_old_quartet_identity_is_not_assigned_to_runtime_slots():
    heroes = _load_json(HEROES_PATH)
    old_names = {name for quartet in INVALIDATED_QUARTETS for name in quartet}
    current_names = {hero["name"] for hero in heroes}
    current_ids = {hero["id"] for hero in heroes}
    canonical_ids = {hero["canonical_id"] for hero in heroes if hero["canonical_id"]}

    assert current_names.isdisjoint(old_names)
    assert current_ids.isdisjoint(OLD_RUNTIME_IDS)
    assert canonical_ids.isdisjoint(OLD_CANONICAL_IDS)


def test_no_legacy_quartet_canonicalization_bridge_remains():
    source = GAME_STATE_PATH.read_text(encoding="utf-8")
    assert "CANONICAL_PARTY_IDENTITIES" not in source
    assert "canonicalize_party_identity" not in source
    for old_id in OLD_RUNTIME_IDS:
        assert f'"{old_id}"' not in source
    for canonical_id in OLD_CANONICAL_IDS:
        assert canonical_id not in source


def test_cosmopolitan_blank_slate_constraints_are_locked():
    roster = _load_json(ROSTER_PATH)
    constraints = roster["design_constraints"]
    assert constraints["cosmopolitan_world"] is True
    assert constraints["strong_asian_cultural_foundation"] is True
    assert constraints["primarily_chinese_visual_influence"] is True
    assert constraints["human_ethnic_diversity_required"] is True
    assert constraints["four_distinct_identities_required"] is True
    assert roster["rules"]["inherit_legacy_identity"] is False
    assert roster["rules"]["inherit_legacy_role"] is False
    assert roster["rules"]["inherit_legacy_ethnicity"] is False
    assert roster["rules"]["inherit_legacy_class"] is False
    assert roster["rules"]["inherit_legacy_loadout"] is False
