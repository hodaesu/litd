import base64
import hashlib
import json
import zlib
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "veilleurs"
GENERATED = DATA / "generated"
PACK_SHA = "0739666c23b6aad99d79128147b84322155bbdd5ff49c62b0990eaf11fec8919"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def decode_cache(path: Path) -> tuple[dict, dict, bytes]:
    cache = load(path)
    assert cache["source_pack_sha256"] == PACK_SHA
    raw = zlib.decompress(base64.b64decode(cache["payload"]))
    assert len(raw) == cache["uncompressed_bytes"]
    assert hashlib.sha256(raw).hexdigest() == cache["raw_json_sha256"]
    return cache, json.loads(raw.decode("utf-8")), raw


def test_exact_skill_ai_cache_is_1305_unique_and_29_by_45():
    manifest = load(GENERATED / "enemy_skill_ai_catalog_manifest_v1.json")
    assert manifest["source_pack_sha256"] == PACK_SHA
    assert manifest["total_records"] == 1305
    assert manifest["entity_count"] == 29
    records = []
    for act in manifest["acts"]:
        cache, decoded, raw = decode_cache(ROOT / act["path"].removeprefix("res://"))
        assert cache["act"] == act["act"]
        assert cache["record_count"] == act["count"]
        assert hashlib.sha256(raw).hexdigest() == act["raw_json_sha256"]
        assert len(decoded["records"]) == act["count"]
        schema = decoded["schema"]
        records.extend(dict(zip(schema, row)) for row in decoded["records"])

    assert len(records) == 1305
    assert len({record["rid"] for record in records}) == 1305
    by_entity = Counter(record["entity"] for record in records)
    assert len(by_entity) == 29
    assert set(by_entity.values()) == {45}

    by_tree = Counter((record["entity"], record["tree"]) for record in records)
    assert len(by_tree) == 87
    assert set(by_tree.values()) == {15}

    delie = [record for record in records if record["entity"] == "delie_affame"]
    assert len(delie) == 45
    assert Counter(record["tree"] for record in delie) == {
        "Chair ouverte": 15,
        "Faim basse": 15,
        "Fuite des cendres": 15,
    }
    assert all(record["rid"].startswith("delie_affame:") for record in delie)


def test_encounter_cache_contains_all_64_narrative_reward_capture_bindings():
    cache, decoded, _ = decode_cache(GENERATED / "encounter_narrative_reward_64_v1.json")
    assert cache["record_count"] == decoded["count"] == 64
    records = decoded["records"]
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
