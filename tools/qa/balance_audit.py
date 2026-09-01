#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]


def load_json(root: Path, relative: str) -> Any:
    return json.loads((root / relative).read_text(encoding="utf-8"))


def parse_int_array(text: str, name: str) -> list[int]:
    match = re.search(rf"const\s+{re.escape(name)}[^=]*=\s*\[([^\]]*)\]", text)
    if not match:
        return []
    return [int(value) for value in re.findall(r"-?\d+", match.group(1))]


def normalize_boss_id(encounter_id: str) -> str:
    return encounter_id


class BalanceAudit:
    def __init__(self) -> None:
        self.checks: list[dict[str, Any]] = []
        self.warnings: list[dict[str, Any]] = []
        self.info: dict[str, Any] = {}

    def check(self, name: str, ok: bool, detail: str = "") -> None:
        self.checks.append({"name": name, "ok": bool(ok), "detail": detail})

    def warn(self, name: str, triggered: bool, detail: str = "") -> None:
        if triggered:
            self.warnings.append({"name": name, "detail": detail})

    @property
    def errors(self) -> list[dict[str, Any]]:
        return [item for item in self.checks if not item["ok"]]


def audit_hero_progression(root: Path, audit: BalanceAudit) -> None:
    source = (root / "scripts/core/hero_skill_manager.gd").read_text(encoding="utf-8")
    levels = parse_int_array(source, "LEVELS")
    costs = parse_int_array(source, "COSTS")
    audit.check("Héros : quinze paliers par arbre", len(levels) == 15 and len(costs) == 15, f"levels={len(levels)}, costs={len(costs)}")
    audit.check("Héros : dernier palier avant ou au niveau 50", bool(levels) and max(levels) <= 50, str(levels))
    # Un héros prototype démarre niveau 3 avec un point puis gagne un point par niveau.
    available_points = 1 + (50 - 3)
    audit.check("Héros : un arbre complet est finissable au niveau 50", bool(costs) and sum(costs) <= available_points, f"coût={sum(costs)}, points={available_points}")
    audit.check("Héros : exclusivité des arbres permanente", "func multi_tree_enabled() -> bool:" in source and "return false" in source and 'specialization != "" and specialization != branch' in source)


def audit_companion_progression(root: Path, audit: BalanceAudit) -> None:
    source = (root / "scripts/core/creature_manager.gd").read_text(encoding="utf-8")
    advanced_levels = parse_int_array(source, "ADVANCED_SKILL_LEVELS")
    audit.check("Compagnons : sept paliers d'ascension", len(advanced_levels) == 7, str(advanced_levels))
    audit.check("Compagnons : ascension jusqu'au niveau 49", bool(advanced_levels) and advanced_levels[-1] == 49, str(advanced_levels))
    audit.check("Compagnons : l'ascension s'ancre avant son premier palier", "previous_id" in source and "first_advanced_level" in source)
    audit.check("Compagnons : exclusivité des arbres permanente", "func multi_tree_enabled() -> bool:" in source and "return false" in source and 'specialization != "" and specialization != skill_branch' in source)


def audit_endings(root: Path, audit: BalanceAudit) -> None:
    data = load_json(root, "data/world/endgame_epilogues.json")
    epilogues = data.get("epilogues", [])
    ids = {str(item.get("ending_id", "")) for item in epilogues}
    canonical_core = {"radical_closure", "stable_coexistence", "preserve_crossings", "seek_absent", "restore_concord"}
    audit.check("Fins : six orientations canoniques", len(epilogues) >= 6 and canonical_core <= ids, f"epilogues={len(epilogues)}")
    audit.check("Fins : identifiants uniques", len(ids) == len(epilogues), f"ids={len(ids)}, epilogues={len(epilogues)}")


def audit_postgame_and_ngplus(root: Path, audit: BalanceAudit) -> None:
    ngplus = load_json(root, "data/world/new_game_plus.json")
    perks = ngplus.get("perks", [])
    audit.check("Postgame : NG+ impossible à soft-lock économiquement", ngplus.get("unlock", {}).get("runtime_gate") == "campaign_complete_only" and ngplus.get("unlock", {}).get("postgame_operations_gate_enforced") is False)
    audit.check("NG+ : un seul héritage actif", int(ngplus.get("max_legacy_perks", 0)) == 1, str(ngplus.get("max_legacy_perks")))
    audit.check("NG+ : héritages optionnels présents", len(perks) >= 4, f"héritages={len(perks)}")
    difficulty = ngplus.get("difficulty_per_cycle", {})
    hp_pct = int(difficulty.get("enemy_hp_pct", 0))
    damage_pct = int(difficulty.get("enemy_damage_pct", 0))
    fear_pct = int(difficulty.get("enemy_fear_pct", 0))
    audit.check("NG+ : scaling par cycle strictement positif", 0 < hp_pct <= 50 and 0 < damage_pct <= 50 and 0 < fear_pct <= 50, str(difficulty))
    skill_rules = ngplus.get("skill_tree_rules", {})
    audit.check("NG+ : ne déverrouille jamais les autres arbres", skill_rules.get("multitree_enabled") is False and skill_rules.get("tree_choice_exclusive_in_all_cycles") is True)


def audit_boss_contracts_and_capture(root: Path, audit: BalanceAudit) -> None:
    recruits_data = load_json(root, "data/world/ngplus_boss_recruits.json")
    ngplus = load_json(root, "data/world/new_game_plus.json")
    contracts = load_json(root, "data/boss_design_contracts.json")
    runtime = (root / "scripts/core/ngplus_boss_recruitment.gd").read_text(encoding="utf-8")
    creature_runtime = (root / "scripts/core/creature_manager.gd").read_text(encoding="utf-8")

    bosses = contracts.get("bosses", [])
    ids = [str(item.get("id", "")) for item in bosses]
    audit.check("Boss : contrats de conception présents", len(bosses) >= 30, f"contrats={len(bosses)}")
    audit.check("Boss : contrats uniques", len(ids) == len(set(ids)), f"contrats={len(ids)}")

    boss_rule = ngplus.get("boss_recruitment", {})
    disabled_data = recruits_data.get("status") == "disabled_by_canon_audit" and recruits_data.get("recruits", []) == [] and recruits_data.get("capture_rules", {}) == {}
    disabled_rule = boss_rule.get("enabled") is False
    disabled_runtime = "func enabled() -> bool:" in runtime and "return false" in runtime
    creature_gate = "Les mini-boss et boss ne sont pas capturables." in creature_runtime

    audit.check("NG+ boss : recrutement générique désactivé par canon", disabled_data and disabled_rule and disabled_runtime and creature_gate)
    audit.check("NG+ boss : aucun catalogue actif ne remplace les contrats de boss", recruits_data.get("recruits", []) == [] and len(bosses) >= 30)
    audit.check("NG+ boss : personnes et justice restent hors capture", "personhood_rule" in boss_rule and "arrestation" in str(boss_rule.get("personhood_rule", "")).lower() and "procès" in str(boss_rule.get("personhood_rule", "")).lower())

    hard_exclusions = " ".join(str(value) for value in boss_rule.get("hard_exclusions", [])).lower()
    audit.check("NG+ boss : Ange et sujets humains explicitement exclus", "ange" in hard_exclusions and ("human" in hard_exclusions or "personhood" in hard_exclusions))


def audit_capture_roster(root: Path, audit: BalanceAudit) -> None:
    creatures = load_json(root, "data/capturable_creatures.json")
    enemy_ids = [int(item.get("enemy_id", -1)) for item in creatures]
    audit.check("Capture : roster ordinaire explicite et unique", len(enemy_ids) == len(set(enemy_ids)) and all(value >= 0 for value in enemy_ids), str(enemy_ids))
    audit.check("Capture : trois familles prototype restent disponibles", set(enemy_ids) == {1, 8, 10}, str(enemy_ids))


def run(root: Path = ROOT) -> BalanceAudit:
    audit = BalanceAudit()
    audit_hero_progression(root, audit)
    audit_companion_progression(root, audit)
    audit_endings(root, audit)
    audit_postgame_and_ngplus(root, audit)
    audit_boss_contracts_and_capture(root, audit)
    audit_capture_roster(root, audit)
    audit.info["canon"] = {
        "tree_exclusivity_all_cycles": True,
        "generic_boss_recruitment": False,
        "boss_contracts_preserved": True,
    }
    return audit


def write_report(root: Path, audit: BalanceAudit) -> Path:
    out = root / "reports" / "balance-audit-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "summary": {"checks": len(audit.checks), "errors": len(audit.errors), "warnings": len(audit.warnings)},
        "checks": audit.checks,
        "warnings": audit.warnings,
        "info": audit.info,
    }
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return out


def main() -> int:
    audit = run(ROOT)
    path = write_report(ROOT, audit)
    for check in audit.checks:
        print(("PASS" if check["ok"] else "FAIL"), "-", check["name"], check["detail"])
    for warning in audit.warnings:
        print("WARN -", warning["name"], warning["detail"])
    print(f"RESULT: {len(audit.errors)} error(s), {len(audit.warnings)} warning(s) — {path}")
    return 1 if audit.errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
