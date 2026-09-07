import hashlib
import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "veilleurs"
GENERATED = DATA / "generated"
SKILLS = DATA / "skills"
PACK_SHA = "0739666c23b6aad99d79128147b84322155bbdd5ff49c62b0990eaf11fec8919"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_exact_skill_runtime_uses_direct_tree_json_1305_unique_and_29_by_45():
    catalog = load(SKILLS / "enemy_skill_runtime_catalog_v1.json")
    assert catalog["version"] == 1
    assert catalog["status"] == "source_backed_runtime_catalog"
    assert catalog["canonical_source"]["pack_sha256"] == PACK_SHA
    assert catalog["counts"]["skills"] == 1305
    assert catalog["counts"]["entities"] == 29
    assert catalog["counts"]["trees"] == 87
    assert catalog["counts"]["runtime_id_collisions"] == 0

    runtime_ids = []
    entity_counts = Counter()
    tree_counts = Counter()
    delie_tree_counts = Counter()

    for file_ref in catalog["canonical_source"]["tree_files"]:
        path = ROOT / file_ref["path"].removeprefix("res://")
        source = load(path)
        trees = source["trees"]
        assert len(trees) == file_ref["trees"]
        assert sum(len(tree["source_skill_ids"]) for tree in trees) == file_ref["skills"]
        for tree in trees:
            entity_id = tree["entity_id"]
            tree_name = tree["tree"]
            source_ids = tree["source_skill_ids"]
            assert len(source_ids) == 15
            tree_counts[(entity_id, tree_name)] += len(source_ids)
            entity_counts[entity_id] += len(source_ids)
            if entity_id == "delie_affame":
                delie_tree_counts[tree_name] += len(source_ids)
            runtime_ids.extend(f"{entity_id}:{source_id}" for source_id in source_ids)

    assert len(runtime_ids) == 1305
    assert len(set(runtime_ids)) == 1305
    assert len(entity_counts) == 29
    assert set(entity_counts.values()) == {45}
    assert len(tree_counts) == 87
    assert set(tree_counts.values()) == {15}
    assert delie_tree_counts == Counter({
        "Chair ouverte": 15,
        "Faim basse": 15,
        "Fuite des cendres": 15,
    })
    assert all(runtime_id.startswith("delie_affame:") for runtime_id in runtime_ids if runtime_id.startswith("delie_affame:"))


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
