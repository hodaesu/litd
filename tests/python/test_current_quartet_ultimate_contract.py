import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "data" / "veilleurs" / "current_quartet_ultimate_sheets.json"


def _load_contract() -> dict:
    with CONTRACT.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def test_current_quartet_ultimate_contract_shape() -> None:
    data = _load_contract()

    assert data["schema_version"] == 1
    assert data["status"] == "CURRENT_QUARTET_AUTHORED_IDENTITY_LOCK"
    assert data["charge_progression"] == {"16": 1, "32": 2, "48": 3}

    heroes = data["heroes"]
    assert [hero["hero_id"] for hero in heroes] == [
        "mathilde",
        "marec",
        "anouk",
        "aurelien",
    ]
    assert [hero["display_name"] for hero in heroes] == [
        "Mathilde",
        "Marec",
        "Anouk",
        "Aurélien",
    ]

    for hero in heroes:
        ultimates = hero["ultimates"]
        assert len(ultimates) == 3
        assert [ultimate["branch_slot"] for ultimate in ultimates] == [1, 2, 3]
        assert all(ultimate["identity_locked"] is True for ultimate in ultimates)
        assert all(ultimate["name"].strip() for ultimate in ultimates)
        assert all(
            ultimate["runtime_effect_status"] == "PENDING_RESOLVER_BINDING"
            for ultimate in ultimates
        )


def test_current_quartet_ultimate_names_are_unique() -> None:
    data = _load_contract()
    names = [
        ultimate["name"]
        for hero in data["heroes"]
        for ultimate in hero["ultimates"]
    ]
    assert len(names) == 12
    assert len(set(names)) == 12
