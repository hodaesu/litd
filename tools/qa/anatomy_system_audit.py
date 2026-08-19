#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORE_BOSSES = {
    "c05_boss_silex_general", "c06_boss_boundary", "c09_boss_consensus", "c10_boss_final",
    "vestige_ashai_boss_seventh_voice", "vestige_silex_boss_last_strategist",
    "vestige_saan_boss_last_watch", "vestige_vaor_boss_command_without_body",
    "vestige_lyrmar_boss_absent_cartographer", "vestige_sahmir_boss_single_interpreter",
    "vestige_ydris_boss_living_theorem",
}
DEEP_BOSSES = {
    "vestige_ashai_boss_seventh_voice", "vestige_silex_boss_last_strategist",
    "vestige_saan_boss_last_watch", "vestige_vaor_boss_command_without_body",
    "vestige_lyrmar_boss_absent_cartographer", "vestige_sahmir_boss_single_interpreter",
    "vestige_ydris_boss_living_theorem",
}
HEROES = {"malvor", "darius", "aurelien", "lysandra"}


def run(root: Path = ROOT) -> dict:
    anatomy = json.loads((root / "data/combat_anatomy_v2.json").read_text(encoding="utf-8"))
    families = json.loads((root / "data/enemy_family_tactics.json").read_text(encoding="utf-8"))
    ai = json.loads((root / "data/combat_post_mutilation_ai.json").read_text(encoding="utf-8"))
    psychology = json.loads((root / "data/combat_mutilation_psychology.json").read_text(encoding="utf-8"))
    capture = json.loads((root / "data/capture_wound_rules.json").read_text(encoding="utf-8"))
    injuries = json.loads((root / "data/combat_injuries.json").read_text(encoding="utf-8"))
    blender = json.loads((root / "data/blender/dismemberment_contract.json").read_text(encoding="utf-8"))
    project = (root / "project.godot").read_text(encoding="utf-8")
    scene = (root / "scenes/Main.tscn").read_text(encoding="utf-8")
    anatomy_runtime = (root / "scripts/core/anatomy_runtime.gd").read_text(encoding="utf-8")
    capture_runtime = (root / "scripts/core/capture_wound_runtime.gd").read_text(encoding="utf-8")
    injury_runtime = (root / "scripts/core/injury_runtime.gd").read_text(encoding="utf-8")
    ui = {i: (root / f"scripts/ui/main_v{i}.gd").read_text(encoding="utf-8") for i in range(6, 15)}
    generator = (root / "tools/blender/generate_dismemberment_jobs.py").read_text(encoding="utf-8")

    checks: list[dict] = []
    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    check("Anatomie : Main utilise v14", 'res://scripts/ui/main_v14.gd' in scene)
    for child in range(14, 6, -1):
        check(f"Anatomie : v{child} hérite de v{child-1}", f'extends "res://scripts/ui/main_v{child-1}.gd"' in ui[child])

    check("Étape 1 : ciblage anatomique explicite", "select_part" in anatomy_runtime and "cycle_part" in anatomy_runtime and "selected_anatomy_part" in ui[7])
    check("Étape 1 : difficulté de toucher une partie", "hit_modifier" in json.dumps(anatomy, ensure_ascii=False) and "part_hit_chance" in anatomy_runtime)
    check("Étape 1 : partie protégée réduit la précision", "protected_anatomy_part" in anatomy_runtime and "chance -= 15" in anatomy_runtime and "PROTÉGÉE" in ui[7])
    check("Étape 2 : trauma stocké par membre", "anatomy_part_trauma" in anatomy_runtime and "part_threshold" in anatomy_runtime)
    check("Étape 2 : ancien trauma aléatoire neutralisé", "anatomy_v2_enabled" in (root / "scripts/core/dismemberment_runtime.gd").read_text(encoding="utf-8"))

    specs = anatomy.get("hero_specializations", {})
    check("Étape 3 : quatre spécialisations anatomiques", set(specs) == HEROES, str(sorted(specs)))
    check("Étape 3 : spécialisation affecte trauma", "trauma_multiplier" in anatomy_runtime and "part_hit_bonus" in anatomy_runtime)

    bosses = anatomy.get("boss_anatomies", {})
    check("Étape 4 : onze anatomies de boss uniques", set(bosses) == CORE_BOSSES, str(sorted(bosses)))
    for boss_id, boss in bosses.items():
        part_ids = [str(part.get("id", "")) for part in boss.get("parts", [])]
        check(f"{boss_id} : au moins trois parties uniques", len(part_ids) >= 3 and len(part_ids) == len(set(part_ids)), str(part_ids))
        check(f"{boss_id} : conséquences documentées", all(bool(part.get("consequence")) for part in boss.get("parts", [])))
    overrides = families.get("boss_required_part_overrides", {})
    check("Étape 4 : sept Vestiges relient leur manœuvre à une partie unique", set(overrides) == DEEP_BOSSES, str(sorted(overrides)))
    for boss_id, part_id in overrides.items():
        part_ids = {str(part.get("id", "")) for part in bosses.get(boss_id, {}).get("parts", [])}
        check(f"{boss_id} : partie familiale existe dans anatomie unique", str(part_id) in part_ids, f"{part_id} / {sorted(part_ids)}")
    check("Étape 4 : mini-boss utilisent le profil boss réel", families.get("families", {}).get("elite", {}).get("required_part") == "offensive_limb")

    check("Étape 5 : IA adaptative présente", "_apply_adaptive_enemy_states" in ui[8] and "adaptive_ai_state" in ui[8])
    check("Étape 5 : familles possèdent états blessés", {"humanoid","beast","arachnid","aberration","construct","elite","boss"} <= set(ai.get("families", {})))
    check("Étape 5 : boss exclus de la fuite", "_can_panic_flee" in ui[8] and "is_boss" in ui[8])
    check("Étape 5 : protection d'une partie restante", "protected_anatomy_part" in ui[8] and "_best_part_to_protect" in ui[8])
    check("Étape 5 : blessures persistent après recalcul IA", "func _lost_attack_multiplier" in ui[11] and "applied_injury_states" in ui[11])

    bands = psychology.get("witness_bands", [])
    check("Étape 6 : réactions Peur/Folie graduées", len(bands) >= 4 and all("fear" in band and "madness" in band for band in bands))
    check("Étape 6 : psychologie branchée au démembrement", "_apply_mutilation_psychology" in ui[9] and "last_mutilation_response" in ui[9])
    check("Étape 6 : Espoir amortit la Peur", int(psychology.get("high_hope_fear_reduction", 0)) > 0 and "high_hope_threshold" in ui[9])

    check("Étape 7 : blessures facilitent capture", int(capture.get("capture_bonus_per_lost_part", 0)) > 0 and "capture_bonus" in capture_runtime)
    check("Étape 7 : confiance pénalisée", int(capture.get("bond_penalty_per_lost_part", 0)) > 0 and 'creature["bond"]' in capture_runtime)
    check("Étape 7 : convalescence bloque combat", capture.get("disable_combat_until_care_complete") is True and "anatomy_recovery_locked" in capture_runtime and "_finish_party_round" in ui[10])
    check("Étape 7 : soins Sanctuaire prévus", "provide_sanctuary_care" in capture_runtime and "care_progress" in capture_runtime)
    check("Étape 7 : soins accessibles dans le Bestiaire", "SOINS DU SANCTUAIRE" in ui[12] and "_provide_creature_care" in ui[12])
    check("Étape 7 : Infirmerie réellement accessible", "show_infirmary" in ui[13] and 'GameState.request_screen("infirmary")' in ui[13] and "_treat_in_infirmary" in ui[13])
    check("Étape 7 : échec de capture restaure les PV avant le tour", "capture_target[\"hp\"] = original_hp" in ui[10] and "_complete_hero_action(hero)" in ui[10])

    by_tag = injuries.get("by_tag", {})
    check("Étape 8 : blessures non létales diversifiées", {"armor","mobility","sensor","venom","attack","weapon","anchor","veil","core","support"} <= set(by_tag))
    check("Étape 8 : fonctions neutralisables sans section", any(rule.get("critical_disables_part") for rule in by_tag.values()) and "critically_disabled_parts" in injury_runtime)
    check("Étape 8 : blessures branchées au combat", "InjuryRuntime.apply_if_needed" in ui[11] and "InjuryRuntime.part_functional" in ui[11])

    check("Étape 9 : schéma anatomique visible", "SCHÉMA ANATOMIQUE" in ui[12] and "_anatomy_state_label" in ui[12])
    check("Étape 9 : conséquences affichées", "SI NEUTRALISÉE" in ui[12] and "consequence" in ui[12])
    check("Étape 9 : affinité héros affichée", "AFFINITÉ ANATOMIQUE" in ui[12])
    check("Étape 9 : protection ennemie affichée", "protected" in ui[12] and "PROTÉGÉE" in ui[12])

    check("Étape 10 : contrat Blender présent", blender.get("schema_version") == 1 and bool(blender.get("required_collections")))
    check("Étape 10 : trois modes gore", set(blender.get("presentation_modes", {})) == {"full", "reduced", "off"})
    check("Étape 10 : conventions bones/sockets", blender.get("naming", {}).get("bone_prefix") == "BONE_" and blender.get("naming", {}).get("sever_socket_prefix") == "SEVER_")
    check("Étape 10 : animations de réaction", {"injury_react","dismember_react","wounded_rage","panic_flee","phase_altered"} <= set(blender.get("animation_contract", {}).get("required_generic", [])))
    check("Étape 10 : générateur Blender sans Blender", "def build_jobs" in generator and "combat_anatomy_v2.json" in generator)

    check("UI mobile v14 : cibles tactiles garanties", "MOBILE_MIN_TOUCH_HEIGHT" in ui[14] and "MOBILE_MIN_TOUCH_WIDTH" in ui[14])

    for autoload in [
        'AnatomyRuntime="*res://scripts/core/anatomy_runtime.gd"',
        'CaptureWoundRuntime="*res://scripts/core/capture_wound_runtime.gd"',
        'InjuryRuntime="*res://scripts/core/injury_runtime.gd"',
    ]:
        check(f"Autoload présent : {autoload.split('=')[0]}", autoload in project)

    return {"summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])}, "checks": checks}


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "anatomy-system-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
