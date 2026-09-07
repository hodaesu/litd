#!/usr/bin/env python3
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import unicodedata
import zipfile
import zlib

PACK_SHA = "0739666c23b6aad99d79128147b84322155bbdd5ff49c62b0990eaf11fec8919"
PREFIX = "litd_canonical_pack_2026-09-03/current/"
SKILL_SCHEMA = [
    "rid", "sid", "entity", "tree", "name", "type",
    "node_role", "positions", "power", "precision", "tags",
]


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def compact_bytes(payload) -> bytes:
    return json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def compressed_cache(raw: bytes, *, record_count: int, act: int | None = None) -> dict:
    cache = {
        "version": 1,
        "status": "generated_runtime_cache",
        "source_pack_sha256": PACK_SHA,
        "record_count": record_count,
        "uncompressed_bytes": len(raw),
        "raw_json_sha256": sha256_bytes(raw),
        "compression": "zlib_deflate_base64",
        "payload": base64.b64encode(zlib.compress(raw, 9)).decode("ascii"),
    }
    if act is not None:
        cache = {"version": 1, "status": "generated_runtime_cache", "act": act, **{
            key: value for key, value in cache.items() if key not in ("version", "status")
        }}
    return cache


def write_compact(path: Path, payload) -> None:
    path.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )


def read_pack_json(zf: zipfile.ZipFile, name: str, expected_sha=None):
    raw = zf.read(PREFIX + name)
    if expected_sha and sha256_bytes(raw) != expected_sha:
        raise SystemExit(f"SHA mismatch for {name}")
    return json.loads(raw.decode("utf-8"))


def normalize_entity_id(value: str) -> str:
    ascii_value = (
        unicodedata.normalize("NFKD", value)
        .encode("ascii", "ignore")
        .decode("ascii")
        .lower()
    )
    return re.sub(r"[^a-z0-9]+", "_", ascii_value).strip("_")


def act_number(value: str) -> int:
    text = str(value).strip()
    for roman, number in (("V", 5), ("IV", 4), ("III", 3), ("II", 2), ("I", 1)):
        if text.startswith(roman):
            return number
    raise SystemExit(f"Unknown act label: {value}")


def build(repo: Path, pack: Path, output_dir: Path):
    if sha256_bytes(pack.read_bytes()) != PACK_SHA:
        raise SystemExit("Canonical pack SHA mismatch")

    intent = load_json(repo / "data/veilleurs/enemy_skill_intent_contract_v1.json")
    encounter_contract = load_json(repo / "data/veilleurs/encounter_narrative_reward_contract_v1.json")
    archives = load_json(repo / "data/veilleurs/archives_bestiary_29_v1.json")
    encounter_manifest = load_json(repo / "data/veilleurs/encounter_catalog_64_v1.json")

    entity_id_by_name = {r["source_name"]: r["entity_id"] for r in archives["records"]}
    valid_entity_ids = set(entity_id_by_name.values())
    if len(valid_entity_ids) != 29:
        raise SystemExit("Archive binding is not exactly 29 unique entities")

    tree_map = {
        (entity_id, tree): (primary, secondary)
        for entity_id, tree, primary, secondary in intent["tree_bindings"]
    }
    node_overrides = intent["node_role_overrides"]
    action_channels = intent["action_channels"]

    encounter_id_by_name = {}
    for ref in encounter_manifest["act_files"]:
        act_data = load_json(repo / ref["path"].removeprefix("res://"))
        for rec in act_data["records"]:
            if rec["name"] in encounter_id_by_name:
                raise SystemExit(f"Duplicate runtime encounter name: {rec['name']}")
            encounter_id_by_name[rec["name"]] = rec["id"]
    if len(encounter_id_by_name) != 64:
        raise SystemExit("Runtime encounter catalog is not exactly 64 unique names")

    source_hashes = {f["name"]: f["sha256"] for f in intent["source"]["files"]}
    with zipfile.ZipFile(pack) as zf:
        skill_sources = [
            read_pack_json(zf, "comp_bestiaire_585.json", source_hashes["comp_bestiaire_585.json"]),
            read_pack_json(zf, "comp_ii_v_720.json", source_hashes["comp_ii_v_720.json"]),
        ]
        narrative = read_pack_json(
            zf,
            "rencontres_narratives_64.json",
            encounter_contract["source"]["narrative"]["sha256"],
        )
        rewards = read_pack_json(
            zf,
            "recompenses_capture.json",
            encounter_contract["source"]["reward_capture"]["sha256"],
        )
        compositions = read_pack_json(
            zf,
            "compositions_64.json",
            encounter_contract["source"]["compositions"]["sha256"],
        )

    skill_bindings = []
    compact_rows_by_act = {act: [] for act in range(1, 6)}
    seen_runtime_ids = set()
    tree_counts = {}

    for source in skill_sources:
        for row in source["records"]:
            entity_name = row.get("Entité") or row.get("Ennemi")
            entity_id = normalize_entity_id(entity_name)
            if entity_id not in valid_entity_ids:
                raise SystemExit(f"Unknown entity in skill source: {entity_name} -> {entity_id}")
            if entity_id_by_name.get(entity_name) != entity_id:
                raise SystemExit(f"Entity normalization mismatch: {entity_name} -> {entity_id}")

            tree_key = (entity_id, row["Arbre"])
            if tree_key not in tree_map:
                raise SystemExit(f"Unbound skill tree: {tree_key}")
            primary, secondary = tree_map[tree_key]
            node_role = row.get("Rôle du nœud") or row.get("Rôle nœud")
            effective = node_overrides.get(node_role, primary)
            skill_type = row["Type"]
            if skill_type not in action_channels:
                raise SystemExit(f"Unknown action channel: {skill_type}")

            runtime_id = f"{entity_id}:{row['ID']}"
            if runtime_id in seen_runtime_ids:
                raise SystemExit(f"Duplicate runtime skill ID: {runtime_id}")
            seen_runtime_ids.add(runtime_id)

            skill_bindings.append(
                {
                    "runtime_skill_id": runtime_id,
                    "source_skill_id": row["ID"],
                    "entity_id": entity_id,
                    "tree": row["Arbre"],
                    "skill_name": row["Compétence"],
                    "skill_type": skill_type,
                    "node_role": node_role,
                    "intent_family": effective,
                    "tree_primary_intent": primary,
                    "secondary_intent": secondary,
                    "action_channel": action_channels[skill_type],
                    "positions": row["Positions"],
                    "power_0_5": row["Puissance 0-5"],
                    "precision_pct": row["Précision %"],
                    "tags": [tag for tag in row["Tags"].split(";") if tag],
                    "effect": row["Effet"],
                }
            )

            act = act_number(row.get("Acte/Région") or row.get("Acte"))
            compact_rows_by_act[act].append(
                [
                    runtime_id,
                    row["ID"],
                    entity_id,
                    row["Arbre"],
                    row["Compétence"],
                    skill_type,
                    node_role,
                    row["Positions"],
                    row["Puissance 0-5"],
                    row["Précision %"],
                    row["Tags"],
                ]
            )
            tree_counts[tree_key] = tree_counts.get(tree_key, 0) + 1

    if len(skill_bindings) != 1305 or len(seen_runtime_ids) != 1305:
        raise SystemExit("Skill binding must contain 1305 unique runtime skill IDs")
    if len(tree_counts) != 87 or set(tree_counts.values()) != {15}:
        raise SystemExit("Skill source must contain exactly 87 trees with 15 skills each")
    per_entity = {}
    for record in skill_bindings:
        per_entity[record["entity_id"]] = per_entity.get(record["entity_id"], 0) + 1
    if len(per_entity) != 29 or set(per_entity.values()) != {45}:
        raise SystemExit("Skill source must contain exactly 29 entities with 45 skills each")

    n_records = narrative["records"]
    r_records = rewards["records"]
    c_records = compositions["records"]
    names_n = [record["Rencontre"] for record in n_records]
    names_r = [record["Rencontre"] for record in r_records]
    names_c = [record["Rencontre"] for record in c_records]
    if not (names_n == names_r == names_c):
        raise SystemExit("The three canonical 64-row encounter sheets do not have identical order")

    merged_encounters = []
    for n_record, r_record, c_record in zip(n_records, r_records, c_records):
        name = n_record["Rencontre"]
        if name not in encounter_id_by_name:
            raise SystemExit(f"Narrative/reward encounter missing from runtime catalog: {name}")
        if n_record["Acte"] != r_record["Acte"] or n_record["Acte"] != c_record["Acte"]:
            raise SystemExit(f"Act mismatch for encounter: {name}")
        merged_encounters.append(
            {
                "encounter_id": encounter_id_by_name[name],
                "name": name,
                "act": n_record["Acte"],
                "type": n_record["Type"],
                "narrative": {
                    "intro": n_record["Introduction"],
                    "combat_beat": n_record["Beat en combat"],
                    "victory": n_record["Après victoire"],
                    "retreat": n_record["Retraite"],
                    "remanence_hint": n_record["Indice Rémanence"],
                },
                "reward": {
                    "threat": r_record["Menace"],
                    "gold_target": r_record["Or cible"],
                    "essence_target": r_record["Essence cible"],
                    "remanence_target": r_record["Rémanence cible"],
                    "loot": r_record["Butin"],
                    "capture_rule": r_record["Capture"],
                    "knowledge_bonus": r_record["Bonus connaissance"],
                },
            }
        )
    if len(merged_encounters) != 64 or len({r["encounter_id"] for r in merged_encounters}) != 64:
        raise SystemExit("Encounter narrative/reward binding must contain 64 unique runtime IDs")

    output_dir.mkdir(parents=True, exist_ok=True)

    write_compact(
        output_dir / "enemy_skill_intent_binding_1305_v1.json",
        {"version": 1, "count": 1305, "records": skill_bindings},
    )

    manifest_acts = []
    act_distribution = {1: 405, 2: 225, 3: 225, 4: 225, 5: 225}
    for act in range(1, 6):
        rows = compact_rows_by_act[act]
        if len(rows) != act_distribution[act]:
            raise SystemExit(f"Unexpected skill count for act {act}: {len(rows)}")
        raw = compact_bytes({"schema": SKILL_SCHEMA, "records": rows})
        cache = compressed_cache(raw, record_count=len(rows), act=act)
        filename = f"enemy_skill_ai_catalog_act_{act}_v1.json"
        write_compact(output_dir / filename, cache)
        manifest_acts.append(
            {
                "act": act,
                "path": f"res://data/veilleurs/generated/{filename}",
                "count": len(rows),
                "raw_json_sha256": cache["raw_json_sha256"],
            }
        )

    manifest = {
        "version": 1,
        "status": "generated_runtime_cache_manifest",
        "source_pack_sha256": PACK_SHA,
        "total_records": 1305,
        "entity_count": 29,
        "skills_per_entity": 45,
        "trees_per_entity": 3,
        "skills_per_tree": 15,
        "schema": [
            "runtime_skill_id", "source_skill_id", "entity_id", "tree", "skill_name",
            "skill_type", "node_role", "positions", "power_0_5", "precision_pct", "tags",
        ],
        "acts": manifest_acts,
        "generation": {
            "source_files": ["comp_bestiaire_585.json", "comp_ii_v_720.json"],
            "runtime_id_format": "{entity_id}:{source_skill_id}",
            "entity_id_normalization": "unicode_nfkd_ascii_lower_non_alnum_to_underscore",
            "payload": "compact_json_zlib_deflate_base64",
            "source_is_authoritative": True,
            "cache_is_reproducible": True,
        },
    }
    write_compact(output_dir / "enemy_skill_ai_catalog_manifest_v1.json", manifest)

    encounter_raw = compact_bytes(
        {"version": 1, "count": 64, "records": merged_encounters}
    )
    encounter_cache = compressed_cache(encounter_raw, record_count=64)
    write_compact(
        output_dir / "encounter_narrative_reward_64_v1.json",
        encounter_cache,
    )

    return {
        "skills": len(skill_bindings),
        "encounters": len(merged_encounters),
        "entities": len(per_entity),
        "trees": len(tree_counts),
        "skill_cache_hashes": {
            str(entry["act"]): entry["raw_json_sha256"] for entry in manifest_acts
        },
        "encounter_cache_hash": encounter_cache["raw_json_sha256"],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--pack", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()
    output = args.output_dir or args.repo / "data/veilleurs/generated"
    report = build(args.repo, args.pack, output)
    print(json.dumps(report, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
