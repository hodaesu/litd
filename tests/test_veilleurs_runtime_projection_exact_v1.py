import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "veilleurs"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_each_runtime_encounter_preserves_source_type_actor_count_and_composition():
    source = load(DATA / "encounter_index_v1.json")
    manifest = load(DATA / "encounter_catalog_64_v1.json")

    source_by_name = {
        record["name"]: record
        for records in source["acts"].values()
        for record in records
    }
    runtime = []
    for ref in manifest["act_files"]:
        runtime.extend(load(ROOT / ref["path"].removeprefix("res://"))["records"])

    assert set(source_by_name) == {record["name"] for record in runtime}
    for record in runtime:
        expected = source_by_name[record["name"]]
        assert record["type"] == expected["type"]
        assert record["actors"] == expected["actors"]
        assert " + ".join(record["composition_names"]) == expected["composition"]


def test_each_runtime_boss_phase_preserves_every_master_phase_field():
    source = load(DATA / "boss_phase_catalog_v1.json")
    manifest = load(DATA / "boss_phase_knowledge_v1.json")

    runtime_records = []
    runtime_name_by_id = {}
    for ref in manifest["boss_files"]:
        data = load(ROOT / ref["path"].removeprefix("res://"))
        runtime_name_by_id[data["boss_id"]] = data["canonical_name"]
        runtime_records.extend(data["records"])

    runtime_by_key = {
        (runtime_name_by_id[record["boss_id"]], record["phase"]): record
        for record in runtime_records
    }
    assert len(runtime_by_key) == 16

    for expected in source["records"]:
        key = (expected["boss"], expected["phase"])
        assert key in runtime_by_key
        record = runtime_by_key[key]
        assert record["phase_title"] == expected["title"]
        assert record["doctrine"] == expected["doctrine"]
        assert record["trigger"] == expected["trigger"]
        assert record["mechanics"] == expected["mechanics"]
        assert record["counterplay"] == expected["counterplay"]
        assert record["arena"] == expected["arena"]
        assert " / ".join(record["source_intent_labels"]) == expected["intents"]
        assert record["punished_error"] == expected["punished_error"]
        assert record["transition"] == expected["transition"]
        assert record["reward"] == expected["reward"]


def test_runtime_boss_ids_and_nonrecruitment_match_v2_normalization():
    normalized = load(DATA / "canonical_bestiary_normalization_v2.json")
    manifest = load(DATA / "boss_phase_knowledge_v1.json")

    expected = {
        boss["runtime_id"]: (boss["name"], boss["phases"], boss["recruitable"])
        for boss in normalized["bosses"]
    }
    assert set(expected) == set(manifest["boss_phase_counts"])
    for ref in manifest["boss_files"]:
        name, phases, recruitable = expected[ref["boss_id"]]
        data = load(ROOT / ref["path"].removeprefix("res://"))
        assert data["canonical_name"] == name
        assert data["count"] == phases
        assert data["recruitable"] == recruitable is False
