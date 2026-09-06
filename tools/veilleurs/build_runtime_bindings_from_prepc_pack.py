#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

PACK_SHA = "0739666c23b6aad99d79128147b84322155bbdd5ff49c62b0990eaf11fec8919"
PREFIX = "litd_canonical_pack_2026-09-03/current/"


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_pack_json(zf: zipfile.ZipFile, name: str, expected_sha=None):
    raw = zf.read(PREFIX + name)
    if expected_sha and sha256_bytes(raw) != expected_sha:
        raise SystemExit(f"SHA mismatch for {name}")
    return json.loads(raw.decode("utf-8"))


def build(repo: Path, pack: Path, output_dir: Path):
    if sha256_bytes(pack.read_bytes()) != PACK_SHA:
        raise SystemExit("Canonical pack SHA mismatch")

    intent = load_json(repo / "data/veilleurs/enemy_skill_intent_contract_v1.json")
    encounter_contract = load_json(repo / "data/veilleurs/encounter_narrative_reward_contract_v1.json")
    archives = load_json(repo / "data/veilleurs/archives_bestiary_29_v1.json")
    encounter_manifest = load_json(repo / "data/veilleurs/encounter_catalog_64_v1.json")

    entity_id_by_name = {r["source_name"]: r["entity_id"] for r in archives["records"]}
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
    for source in skill_sources:
        for row in source["records"]:
            entity_name = row.get("Entité") or row.get("Ennemi")
            entity_id = entity_id_by_name.get(entity_name)
            if not entity_id:
                raise SystemExit(f"Unknown entity in skill source: {entity_name}")
            tree_key = (entity_id, row["Arbre"])
            if tree_key not in tree_map:
                raise SystemExit(f"Unbound skill tree: {tree_key}")
            primary, secondary = tree_map[tree_key]
            node_role = row.get("Rôle du nœud") or row.get("Rôle nœud")
            effective = node_overrides.get(node_role, primary)
            skill_type = row["Type"]
            if skill_type not in action_channels:
                raise SystemExit(f"Unknown action channel: {skill_type}")
            skill_bindings.append(
                {
                    "runtime_skill_id": f"{entity_id}:{row['ID']}",
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
                    "tags": [t for t in row["Tags"].split(";") if t],
                    "effect": row["Effet"],
                }
            )
    if len(skill_bindings) != 1305 or len({r["runtime_skill_id"] for r in skill_bindings}) != 1305:
        raise SystemExit("Skill intent binding must contain 1305 unique runtime skill IDs")

    n_records = narrative["records"]
    r_records = rewards["records"]
    c_records = compositions["records"]
    names_n = [r["Rencontre"] for r in n_records]
    names_r = [r["Rencontre"] for r in r_records]
    names_c = [r["Rencontre"] for r in c_records]
    if not (names_n == names_r == names_c):
        raise SystemExit("The three canonical 64-row encounter sheets do not have identical order")

    merged_encounters = []
    for n, r, c in zip(n_records, r_records, c_records):
        name = n["Rencontre"]
        if name not in encounter_id_by_name:
            raise SystemExit(f"Narrative/reward encounter missing from runtime catalog: {name}")
        if n["Acte"] != r["Acte"] or n["Acte"] != c["Acte"]:
            raise SystemExit(f"Act mismatch for encounter: {name}")
        merged_encounters.append(
            {
                "encounter_id": encounter_id_by_name[name],
                "name": name,
                "act": n["Acte"],
                "type": n["Type"],
                "narrative": {
                    "intro": n["Introduction"],
                    "combat_beat": n["Beat en combat"],
                    "victory": n["Après victoire"],
                    "retreat": n["Retraite"],
                    "remanence_hint": n["Indice Rémanence"],
                },
                "reward": {
                    "threat": r["Menace"],
                    "gold_target": r["Or cible"],
                    "essence_target": r["Essence cible"],
                    "remanence_target": r["Rémanence cible"],
                    "loot": r["Butin"],
                    "capture_rule": r["Capture"],
                    "knowledge_bonus": r["Bonus connaissance"],
                },
            }
        )
    if len(merged_encounters) != 64 or len({r["encounter_id"] for r in merged_encounters}) != 64:
        raise SystemExit("Encounter narrative/reward binding must contain 64 unique runtime IDs")

    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "enemy_skill_intent_binding_1305_v1.json").write_text(
        json.dumps(
            {"version": 1, "count": 1305, "records": skill_bindings},
            ensure_ascii=False,
            separators=(",", ":"),
        ),
        encoding="utf-8",
    )
    (output_dir / "encounter_narrative_reward_64_v1.json").write_text(
        json.dumps(
            {"version": 1, "count": 64, "records": merged_encounters},
            ensure_ascii=False,
            separators=(",", ":"),
        ),
        encoding="utf-8",
    )
    return len(skill_bindings), len(merged_encounters)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--pack", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()
    output = args.output_dir or args.repo / "data/veilleurs/generated"
    skills, encounters = build(args.repo, args.pack, output)
    print(f"Generated {skills} skill-intent bindings and {encounters} encounter narrative/reward bindings")


if __name__ == "__main__":
    main()
