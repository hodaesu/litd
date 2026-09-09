#!/usr/bin/env python3
"""Rebuild neutral hero-skill animation scaffolds for the active starting roster.

This migration helper deliberately does not invent canonical skill names or effects.
The 45 entries per hero are animation-production slots only; authored skill identity
continues to come from the existing character/skill sheets.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HEROES = ROOT / "data" / "heroes.json"
REGISTRY = ROOT / "data" / "movement_registry.json"
BRANCHES = ("offense", "defense", "special")

CLASS_MOTION_FAMILIES = {
    "duelist": {"offense": "blade_precision", "defense": "evasive_guard", "special": "duelist_signature"},
    "breaker": {"offense": "unarmed_impact", "defense": "body_guard", "special": "breaker_signature"},
    "mystic": {"offense": "trame_projection", "defense": "trame_ward", "special": "mystic_signature"},
    "surgeon": {"offense": "blade_precision", "defense": "field_medicine", "special": "surgeon_signature"},
}


def _entry(hero: dict, branch: str, index: int) -> dict:
    hero_id = str(hero["id"])
    class_id = str(hero["class_id"])
    ultimate = index == 15
    variants = ["technical_scaffold", "canonical_choreography_pending_link"]
    if ultimate:
        variants.append("ultimate_signature")
    result = {
        "id": f"hero.{hero_id}_{branch}_{index:02d}",
        "category": "hero_skill",
        "owner": hero_id,
        "trigger": f"skill_{branch}_{index:02d}",
        "motion_family": CLASS_MOTION_FAMILIES.get(class_id, {}).get(branch, "hero_skill_generic"),
        "markers": ["windup", "impact", "recover"],
        "variants": variants,
        "rig": "LITD_HUMANOID_STANDARD",
        "status": "prepared",
        "gameplay_authority": "Godot",
        "root_motion": False,
        "notes": (
            "Slot technique d'animation uniquement. Ne définit ni le nom, ni l'effet, "
            "ni la chorégraphie canonique de la compétence; relier aux fiches existantes "
            "de Mathilde/Marec/Anouk/Aurélien lors de la production Blender."
        ),
    }
    if ultimate:
        result["ultimate_uses_by_level"] = {"16": 1, "32": 2, "48": 3}
    return result


def rebuild() -> dict:
    heroes = json.loads(HEROES.read_text(encoding="utf-8"))
    payload = json.loads(REGISTRY.read_text(encoding="utf-8"))
    retained = [row for row in payload["entries"] if row.get("category") != "hero_skill"]
    generated = [
        _entry(hero, branch, index)
        for hero in heroes
        for branch in BRANCHES
        for index in range(1, 16)
    ]
    payload["entries"] = retained + generated
    payload["summary"]["heroes"] = len(heroes)
    payload["summary"]["hero_skill_movements"] = len(generated)
    payload["summary"]["total"] = len(payload["entries"])
    payload["summary"]["by_category"]["hero_skill"] = len(generated)
    payload["generated_from"] = list(dict.fromkeys(payload.get("generated_from", []) + [
        "canonical_roster.json",
        "rebind_starting_hero_movements.py",
    ]))
    REGISTRY.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return payload


def main() -> int:
    payload = rebuild()
    hero_ids = [hero["id"] for hero in json.loads(HEROES.read_text(encoding="utf-8"))]
    print(f"rebound {payload['summary']['hero_skill_movements']} hero-skill movement slots for {hero_ids}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
