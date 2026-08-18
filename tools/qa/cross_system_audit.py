#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]

CHAPTERS = [
    {"number": 1, "id": "chapter_01_ashlands", "data": "data/levels/chapter_01_vertical_slice.json", "world": None, "scene_dir": "scenes/world/terre_des_cendres", "start_fn": "start_ashlands", "autoload": "Chapter01Runtime", "runtime": "scripts/world/chapter_01_runtime.gd", "boss_runtime": "scripts/world/chapter_01_boss_runtime.gd", "save_key": "chapter_01"},
    {"number": 2, "id": "chapter_02_before_fall", "data": "data/levels/chapter_02_vertical_slice.json", "world": "data/levels/chapter_02_world.json", "scene_dir": "scenes/world/chapter_02", "start_fn": "start_chapter_02", "autoload": "Chapter02Runtime", "runtime": "scripts/world/chapter_02_runtime.gd", "boss_runtime": "scripts/world/chapter_02_boss_runtime.gd", "save_key": "chapter_02"},
    {"number": 3, "id": "chapter_03_threshold", "data": "data/levels/chapter_03_threshold.json", "world": "data/levels/chapter_03_world.json", "scene_dir": "scenes/world/chapter_03", "start_fn": "start_chapter_03", "autoload": "Chapter03Runtime", "runtime": "scripts/world/chapter_03_runtime.gd", "boss_runtime": "scripts/world/chapter_03_boss_runtime.gd", "save_key": "chapter_03"},
    {"number": 4, "id": "chapter_04_first_rupture", "data": "data/levels/chapter_04_first_rupture.json", "world": "data/levels/chapter_04_world.json", "scene_dir": "scenes/world/chapter_04", "start_fn": "start_chapter_04", "autoload": "Chapter04Runtime", "runtime": "scripts/world/chapter_04_runtime.gd", "boss_runtime": "scripts/world/chapter_04_boss_runtime.gd", "save_key": "chapter_04"},
    {"number": 5, "id": "chapter_05_great_closure", "data": "data/levels/chapter_05_great_closure.json", "world": "data/levels/chapter_05_world.json", "scene_dir": "scenes/world/chapter_05", "start_fn": "start_chapter_05", "autoload": "Chapter05Runtime", "runtime": "scripts/world/chapter_05_runtime.gd", "boss_runtime": "scripts/world/chapter_05_boss_runtime.gd", "save_key": "chapter_05"},
    {"number": 6, "id": "chapter_06_absent", "data": "data/levels/chapter_06_absent.json", "world": "data/levels/chapter_06_world.json", "scene_dir": "scenes/world/chapter_06", "start_fn": "start_chapter_06", "autoload": "Chapter06Runtime", "runtime": "scripts/world/chapter_06_runtime.gd", "boss_runtime": "scripts/world/chapter_06_boss_runtime.gd", "save_key": "chapter_06"},
    {"number": 7, "id": "chapter_07_living_responsible", "data": "data/levels/chapter_07_living_responsible.json", "world": "data/levels/chapter_07_world.json", "scene_dir": "scenes/world/chapter_07", "start_fn": "start_chapter_07", "autoload": "Chapter07Runtime", "runtime": "scripts/world/chapter_07_runtime.gd", "boss_runtime": "scripts/world/chapter_07_boss_runtime.gd", "save_key": "chapter_07"},
    {"number": 8, "id": "chapter_08_outer_world", "data": "data/levels/chapter_08_outer_world.json", "world": "data/levels/chapter_08_world.json", "scene_dir": "scenes/world/chapter_08", "start_fn": "start_chapter_08", "autoload": "Chapter08Runtime", "runtime": "scripts/world/chapter_08_runtime.gd", "boss_runtime": "scripts/world/chapter_08_boss_runtime.gd", "save_key": "chapter_08"},
    {"number": 9, "id": "chapter_09_veil_nature", "data": "data/levels/chapter_09_veil_nature.json", "world": "data/levels/chapter_09_world.json", "scene_dir": "scenes/world/chapter_09", "start_fn": "start_chapter_09", "autoload": "Chapter09Runtime", "runtime": "scripts/world/chapter_09_runtime.gd", "boss_runtime": "scripts/world/chapter_09_boss_runtime.gd", "save_key": "chapter_09"},
    {"number": 10, "id": "chapter_10_final_choice", "data": "data/levels/chapter_10_final_choice.json", "world": "data/levels/chapter_10_world.json", "scene_dir": "scenes/world/chapter_10", "start_fn": "start_chapter_10", "autoload": "Chapter10Runtime", "runtime": "scripts/world/chapter_10_runtime.gd", "boss_runtime": "scripts/world/chapter_10_boss_runtime.gd", "save_key": "chapter_10"},
]

BOSS_ALIASES = {
    "c02_boss_archive_keeper": "c02_marker_warden",
    "c04_boss_unfinished_chorus": "c04_boss_chorus",
}


def normalize_boss_id(value: str) -> str:
    return BOSS_ALIASES.get(value, value)


def load_json(root: Path, relative: str) -> dict[str, Any]:
    return json.loads((root / relative).read_text(encoding="utf-8"))


def unique(values: list[str]) -> bool:
    return len(values) == len(set(values))


class Audit:
    def __init__(self) -> None:
        self.checks: list[dict[str, Any]] = []

    def check(self, name: str, ok: bool, detail: str = "", severity: str = "error") -> None:
        self.checks.append({"name": name, "ok": bool(ok), "detail": detail, "severity": severity})

    def warn(self, name: str, ok: bool, detail: str = "") -> None:
        self.check(name, ok, detail, "warning")

    @property
    def errors(self) -> list[dict[str, Any]]:
        return [c for c in self.checks if not c["ok"] and c["severity"] == "error"]

    @property
    def warnings(self) -> list[dict[str, Any]]:
        return [c for c in self.checks if not c["ok"] and c["severity"] == "warning"]


def audit_campaign(root: Path, a: Audit) -> None:
    campaign = load_json(root, "data/world/main_campaign.json")
    chapters = campaign.get("chapters", [])
    ids = [str(c.get("id", "")) for c in chapters]
    numbers = [int(c.get("number", -1)) for c in chapters]
    a.check("Campagne : 10 chapitres", len(chapters) == 10, f"trouvés={len(chapters)}")
    a.check("Campagne : numérotation 1→10", numbers == list(range(1, 11)), str(numbers))
    a.check("Campagne : IDs uniques", unique(ids), str(ids))
    a.check("Campagne : ordre canonique", ids == [c["id"] for c in CHAPTERS], str(ids))
    for index in range(min(9, len(chapters) - 1)):
        expected = str(chapters[index + 1].get("id", ""))
        actual = str(chapters[index].get("unlock", ""))
        a.check(f"Campagne : transition chapitre {index + 1}→{index + 2}", actual == expected, f"{actual} != {expected}")
    if len(chapters) >= 10:
        a.check("Campagne : chapitre X ouvre les fins", str(chapters[9].get("unlock", "")) == "endings", str(chapters[9].get("unlock", "")))

    quest_ids: list[str] = []
    for chapter in chapters:
        quest_ids.extend(str(q.get("id", "")) for q in chapter.get("main_quests", []))
    a.check("Campagne : IDs de quêtes uniques", unique(quest_ids), "doublons détectés" if not unique(quest_ids) else f"total={len(quest_ids)}")


def audit_chapters(root: Path, a: Audit) -> None:
    project = (root / "project.godot").read_text(encoding="utf-8")
    router = (root / "scripts/world/ashlands_scene_router.gd").read_text(encoding="utf-8")
    save = (root / "scripts/core/save_manager.gd").read_text(encoding="utf-8")

    for spec in CHAPTERS:
        number = spec["number"]
        data_path = root / str(spec["data"])
        a.check(f"Chapitre {number} : données présentes", data_path.is_file(), str(spec["data"]))
        a.check(f"Chapitre {number} : runtime présent", (root / str(spec["runtime"])).is_file(), str(spec["runtime"]))
        a.check(f"Chapitre {number} : boss runtime présent", (root / str(spec["boss_runtime"])).is_file(), str(spec["boss_runtime"]))
        a.check(f"Chapitre {number} : autoload présent", f'{spec["autoload"]}="*res://{spec["runtime"]}"' in project, str(spec["autoload"]))
        a.check(f"Chapitre {number} : route de départ présente", f"func {spec['start_fn']}(" in router, str(spec["start_fn"]))
        a.check(f"Chapitre {number} : sauvegarde serialize", f'"{spec["save_key"]}": {spec["autoload"]}.serialize()' in save, str(spec["save_key"]))
        a.check(f"Chapitre {number} : sauvegarde deserialize", f'{spec["autoload"]}.deserialize(payload.get("{spec["save_key"]}",{{}}))' in save, str(spec["save_key"]))

        if not data_path.is_file():
            continue
        chapter_data = load_json(root, str(spec["data"]))
        a.check(f"Chapitre {number} : chapter_id cohérent", str(chapter_data.get("chapter_id", "")) == spec["id"], str(chapter_data.get("chapter_id", "")))

        world_rel = spec.get("world")
        if not world_rel:
            continue
        world_path = root / str(world_rel)
        a.check(f"Chapitre {number} : monde présent", world_path.is_file(), str(world_rel))
        if not world_path.is_file():
            continue
        world = load_json(root, str(world_rel))
        zones = world.get("zones", [])
        zone_ids = [str(z.get("id", "")) for z in zones]
        a.check(f"Chapitre {number} : zones uniques", unique(zone_ids), str(zone_ids))
        a.check(f"Chapitre {number} : au moins une zone", bool(zone_ids), "aucune zone")

        start_zone = str(chapter_data.get("start_zone", ""))
        if start_zone:
            a.check(f"Chapitre {number} : start_zone existe", start_zone in zone_ids, start_zone)

        missing_scenes = [z for z in zone_ids if not (root / str(spec["scene_dir"]) / f"{z}.tscn").is_file()]
        a.check(f"Chapitre {number} : scènes de zones présentes", not missing_scenes, ", ".join(missing_scenes[:12]))

        missing_routes = [z for z in zone_ids if f'"{z}"' not in router]
        a.check(f"Chapitre {number} : zones routées", not missing_routes, ", ".join(missing_routes[:12]))

        stage_zones = [str(stage.get("zone", "")) for stage in chapter_data.get("stages", []) if stage.get("zone")]
        invalid_stage_zones = [z for z in stage_zones if z != "sanctuary" and z not in zone_ids]
        a.check(f"Chapitre {number} : zones d'étapes valides", not invalid_stage_zones, ", ".join(invalid_stage_zones))


def audit_boss_contracts(root: Path, a: Audit) -> set[str]:
    data = load_json(root, "data/boss_design_contracts.json")
    bosses = data.get("bosses", [])
    ids = [str(b.get("id", "")) for b in bosses]
    a.check("Boss : IDs de contrats uniques", unique(ids), "doublons détectés")
    tier_rules = data.get("tiers", {})
    for boss in bosses:
        boss_id = str(boss.get("id", ""))
        tier = str(boss.get("tier", ""))
        mechanics = boss.get("mechanics", [])
        rule = tier_rules.get(tier, {})
        minimum = int(rule.get("mechanics_min", 0))
        maximum = int(rule.get("mechanics_max", 999))
        a.check(f"Boss {boss_id} : mécanique conforme", minimum <= len(mechanics) <= maximum, f"tier={tier}, mechanics={len(mechanics)}, attendu={minimum}-{maximum}")
        a.check(f"Boss {boss_id} : signature", bool(str(boss.get("signature", "")).strip()), "signature vide")
        a.check(f"Boss {boss_id} : contre-jeu", bool(str(boss.get("counterplay", "")).strip()), "counterplay vide")
        a.check(f"Boss {boss_id} : puzzle central", bool(str(boss.get("core_puzzle", "")).strip()), "core_puzzle vide")

    campaign = load_json(root, "data/world/main_campaign.json")
    contract_ids = {normalize_boss_id(v) for v in ids}
    campaign_boss_ids = {normalize_boss_id(str(b.get("id", ""))) for ch in campaign.get("chapters", []) for b in ch.get("bosses", [])}
    missing = sorted(campaign_boss_ids - contract_ids)
    a.check("Boss : tous les boss de campagne ont un contrat", not missing, ", ".join(missing))
    return contract_ids


def audit_vestiges(root: Path, a: Audit, contract_ids: set[str]) -> set[str]:
    index = load_json(root, "data/world/deep_vestiges.json")
    vestiges = index.get("vestiges", [])
    ids = [str(v.get("id", "")) for v in vestiges]
    civs = [str(v.get("civilization", "")) for v in vestiges]
    a.check("Vestiges : au moins 7 civilisations anciennes", len(vestiges) >= 7, f"trouvés={len(vestiges)}")
    a.check("Vestiges : IDs uniques", unique(ids), str(ids))
    a.check("Vestiges : civilisations uniques", unique(civs), str(civs))

    all_zone_ids: list[str] = []
    boss_ids: set[str] = set()
    for entry in vestiges:
        vestige_id = str(entry.get("id", ""))
        raw_path = str(entry.get("data_path", ""))
        relative = raw_path.removeprefix("res://")
        path = root / relative
        a.check(f"Vestige {vestige_id} : fichier présent", path.is_file(), relative)
        if not path.is_file():
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        zones = data.get("zones", [])
        zone_ids = [str(z.get("id", "")) for z in zones]
        all_zone_ids.extend(zone_ids)
        a.check(f"Vestige {vestige_id} : donjon complet", len(zone_ids) >= 6, f"zones={len(zone_ids)}")
        a.check(f"Vestige {vestige_id} : zones uniques", unique(zone_ids), str(zone_ids))
        a.check(f"Vestige {vestige_id} : fragments de lore", len(data.get("fragments", [])) >= 6, f"fragments={len(data.get('fragments', []))}")
        text = path.read_text(encoding="utf-8")
        a.check(f"Vestige {vestige_id} : Vérité Profonde", "deep_truth" in text, "champ deep_truth absent")
        boss_id = str(entry.get("boss", ""))
        if boss_id:
            boss_ids.add(normalize_boss_id(boss_id))
            a.check(f"Vestige {vestige_id} : boss sous contrat", normalize_boss_id(boss_id) in contract_ids, boss_id)

    a.check("Vestiges : IDs de zones uniques globalement", unique(all_zone_ids), "collision d'ID entre donjons")
    return boss_ids


def audit_save_and_autoloads(root: Path, a: Audit) -> None:
    project = (root / "project.godot").read_text(encoding="utf-8")
    save = (root / "scripts/core/save_manager.gd").read_text(encoding="utf-8")
    match = re.search(r'const SAVE_VERSION := "([^"]+)"', save)
    a.check("Sauvegarde : version déclarée", match is not None, "SAVE_VERSION introuvable")
    if match:
        a.check("Sauvegarde : version actuelle ≥ 0.31", tuple(map(int, match.group(1).split("."))) >= (0, 31), match.group(1))

    expected_autoloads = {
        "BossRecruitmentState": "scripts/core/ngplus_boss_recruitment.gd",
        "DeepVestigeRuntime": "scripts/world/deep_vestige_runtime.gd",
        "EndgameState": "scripts/core/endgame_state.gd",
        "SaveManager": "scripts/core/save_manager.gd",
        "AshlandsSceneRouter": "scripts/world/ashlands_scene_router.gd",
        "AshlandsCombatBridge": "scripts/world/ashlands_combat_bridge.gd",
    }
    for name, path in expected_autoloads.items():
        a.check(f"Autoload : {name}", f'{name}="*res://{path}"' in project, path)

    for key in ["campaign", "creatures", "deep_vestiges", "endgame"]:
        a.check(f"Sauvegarde : bloc {key}", f'"{key}"' in save and f'payload.get("{key}"' in save, key)


def audit_ngplus(root: Path, a: Audit, contract_ids: set[str]) -> None:
    registry = load_json(root, "data/world/ngplus_boss_recruits.json")
    recruits = registry.get("recruits", [])
    ids = [str(r.get("id", "")) for r in recruits]
    encounters = [str(r.get("encounter_id", "")) for r in recruits]
    a.check("NG+ boss : au moins 34 recrutements", len(recruits) >= 34, f"trouvés={len(recruits)}")
    a.check("NG+ boss : IDs uniques", unique(ids), "doublons d'ID")
    a.check("NG+ boss : encounter_id uniques", unique(encounters), "doublons de rencontre")
    a.check("NG+ boss : déblocage au Premier retour", int(registry.get("unlock_cycle_min", 999)) == 1, str(registry.get("unlock_cycle_min")))
    a.check("NG+ boss : synchronisation niveau moyen", str(registry.get("level_sync", "")) == "party_average", str(registry.get("level_sync", "")))

    capture_rules = registry.get("capture_rules", {})
    for rank in ["miniboss", "boss", "deep_miniboss", "deep_boss"]:
        a.check(f"NG+ boss : règle de capture {rank}", rank in capture_rules, rank)

    normalized_recruits = {normalize_boss_id(v) for v in encounters}
    missing_contract_recruits = sorted(contract_ids - normalized_recruits)
    a.check("NG+ boss : tous les contrats de boss sont recrutables", not missing_contract_recruits, ", ".join(missing_contract_recruits))

    unmatched_recruits = sorted(normalized_recruits - contract_ids)
    a.warn("NG+ boss : recrutements sans contrat global", not unmatched_recruits, ", ".join(unmatched_recruits))

    boss_script = (root / "scripts/core/ngplus_boss_recruitment.gd").read_text(encoding="utf-8")
    hero_script = (root / "scripts/core/hero_skill_manager.gd").read_text(encoding="utf-8")
    creature_script = (root / "scripts/core/creature_manager.gd").read_text(encoding="utf-8")
    endgame = (root / "scripts/core/endgame_state.gd").read_text(encoding="utf-8")
    a.check("NG+ boss : niveau moyen implémenté", "func party_reference_level()" in boss_script and 'result["level_sync"] = true' in boss_script, "ngplus_boss_recruitment.gd")
    a.check("NG+ compétences : héros trois arbres", "func multi_tree_enabled()" in hero_script and "EndgameState.active_cycle >= 1" in hero_script, "hero_skill_manager.gd")
    a.check("NG+ compétences : compagnons trois arbres", "func multi_tree_enabled()" in creature_script and "EndgameState.active_cycle >= 1" in creature_script, "creature_manager.gd")
    a.check("NG+ difficulté : scaling ennemi", all(token in endgame for token in ["enemy_hp_multiplier", "enemy_damage_multiplier", "enemy_fear_multiplier", "apply_enemy_scaling"]), "endgame_state.gd")


def audit_ci(root: Path, a: Audit) -> None:
    ci = (root / ".github/workflows/ci.yml").read_text(encoding="utf-8")
    a.check("CI : pytest", "python -m pytest" in ci, "commande absente")
    a.check("CI : audit de base", "python -m tools.qa.audit" in ci, "commande absente")
    a.check("CI : audit transversal", "python -m tools.qa.cross_system_audit" in ci, "commande absente")
    a.check("CI : smoke Godot headless", "godot --headless" in ci and "smoke_test.gd" in ci, "smoke test absent")
    a.check("CI : rapports uploadés", "actions/upload-artifact" in ci and "reports/" in ci, "artifact QA absent")


def run(root: Path = ROOT) -> Audit:
    a = Audit()
    audit_campaign(root, a)
    audit_chapters(root, a)
    contract_ids = audit_boss_contracts(root, a)
    audit_vestiges(root, a, contract_ids)
    audit_save_and_autoloads(root, a)
    audit_ngplus(root, a, contract_ids)
    audit_ci(root, a)
    return a


def write_report(a: Audit, outdir: Path) -> None:
    outdir.mkdir(parents=True, exist_ok=True)
    payload = {
        "summary": {
            "passed": sum(1 for c in a.checks if c["ok"]),
            "errors": len(a.errors),
            "warnings": len(a.warnings),
            "total": len(a.checks),
        },
        "checks": a.checks,
    }
    (outdir / "cross-system-report.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--out", type=Path, default=ROOT / "reports")
    args = parser.parse_args()
    audit = run(args.root)
    write_report(audit, args.out)
    for check in audit.checks:
        if check["ok"]:
            status = "PASS"
        elif check["severity"] == "warning":
            status = "WARN"
        else:
            status = "FAIL"
        print(f"{status} - {check['name']} {check['detail']}")
    print(f"RESULT: {len(audit.errors)} errors, {len(audit.warnings)} warnings, {len(audit.checks)} checks")
    return 1 if audit.errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
