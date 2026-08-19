#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_FAMILIES = {"humanoid", "beast", "arachnid", "aberration", "construct", "elite", "boss"}
EXPECTED_GENERIC = {"humanoid", "beast", "arachnid", "aberration", "construct"}


def run(root: Path = ROOT) -> dict:
    data = json.loads((root / "data/enemy_family_tactics.json").read_text(encoding="utf-8"))
    enemies = json.loads((root / "data/enemies.json").read_text(encoding="utf-8"))
    dismemberment = json.loads((root / "data/combat_dismemberment.json").read_text(encoding="utf-8"))
    anatomy = json.loads((root / "data/combat_anatomy_v2.json").read_text(encoding="utf-8"))
    scene = (root / "scenes/Main.tscn").read_text(encoding="utf-8")
    v6 = (root / "scripts/ui/main_v6.gd").read_text(encoding="utf-8")
    v5 = (root / "scripts/ui/main_v5.gd").read_text(encoding="utf-8")
    v12 = (root / "scripts/ui/main_v12.gd").read_text(encoding="utf-8")
    v13 = (root / "scripts/ui/main_v13.gd").read_text(encoding="utf-8")
    v14 = (root / "scripts/ui/main_v14.gd").read_text(encoding="utf-8")
    v15 = (root / "scripts/ui/main_v15.gd").read_text(encoding="utf-8")
    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    families = data.get("families", {})
    groups = data.get("generic_enemy_ids", {})
    check("Familles ennemies : sept comportements présents", set(families) == EXPECTED_FAMILIES, str(sorted(families)))
    check("Familles génériques : cinq groupes présents", set(groups) == EXPECTED_GENERIC, str(sorted(groups)))
    nonboss_ids = {int(enemy["id"]) for enemy in enemies if not bool(enemy.get("boss", False))}
    assigned: list[int] = []
    for family_id, ids in groups.items():
        assigned.extend(int(value) for value in ids)
        check(f"{family_id} : groupe non vide", bool(ids), str(ids))
    check("Tous les ennemis génériques non-boss sont classés", set(assigned) == nonboss_ids, f"assignés={sorted(set(assigned))} attendus={sorted(nonboss_ids)}")
    check("Aucun ennemi générique n'est classé deux fois", len(assigned) == len(set(assigned)), str(assigned))

    signatures = set()
    valid_effects = {"push_front_hero_1", "pull_rear_hero_1", "swap_middle_heroes", "swap_outer_heroes"}
    valid_reactions = {"lose_maneuver", "retreat_self_1", "pull_self_to_front", "none"}
    for family_id, family in families.items():
        cadence = int(family.get("cadence", 0))
        effect = str(family.get("effect", ""))
        required = str(family.get("required_part", ""))
        reaction = str(family.get("lost_reaction", ""))
        check(f"{family_id} : cadence positive", cadence > 0, str(cadence))
        check(f"{family_id} : effet de rang reconnu", effect in valid_effects, effect)
        check(f"{family_id} : réaction de membre reconnue", reaction in valid_reactions, reaction)
        check(f"{family_id} : description présente", bool(family.get("description")), str(family))
        signatures.add((effect, cadence, required))
    check("Chaque famille a une signature tactique propre", len(signatures) == len(families), str(sorted(signatures)))

    profiles = dismemberment.get("profiles", {})
    known_parts = {part.get("id") for profile in profiles.values() for part in profile.get("parts", [])}
    for family_id, family in families.items():
        required = str(family.get("required_part", ""))
        if required:
            check(f"{family_id} : membre requis existe dans l'anatomie", required in known_parts, required)

    overrides = data.get("boss_required_part_overrides", {})
    for boss_id, part_id in overrides.items():
        boss_parts = {str(part.get("id", "")) for part in anatomy.get("boss_anatomies", {}).get(boss_id, {}).get("parts", [])}
        check(f"{boss_id} : override de partie existe", str(part_id) in boss_parts, f"{part_id} / {sorted(boss_parts)}")
    check("Mini-boss : membre offensif cohérent avec profil boss", families.get("elite", {}).get("required_part") == "offensive_limb")

    check("Main utilise combat v15", 'res://scripts/ui/main_v15.gd' in scene)
    check("Combat v15 conserve v14", 'extends "res://scripts/ui/main_v14.gd"' in v15)
    check("Combat v14 conserve v13", 'extends "res://scripts/ui/main_v13.gd"' in v14)
    check("Combat v13 conserve v12", 'extends "res://scripts/ui/main_v12.gd"' in v13)
    check("Combat v12 conserve v11", 'extends "res://scripts/ui/main_v11.gd"' in v12)
    check("Combat v6 hérite de v5", 'extends "res://scripts/ui/main_v5.gd"' in v6)
    check("Combat v5 reste disponible sous v6", 'extends "res://scripts/ui/main_v4.gd"' in v5)
    check("Famille déterminée par boss/miniboss/ID", '_family_for_enemy' in v6 and 'is_miniboss' in v6 and 'generic_enemy_ids' in v6)
    check("Boss spécifique prioritaire sur famille générique", 'not _boss_maneuver_for(enemy).is_empty()' in v6)
    check("Overrides de boss uniques utilisés", '_family_required_part' in v6 and 'boss_required_part_overrides' in v6)
    check("Familles agissent avant le moteur ennemi hérité", 'func enemy_turn()' in v6 and '_apply_enemy_family_maneuvers()' in v6 and 'super.enemy_turn()' in v6)
    check("Humanoïdes et bêtes peuvent pousser", '"push_front_hero_1"' in v6)
    check("Arachnides peuvent tirer l'arrière-garde", '"pull_rear_hero_1"' in v6 and '_move_hero_relative(rear, -1)' in v6)
    check("Aberrations peuvent permuter le centre", '"swap_middle_heroes"' in v6 and '_swap_hero_ranks(2, 3)' in v6)
    check("Boss génériques peuvent permuter les extrêmes", '"swap_outer_heroes"' in v6 and '_swap_hero_ranks(1, 4)' in v6)
    check("Perte du membre critique déclenche une réaction", '_apply_family_limb_reaction' in v6 and 'required != part_id' in v6)
    check("Réaction bestiale peut faire reculer", '"retreat_self_1"' in v6 and '_move_enemy_relative(enemy, 1)' in v6)
    check("Réaction aberrante peut ramener en première ligne", '"pull_self_to_front"' in v6 and '_move_enemy_to_rank(enemy, 1)' in v6)

    return {"summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])}, "checks": checks}


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "enemy-family-tactics-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
