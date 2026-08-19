#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_BOSSES = {"c05_boss_silex_general", "c06_boss_boundary", "c09_boss_consensus", "c10_boss_final"}
EXPECTED_EFFECTS = {"push_front_hero_1", "swap_outer_heroes", "rotate_party_right", "invert_pairs"}


def run(root: Path = ROOT) -> dict:
    data = json.loads((root / "data/combat_displacement.json").read_text(encoding="utf-8"))
    anatomy = json.loads((root / "data/combat_anatomy_v2.json").read_text(encoding="utf-8"))
    scene = (root / "scenes/Main.tscn").read_text(encoding="utf-8")
    v5 = (root / "scripts/ui/main_v5.gd").read_text(encoding="utf-8")
    v6 = (root / "scripts/ui/main_v6.gd").read_text(encoding="utf-8")
    v12 = (root / "scripts/ui/main_v12.gd").read_text(encoding="utf-8")
    v13 = (root / "scripts/ui/main_v13.gd").read_text(encoding="utf-8")
    v14 = (root / "scripts/ui/main_v14.gd").read_text(encoding="utf-8")
    v15 = (root / "scripts/ui/main_v15.gd").read_text(encoding="utf-8")
    bridge = (root / "scripts/world/ashlands_combat_bridge.gd").read_text(encoding="utf-8")
    checks: list[dict] = []
    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    check("Main utilise combat v15", 'res://scripts/ui/main_v15.gd' in scene)
    check("Combat v15 conserve les couches antérieures", 'extends "res://scripts/ui/main_v14.gd"' in v15 and 'extends "res://scripts/ui/main_v13.gd"' in v14 and 'extends "res://scripts/ui/main_v12.gd"' in v13 and 'extends "res://scripts/ui/main_v11.gd"' in v12 and 'extends "res://scripts/ui/main_v5.gd"' in v6)
    hero_rules = data.get("hero_forced_movement", {})
    check("Quatre héros possèdent une règle de coup lourd", set(hero_rules) == {"malvor", "darius", "aurelien", "lysandra"}, str(hero_rules))
    check("Poussée ennemie branchée", '"push_enemy_1"' in v5 and "_move_enemy_relative(target, 1)" in v5)
    check("Traction ennemie branchée", '"pull_enemy_1"' in v5 and "_move_enemy_relative(target, -1)" in v5)
    fear = data.get("fear_recoil", {})
    check("Peur maximale provoque un recul", int(fear.get("threshold", 0)) == 100 and int(fear.get("ranks", 0)) >= 1)
    check("Recul de Peur limité à une fois par round", bool(fear.get("once_per_round", False)) and "fear_recoil_round" in v5)
    limb_rules = data.get("limb_displacement", {})
    for part in ["support_leg", "hind_leg", "rear_leg", "anchor_appendage", "support_limb", "anchor_limb"]:
        check(f"Membre {part} possède un effet de rang", bool(limb_rules.get(part)), str(limb_rules.get(part)))
    check("Démembrement déclenche le déplacement de membre", "_apply_limb_displacement" in v5 and "part_id" in v5)

    maneuvers = data.get("boss_maneuvers", {})
    check("Quatre boss à phase positionnelle", set(maneuvers) == EXPECTED_BOSSES, str(sorted(maneuvers)))
    effects = {str(item.get("effect", "")) for item in maneuvers.values()}
    check("Quatre familles de désorganisation couvertes", EXPECTED_EFFECTS <= effects, str(sorted(effects)))
    boss_anatomies = anatomy.get("boss_anatomies", {})
    for boss_id, maneuver in maneuvers.items():
        required = str(maneuver.get("part_required", ""))
        part_ids = {str(part.get("id", "")) for part in boss_anatomies.get(boss_id, {}).get("parts", [])}
        check(f"{boss_id} : membre requis", bool(required), str(maneuver))
        check(f"{boss_id} : membre requis existe dans son anatomie unique", required in part_ids, f"{required} / {sorted(part_ids)}")
        check(f"{boss_id} : transformation documentée", bool(maneuver.get("lost_part_transform")), str(maneuver))
        check(f"{boss_id} : cadence positive", int(maneuver.get("cadence", 0)) > 0, str(maneuver.get("cadence")))
        check(f"{boss_id} : rencontre présente dans le bridge", f'"{boss_id}"' in bridge)

    check("Bridge expose chapter_boss_id", 'e["chapter_boss_id"] = encounter_id' in bridge)
    check("Boss vérifie le membre avant manœuvre", "_part_is_available(enemy, required)" in v5)
    check("Perte du membre journalise PHASE ALTÉRÉE", "PHASE ALTÉRÉE" in v5)
    check("Manœuvres exécutées avant le tour ennemi", "func enemy_turn()" in v5 and "_apply_boss_formation_maneuvers()" in v5 and "super.enemy_turn()" in v5)
    check("Permutation externe branchée", '"swap_outer_heroes"' in v5 and "_swap_hero_ranks(1, 4)" in v5)
    check("Rotation de compagnie branchée", '"rotate_party_right"' in v5 and "_rotate_party_right()" in v5)
    check("Inversion des paires branchée", '"invert_pairs"' in v5 and "_swap_hero_ranks(1, 2)" in v5 and "_swap_hero_ranks(3, 4)" in v5)
    check("Combat v6 applique les familles avant les déplacements v5", "_apply_enemy_family_maneuvers()" in v6 and "super.enemy_turn()" in v6)

    return {"summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])}, "checks": checks}


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "displacement-combat-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
