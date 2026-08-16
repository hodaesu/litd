#!/usr/bin/env python3
"""Generate deterministic Blender production jobs for playable and hostile characters."""
from __future__ import annotations

import argparse
import json
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "data/blender/character_jobs.json"


def slug(value: str) -> str:
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")


def _scale_for_hp(hp: int, boss: bool = False) -> float:
    base = 1.18 if boss else 0.86 + min(hp, 130) / 500.0
    return round(base, 2)


def _job(identifier: str, name: str, category: str, archetype: str, art: str,
         hp: int, boss: bool = False, recruitable: bool = False) -> dict:
    scale = _scale_for_hp(hp, boss)
    return {
        "job_id": f"character_{identifier}", "character_id": identifier,
        "name": name, "category": category, "archetype": archetype,
        "reference_art": art, "height_m": round(1.78 * scale, 2),
        "body_scale": scale, "rig_profile": "humanoid_biped_v1",
        "recruitable": recruitable, "boss": boss,
        "collections": ["BODY", "ARMATURE", "EQUIPMENT", "COLLISION", "SOCKETS", "LIGHTING", "CAMERA"],
        "equipment_sockets": ["weapon_r", "weapon_l", "head", "back", "fx_root"],
        "animation_set": ["idle", "walk", "run", "attack", "hit", "death"],
        "lod_levels": [0, 1, 2], "collision": "capsule",
        "material_slots": ["M_skin", "M_cloth", "M_metal"],
        "output": f"builds/characters/{category}/{identifier}",
    }


def build_jobs(root: Path = ROOT) -> list[dict]:
    heroes = json.loads((root / "data/heroes.json").read_text(encoding="utf-8"))
    enemies = json.loads((root / "data/enemies.json").read_text(encoding="utf-8"))
    minibosses = json.loads((root / "data/levels/ashlands_minibosses.json").read_text(encoding="utf-8"))
    jobs = []
    for hero in heroes:
        jobs.append(_job(hero["id"], hero["name"], "hero", hero["class_id"],
                         f"assets/heroes/{hero['class_id']}.webp", hero["max_hp"], recruitable=True))
    for enemy in enemies:
        identifier = f"enemy_{int(enemy['id']):02d}_{slug(enemy['name'])}"
        category = "boss" if enemy.get("boss", False) else "enemy"
        jobs.append(_job(identifier, enemy["name"], category, "hostile_humanoid",
                         f"assets/enemies/{enemy['art']}", enemy["hp"], boss=enemy.get("boss", False)))
    for pool_name in ("normal_pool", "secret_pool"):
        for enemy in minibosses[pool_name]:
            jobs.append(_job(enemy["id"], enemy["name"], "miniboss", enemy["archetype"],
                             "", 120, boss=True))
    return jobs


def generate(output: Path = OUTPUT, root: Path = ROOT) -> dict:
    jobs = build_jobs(root)
    payload = {"version": 1, "generator": "tools/blender/generate_character_jobs.py", "jobs": jobs}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    expected = {"version": 1, "generator": "tools/blender/generate_character_jobs.py", "jobs": build_jobs()}
    rendered = json.dumps(expected, ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if not args.output.exists() or args.output.read_text(encoding="utf-8") != rendered:
            raise SystemExit("character Blender jobs are out of date")
        print(f"{len(expected['jobs'])} character Blender jobs are current")
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(rendered, encoding="utf-8")
    print(f"generated {len(expected['jobs'])} character Blender jobs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
