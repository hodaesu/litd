import json
from pathlib import Path

import pytest


SEED_PATH = Path("unreal/LITD2/Data/Remanence/sarei_seed.json")


def _load_seed() -> dict:
    return json.loads(SEED_PATH.read_text(encoding="utf-8"))


def _index(items: list[dict], key: str) -> dict[str, dict]:
    result = {item[key]: item for item in items}
    assert len(result) == len(items), f"duplicate {key} values"
    return result


@pytest.mark.data
def test_sarei_seed_is_litd2_and_has_unique_ids() -> None:
    data = _load_seed()
    assert data["game"] == "LITD2"
    assert data["branch_id"] == "SAREI_LAST_DOCTORS"

    _index(data["entries"], "entry_id")
    _index(data["sources"], "source_id")
    _index(data["reconstructions"], "reconstruction_id")


@pytest.mark.data
def test_sarei_archive_references_resolve() -> None:
    data = _load_seed()
    entries = _index(data["entries"], "entry_id")
    sources = _index(data["sources"], "source_id")

    for entry_id in data["initial_archive"]["visible_entry_ids"]:
        assert entry_id in entries

    for entry in entries.values():
        for related_id in entry.get("related_entry_ids", []):
            assert related_id in entries, (entry["entry_id"], related_id)
        for contradiction_id in entry.get("contradiction_entry_ids", []):
            assert contradiction_id in entries, (entry["entry_id"], contradiction_id)
        for source_id in entry.get("source_ids", []):
            assert source_id in sources, (entry["entry_id"], source_id)

    for source in sources.values():
        for entry_id in source.get("linked_entry_ids", []):
            assert entry_id in entries, (source["source_id"], entry_id)

    for reconstruction in data["reconstructions"]:
        for entry_id in reconstruction.get("required_entry_ids", []):
            assert entry_id in entries, (reconstruction["reconstruction_id"], entry_id)
        result_entry_id = reconstruction.get("result_entry_id")
        if result_entry_id:
            assert result_entry_id in entries
        for group in reconstruction.get("alternative_requirement_groups", []):
            assert group.get("minimum_matches", 1) >= 1
            candidates = group.get("any_of_entry_ids", []) + group.get("any_of_source_ids", [])
            assert candidates, "alternative requirement group must contain evidence"
            for entry_id in group.get("any_of_entry_ids", []):
                assert entry_id in entries
            for source_id in group.get("any_of_source_ids", []):
                assert source_id in sources


@pytest.mark.data
def test_first_reconstruction_unlocks_fourth_potion_through_knowledge() -> None:
    data = _load_seed()
    reconstructions = _index(data["reconstructions"], "reconstruction_id")
    reconstruction = reconstructions["SAREI_RECON_FIELD_MEDICAL_STORAGE"]

    assert set(reconstruction["required_entry_ids"]) == {
        "SAREI_FIELD_POTIONS",
        "SAREI_MEDICAL_STORAGE",
    }
    assert reconstruction["alternative_requirement_groups"], "must support alternate evidence"

    unlock = next(item for item in reconstruction["unlocks"] if item["unlock_id"] == "POTION_CAPACITY")
    assert unlock["type"] == "LogisticsCapacity"
    assert unlock["integer_value"] == 4
    assert "hermétiques" in unlock["explanation"]


@pytest.mark.data
def test_ashara_contains_explicit_contradiction() -> None:
    data = _load_seed()
    entries = _index(data["entries"], "entry_id")

    official = entries["SAREI_ASHARA_OFFICIAL_ACCOUNT"]
    testimony = entries["SAREI_ASHARA_ABANDONED_TESTIMONY"]

    assert testimony["entry_id"] in official["contradiction_entry_ids"]
    assert official["entry_id"] in testimony["contradiction_entry_ids"]
    assert official["reliability"] == "ProbablePropaganda"
    assert testimony["reliability"] == "SingleTestimony"
