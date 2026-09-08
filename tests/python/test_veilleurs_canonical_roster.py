import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HEROES_PATH = ROOT / "data" / "heroes.json"
ROSTER_PATH = ROOT / "data" / "veilleurs" / "canonical_roster.json"
GAME_STATE_PATH = ROOT / "scripts" / "core" / "game_state.gd"

CANONICAL_NAMES = ["Sahen Varo", "Mira Sen", "Narem Osh", "Ysra Nahal"]
CANONICAL_IDS = ["sahen_varo", "mira_sen", "narem_osh", "ysra_nahal"]
LEGACY_RUNTIME_IDS = ["aurelien", "malvor", "lysandra", "darius"]


def _load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def test_player_facing_hero_roster_is_canonical():
    heroes = _load_json(HEROES_PATH)
    assert [hero["name"] for hero in heroes] == CANONICAL_NAMES
    assert [hero["canonical_id"] for hero in heroes] == CANONICAL_IDS
    assert [hero["id"] for hero in heroes] == LEGACY_RUNTIME_IDS


def test_canonical_roster_contract_matches_runtime_bridge():
    heroes = _load_json(HEROES_PATH)
    roster = _load_json(ROSTER_PATH)
    contract = roster["heroes"]

    assert roster["status"] == "canonical_player_facing_roster"
    assert roster["rules"]["canonical_names_are_player_facing"] is True
    assert roster["rules"]["legacy_runtime_ids_are_compatibility_only"] is True
    assert roster["rules"]["legacy_names_must_never_be_rendered"] is True

    expected = [
        {
            "canonical_id": hero["canonical_id"],
            "name": hero["name"],
            "legacy_runtime_id": hero["id"],
        }
        for hero in heroes
    ]
    assert contract == expected


def test_deprecated_names_are_not_current_hero_display_names():
    heroes = _load_json(HEROES_PATH)
    roster = _load_json(ROSTER_PATH)
    current_names = {hero["name"] for hero in heroes}
    deprecated_names = set(roster["deprecated_player_facing_names"])
    assert current_names.isdisjoint(deprecated_names)


def test_game_state_contains_complete_canonicalization_bridge():
    source = GAME_STATE_PATH.read_text(encoding="utf-8")
    for runtime_id, canonical_id, name in zip(
        LEGACY_RUNTIME_IDS, CANONICAL_IDS, CANONICAL_NAMES, strict=True
    ):
        assert f'"{runtime_id}"' in source
        assert f'"canonical_id": "{canonical_id}"' in source
        assert f'"name": "{name}"' in source
    assert "canonicalize_party_identity" in source


def test_identity_bridge_preserves_legacy_trait_seed_determinism():
    source = GAME_STATE_PATH.read_text(encoding="utf-8")
    assert 'str(prepared_hero.get("id", ""))' in source
    assert 'str(prepared_hero.get("id", "")) == "aurelien"' in source
