from __future__ import annotations

import json
from itertools import combinations
from pathlib import Path

from tools.qa.legendary_seven_relationships_audit import audit_legendary_seven_relationships

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / "universe/lore/legendary_seven_relationships.json"
DIALOGUES = [ROOT / f"data/narrative/legendary_seven_relationship_dialogues_{i}.json" for i in range(1, 4)]


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_legendary_seven_relationships_audit_is_green() -> None:
    report = audit_legendary_seven_relationships(ROOT)
    assert report["ok"], report["errors"]


def test_all_twenty_one_unordered_pairs_exist_once() -> None:
    data = _load(CORE)
    heroes = set(data["heroes"])
    expected = {frozenset(pair) for pair in combinations(heroes, 2)}
    actual = [frozenset(pair["heroes"]) for pair in data["pairs"]]
    assert len(actual) == 21
    assert len(set(actual)) == 21
    assert set(actual) == expected


def test_relationships_do_not_infer_romance_from_trust() -> None:
    data = _load(CORE)
    assert data["rules"]["romance_is_never_inferred_from_trust"] is True
    assert all(pair["romance_status"] == "not_canonized" for pair in data["pairs"])
    by_id = {pair["id"]: pair for pair in data["pairs"]}
    assert by_id["aurelien_mathilde"]["romance_status"] == "not_canonized"
    assert by_id["marec_anouk"]["bond_type"] == "fraternal"
    assert by_id["mathilde_marec"]["bond_type"] == "maternal_protective"


def test_every_pair_has_six_theatrical_states_and_two_survivor_lines() -> None:
    all_pairs: dict[str, dict] = {}
    for path in DIALOGUES:
        for pair in _load(path)["pairs"]:
            assert pair["id"] not in all_pairs
            all_pairs[pair["id"]] = pair
    assert len(all_pairs) == 21
    expected_stages = {"opening", "friction", "rupture", "repair", "durable", "bereavement"}
    for pair in all_pairs.values():
        assert set(pair["stages"]) == expected_stages
        heroes = set(pair["heroes"])
        for stage_name, stage in pair["stages"].items():
            assert stage["stage_direction"].strip()
            if stage_name == "bereavement":
                assert set(stage["survivor_lines"]) == heroes
                assert all(text.strip() for text in stage["survivor_lines"].values())
            else:
                assert stage["line"]["speaker_id"] in heroes
                assert stage["line"]["text"].strip()
