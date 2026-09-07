import hashlib
import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "veilleurs"
GENERATED = DATA / "generated"
PACK_SHA = "0739666c23b6aad99d79128147b84322155bbdd5ff49c62b0990eaf11fec8919"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_exact_skill_binding_is_direct_json_1305_unique_and_29_by_45():
    binding = load(GENERATED / "enemy_skill_intent_binding_1305_v1.json")
    assert binding["version"] == 1
    assert binding["count"] == 1305
    records = binding["records"]
    assert len(records) == 1305
    assert len({record["runtime_skill_id"] for record in records}) == 1305

    by_entity = Counter(record["entity_id"] for record in records)
    assert len(by_entity) == 29
    assert set(by_entity.values()) == {45}

    by_tree = Counter((record["entity_id"], record["tree"]) for record in records)
    assert len(by_tree) == 87
    assert set(by_tree.values()) == {15}

    delie = [record for record in records if record["entity_id"] == "delie_affame"]
    assert len(delie) == 45
    assert Counter(record["tree"] for record in delie) == {
        "Chair ouverte": 15,
        "Faim basse": 15,
        "Fuite des cendres": 15,
    }
    assert all(record["runtime_skill_id"].startswith("delie_affame:") for record in delie)


def test_encounter_manifest_loads_64_records_from_eight_uncompressed_json_chunks():
    manifest = load(GENERATED / "encounter_narrative_reward_64_manifest_v1.json")
    assert manifest["version"] == 2
    assert manifest["status"] == "canonical_uncompressed_runtime_manifest"
    assert manifest["source_pack_sha256"] == PACK_SHA
    assert manifest["count"] == 64
    assert len(manifest["chunks"]) == 8

    records = []
    for index, chunk_ref in enumerate(manifest["chunks"], 1):
        path = ROOT / chunk_ref["path"].removeprefix("res://")
        raw = path.read_bytes()
        assert hashlib.sha256(raw).hexdigest() == chunk_ref["sha256"]
        chunk = json.loads(raw.decode("utf-8"))
        assert chunk["version"] == 1
        assert chunk["chunk"] == index
        assert chunk["count"] == chunk_ref["count"] == 8
        assert len(chunk["records"]) == 8
        records.extend(chunk["records"])

    assert len(records) == 64
    assert len({record["encounter_id"] for record in records}) == 64
    assert len({record["name"] for record in records}) == 64
    assert Counter(record["encounter_id"].split("_")[1] for record in records) == {
        "a1": 16,
        "a2": 12,
        "a3": 12,
        "a4": 12,
        "a5": 12,
    }

    for record in records:
        narrative = record["narrative"]
        reward = record["reward"]
        assert all(narrative[key] for key in ("intro", "combat_beat", "victory", "retreat", "remanence_hint"))
        assert reward["threat"] >= 0
        assert reward["gold_target"] >= 0
        assert reward["essence_target"] >= 0
        assert reward["remanence_target"] >= 0
        assert reward["loot"]
        assert reward["capture_rule"]
        assert reward["knowledge_bonus"]

    first = next(record for record in records if record["encounter_id"] == "enc_a1_01")
    assert first["name"] == "Charognards du bord"
    assert "Délié Affamé" in first["narrative"]["intro"]
    assert first["reward"]["gold_target"] == 22
    assert first["reward"]["essence_target"] == 2


def test_obsolete_compressed_runtime_artifacts_are_removed():
    obsolete = [
        GENERATED / "encounter_narrative_reward_64_v1.json",
        GENERATED / "enemy_skill_ai_catalog_manifest_v1.json",
        *(GENERATED / f"enemy_skill_ai_catalog_act_{act}_v1.json" for act in range(1, 6)),
    ]
    assert all(not path.exists() for path in obsolete)
