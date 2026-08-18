#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
BRANCHES = ("offense", "defense", "special")
EXPECTED_ENDINGS = {
    "radical_closure",
    "stable_coexistence",
    "preserve_crossings",
    "seek_absent",
    "restore_concord",
    "transform_concord",
}
SUPPORTED_ENDING_REQUIREMENTS = {
    "trust_min": "trust",
    "body_min": "body",
    "spirit_min": "spirit",
    "city_min": "city",
    "creature_relations_min": "creature_relations",
    "absent_contact_min": "absent_contact",
    "foreign_alliances_min": "foreign_alliances",
    "justice_integrity_min": "justice_integrity",
    "veil_knowledge_min": "veil_knowledge",
    "stabilizer_nodes_min": "stabilizer_nodes",
}
CAMPAIGN_METRICS = {
    "creature_relations",
    "absent_contact",
    "foreign_alliances",
    "justice_integrity",
    "veil_knowledge",
    "stabilizer_nodes",
}
BOSS_ALIASES = {
    "c04_boss_unfinished_chorus": "c04_boss_chorus",
}


def load_json(root: Path, relative: str) -> Any:
    return json.loads((root / relative).read_text(encoding="utf-8"))


def parse_int_array(text: str, name: str) -> list[int]:
    match = re.search(rf"const\s+{re.escape(name)}[^=]*=\s*\[([^\]]*)\]", text)
    if not match:
        return []
    return [int(value) for value in re.findall(r"-?\d+", match.group(1))]


def parse_scalar_int(text: str, name: str, default: int = 0) -> int:
    match = re.search(rf"(?:const|var)\s+{re.escape(name)}[^=]*:=\s*(-?\d+)", text)
    return int(match.group(1)) if match else default


def normalize_boss_id(value: str) -> str:
    return BOSS_ALIASES.get(value, value)


class BalanceAudit:
    def __init__(self) -> None:
        self.checks: list[dict[str, Any]] = []
        self.info: dict[str, Any] = {}

    def check(self, name: str, ok: bool, detail: str = "", severity: str = "error") -> None:
        self.checks.append({"name": name, "ok": bool(ok), "detail": detail, "severity": severity})

    def warn(self, name: str, ok: bool, detail: str = "") -> None:
        self.check(name, ok, detail, "warning")

    @property
    def errors(self) -> list[dict[str, Any]]:
        return [item for item in self.checks if not item["ok"] and item["severity"] == "error"]

    @property
    def warnings(self) -> list[dict[str, Any]]:
        return [item for item in self.checks if not item["ok"] and item["severity"] == "warning"]


def audit_hero_progression(root: Path, audit: BalanceAudit) -> None:
    source = (root / "scripts/core/hero_skill_manager.gd").read_text(encoding="utf-8")
    levels = parse_int_array(source, "LEVELS")
    costs = parse_int_array(source, "COSTS")
    audit.check("Héros : 15 paliers de compétences", len(levels) == len(costs) == 15, f"levels={len(levels)} costs={len(costs)}")
    audit.check("Héros : niveaux strictement croissants", levels == sorted(levels) and len(levels) == len(set(levels)), str(levels))
    audit.check("Héros : dernier palier avant niveau 50", bool(levels) and levels[-1] <= 50, str(levels[-1:] or []))
    audit.check("Héros : coûts positifs", bool(costs) and all(cost > 0 for cost in costs), str(costs))

    cumulative = 0
    unreachable: list[str] = []
    for level, cost in zip(levels, costs):
        cumulative += cost
        # Un héros préparé commence avec 1 point et gagne 1 point à chaque niveau :
        # à un niveau N, un build dédié peut disposer au maximum de N points.
        if cumulative > level:
            unreachable.append(f"niv{level}: coût cumulé {cumulative}")
    audit.check("Héros : chaque palier est atteignable au niveau affiché", not unreachable, "; ".join(unreachable))
    if costs:
        branch_cost = sum(costs)
        audit.check("Héros : un arbre complet est finissable au niveau 50", branch_cost <= 50, f"coût={branch_cost}/50")
        audit.info["hero_skill_points"] = {"max_level": 50, "points_at_50": 50, "one_tree_cost": branch_cost, "three_tree_cost": branch_cost * 3}
        audit.warn(
            "NG+ : les trois arbres sont ouverts mais ne sont pas tous maximisables simultanément",
            branch_cost * 3 <= 50,
            f"coût trois arbres={branch_cost * 3}, points disponibles=50 ; l'ouverture NG+ permet l'hybridation, pas trois arbres gratuits",
        )
    audit.check("Héros : ouverture multi-arbres dès NG+1", "return EndgameState.active_cycle >= 1" in source)


def _validate_base_tree(species_id: str, branch: str, nodes: list[dict[str, Any]], audit: BalanceAudit) -> None:
    ids = [str(node.get("id", "")) for node in nodes]
    audit.check(f"Créature {species_id}/{branch} : IDs présents", bool(nodes) and all(ids))
    audit.check(f"Créature {species_id}/{branch} : IDs uniques", len(ids) == len(set(ids)), str(ids))
    known_levels: dict[str, int] = {}
    cumulative = 0
    unreachable: list[str] = []
    bad_prereq: list[str] = []
    for node in nodes:
        node_id = str(node.get("id", ""))
        level = int(node.get("required_level", 1))
        cost = int(node.get("cost", 0))
        prerequisite = str(node.get("requires", ""))
        cumulative += cost
        if cost <= 0 or level < 1 or level > 50:
            unreachable.append(f"{node_id}: level={level} cost={cost}")
        if cumulative > level:
            unreachable.append(f"{node_id}: coût cumulé {cumulative}>{level}")
        if prerequisite:
            if prerequisite not in known_levels:
                bad_prereq.append(f"{node_id}->{prerequisite} absent/placé après")
            elif known_levels[prerequisite] > level:
                bad_prereq.append(f"{node_id} niv{level} dépend de {prerequisite} niv{known_levels[prerequisite]}")
        known_levels[node_id] = level
    audit.check(f"Créature {species_id}/{branch} : progression de base atteignable", not unreachable, "; ".join(unreachable))
    audit.check(f"Créature {species_id}/{branch} : prérequis temporels valides", not bad_prereq, "; ".join(bad_prereq))


def audit_creature_progression(root: Path, audit: BalanceAudit) -> None:
    creatures = load_json(root, "data/capturable_creatures.json")
    manager = (root / "scripts/core/creature_manager.gd").read_text(encoding="utf-8")
    advanced_levels = parse_int_array(manager, "ADVANCED_SKILL_LEVELS")
    advanced_costs = parse_int_array(manager, "ADVANCED_SKILL_COSTS")
    audit.check("Compagnons : paliers d'ascension alignés", len(advanced_levels) == len(advanced_costs) == 7, f"levels={advanced_levels} costs={advanced_costs}")
    audit.check("Compagnons : niveaux d'ascension ordonnés", advanced_levels == sorted(advanced_levels) and len(advanced_levels) == len(set(advanced_levels)), str(advanced_levels))
    audit.check("Compagnons : ascension bornée au niveau 50", bool(advanced_levels) and advanced_levels[-1] <= 50, str(advanced_levels[-1:] or []))
    audit.check(
        "Compagnons : l'ascension s'ancre avant son premier palier",
        "first_advanced_level" in manager and "node_level < first_advanced_level" in manager,
        "Le premier nœud d'ascension doit dépendre du dernier nœud de base antérieur, pas du dernier nœud de l'arbre.",
    )
    audit.check("Compagnons : ouverture multi-arbres dès NG+1", "return EndgameState.active_cycle >= 1" in manager)

    all_ids: list[str] = []
    for definition in creatures:
        species_id = str(definition.get("id", ""))
        trees = definition.get("skill_trees", {})
        audit.check(f"Créature {species_id} : trois arbres", set(trees.keys()) == set(BRANCHES), str(sorted(trees.keys())))
        for branch in BRANCHES:
            nodes = list(trees.get(branch, []))
            _validate_base_tree(species_id, branch, nodes, audit)
            all_ids.extend(str(node.get("id", "")) for node in nodes)
            if nodes and advanced_levels and advanced_costs:
                anchor_nodes = [node for node in nodes if int(node.get("required_level", 1)) < advanced_levels[0]]
                audit.check(f"Créature {species_id}/{branch} : ancre d'ascension disponible", bool(anchor_nodes), f"premier palier={advanced_levels[0]}")
                if anchor_nodes:
                    anchor = max(anchor_nodes, key=lambda node: int(node.get("required_level", 1)))
                    anchor_index = nodes.index(anchor)
                    cumulative = sum(int(node.get("cost", 0)) for node in nodes[: anchor_index + 1])
                    impossible: list[str] = []
                    for level, cost in zip(advanced_levels, advanced_costs):
                        cumulative += cost
                        if cumulative > level:
                            impossible.append(f"niv{level}: coût cumulé {cumulative}")
                    audit.check(f"Créature {species_id}/{branch} : chaîne d'ascension finançable", not impossible, "; ".join(impossible))
    audit.check("Créatures : IDs de compétences globalement uniques", len(all_ids) == len(set(all_ids)), f"total={len(all_ids)} uniques={len(set(all_ids))}")


def audit_endings(root: Path, audit: BalanceAudit) -> None:
    ending_data = load_json(root, "data/world/main_campaign_endings.json")
    endings = ending_data.get("endings", [])
    ending_ids = {str(value.get("id", "")) for value in endings}
    audit.check("Fins : six orientations canoniques", ending_ids == EXPECTED_ENDINGS, str(sorted(ending_ids)))
    audit.check("Fins : trois états d'échec", len(ending_data.get("failure_states", [])) == 3, f"trouvés={len(ending_data.get('failure_states', []))}")

    unknown: list[str] = []
    invalid: list[str] = []
    for ending in endings:
        ending_id = str(ending.get("id", ""))
        requirements = ending.get("requirements", {})
        for key, value in requirements.items():
            if key not in SUPPORTED_ENDING_REQUIREMENTS:
                unknown.append(f"{ending_id}:{key}")
                continue
            threshold = int(value)
            if threshold < 0 or threshold > 100:
                invalid.append(f"{ending_id}:{key}={threshold}")
        # Toutes les conditions sont des minima indépendants : un contexte à 100 partout
        # doit donc pouvoir satisfaire chaque fin. Cela détecte les clés orphelines ou contradictoires.
        satisfiable = all(int(value) <= 100 for key, value in requirements.items() if key in SUPPORTED_ENDING_REQUIREMENTS)
        audit.check(f"Fin {ending_id} : contrat de seuil satisfiable", satisfiable, str(requirements))
    audit.check("Fins : aucune clé de condition inconnue", not unknown, "; ".join(unknown))
    audit.check("Fins : seuils dans l'échelle 0–100", not invalid, "; ".join(invalid))

    # Estimation conservatrice : on additionne uniquement les add_metric littéraux positifs
    # des scripts de campagne, plus les +4 de connaissance accordés par quête principale.
    observed: dict[str, int] = {
        "creature_relations": 0,
        "absent_contact": 0,
        "foreign_alliances": 0,
        "justice_integrity": 50,
        "veil_knowledge": 0,
        "stabilizer_nodes": 0,
    }
    add_metric_pattern = re.compile(r'CampaignState\.add_metric\(\s*["\']([^"\']+)["\']\s*,\s*([+-]?\d+)\s*\)')
    for path in (root / "scripts/world").glob("chapter_*_runtime.gd"):
        text = path.read_text(encoding="utf-8")
        for metric, raw_amount in add_metric_pattern.findall(text):
            amount = int(raw_amount)
            if metric in observed and amount > 0:
                observed[metric] += amount
    campaign = load_json(root, "data/world/main_campaign.json")
    quest_count = sum(len(chapter.get("main_quests", [])) for chapter in campaign.get("chapters", []))
    observed["veil_knowledge"] = min(100, observed["veil_knowledge"] + quest_count * 4)
    audit.info["observed_campaign_metric_upper_bound"] = observed

    warnings: list[str] = []
    for ending in endings:
        ending_id = str(ending.get("id", ""))
        for req_key, value in ending.get("requirements", {}).items():
            metric = SUPPORTED_ENDING_REQUIREMENTS.get(req_key, "")
            if metric not in CAMPAIGN_METRICS:
                continue
            threshold = int(value)
            if observed.get(metric, 0) < threshold:
                warnings.append(f"{ending_id}:{metric} seuil {threshold} > gains littéraux observés {observed.get(metric, 0)}")
    audit.warn(
        "Fins : les seuils relationnels ne dépassent pas les gains littéraux observés",
        not warnings,
        "; ".join(warnings) + (" ; à vérifier si ces métriques sont alimentées indirectement par des données/choix" if warnings else ""),
    )


def audit_postgame_economy(root: Path, audit: BalanceAudit) -> None:
    postgame = load_json(root, "data/world/postgame_operations.json")
    ngplus = load_json(root, "data/world/new_game_plus.json")
    operations = postgame.get("operations", [])
    required = int(postgame.get("operations_required_for_ng_plus", 0))
    audit.check("Postgame : nombre d'opérations NG+ positif", required > 0, str(required))
    audit.check("Postgame/NG+ : même seuil de déblocage", int(ngplus.get("unlock", {}).get("postgame_operations_min", -1)) == required, f"postgame={required} ng+={ngplus.get('unlock', {})}")

    free_unconditional: list[dict[str, Any]] = []
    invalid_costs: list[str] = []
    for operation in operations:
        operation_id = str(operation.get("id", ""))
        cost = operation.get("cost", {})
        if any(int(value) < 0 for value in cost.values()):
            invalid_costs.append(operation_id)
        if not operation.get("requirements") and all(int(value) <= 0 for value in cost.values()):
            free_unconditional.append(operation)
    audit.check("Postgame : aucun coût négatif", not invalid_costs, str(invalid_costs))
    audit.check("Postgame : NG+ impossible à soft-lock économiquement", len(free_unconditional) >= required, f"gratuites sans condition={len(free_unconditional)}, requises={required}")

    free_legacy = sum(int(op.get("reward", {}).get("legacy_points", 0)) for op in free_unconditional[:required])
    perks = ngplus.get("perks", [])
    perk_costs = [int(perk.get("cost", 0)) for perk in perks]
    min_perk_cost = min(perk_costs) if perk_costs else 10**9
    audit.check("NG+ : les opérations gratuites financent au moins un héritage", free_legacy >= min_perk_cost, f"héritage gratuit={free_legacy}, coût min={min_perk_cost}")
    audit.check("NG+ : un seul héritage actif", int(ngplus.get("max_legacy_perks", 0)) == 1, str(ngplus.get("max_legacy_perks")))

    difficulty = ngplus.get("difficulty_per_cycle", {})
    hp_pct = int(difficulty.get("enemy_hp_pct", 0))
    damage_pct = int(difficulty.get("enemy_damage_pct", 0))
    fear_pct = int(difficulty.get("enemy_fear_pct", 0))
    audit.check("NG+ : scaling par cycle strictement positif", 0 < hp_pct <= 50 and 0 < damage_pct <= 50 and 0 < fear_pct <= 50, str(difficulty))
    audit.info["ngplus_scaling"] = {
        f"cycle_{cycle}": {
            "enemy_hp_multiplier": round(1 + cycle * hp_pct / 100, 3),
            "enemy_damage_multiplier": round(1 + cycle * damage_pct / 100, 3),
            "enemy_fear_multiplier": round(1 + cycle * fear_pct / 100, 3),
        }
        for cycle in range(1, 5)
    }


def audit_boss_recruitment(root: Path, audit: BalanceAudit) -> None:
    recruits_data = load_json(root, "data/world/ngplus_boss_recruits.json")
    ngplus = load_json(root, "data/world/new_game_plus.json")
    contracts = load_json(root, "data/boss_design_contracts.json")
    recruits = recruits_data.get("recruits", [])
    capture_rules = recruits_data.get("capture_rules", {})
    contract_ids = {str(value.get("id", "")) for value in contracts.get("bosses", [])}
    recruit_ids = [str(value.get("id", "")) for value in recruits]
    encounter_ids = [str(value.get("encounter_id", "")) for value in recruits]

    audit.check("NG+ boss : 34 recrutements", len(recruits) == 34, f"trouvés={len(recruits)}")
    audit.check("NG+ boss : IDs de recrues uniques", len(recruit_ids) == len(set(recruit_ids)), f"total={len(recruit_ids)}")
    audit.check("NG+ boss : encounter_id uniques", len(encounter_ids) == len(set(encounter_ids)), f"total={len(encounter_ids)}")
    missing_contracts = [encounter for encounter in encounter_ids if normalize_boss_id(encounter) not in contract_ids]
    audit.check("NG+ boss : chaque recrutement possède un contrat de boss", not missing_contracts, str(missing_contracts))
    audit.check("NG+ boss : déblocage au Premier retour", int(recruits_data.get("unlock_cycle_min", 99)) == 1 and int(ngplus.get("boss_recruitment", {}).get("enabled_from_cycle", 99)) == 1)
    audit.check("NG+ boss : synchronisation au niveau moyen", recruits_data.get("level_sync") == "party_average" and ngplus.get("boss_recruitment", {}).get("level_sync") == "party_average")

    invalid_recruits: list[str] = []
    for recruit in recruits:
        recruit_id = str(recruit.get("id", ""))
        rank = str(recruit.get("rank", ""))
        base_damage = recruit.get("base_damage", [])
        if rank not in capture_rules:
            invalid_recruits.append(f"{recruit_id}:rank={rank}")
        if not isinstance(base_damage, list) or len(base_damage) != 2 or int(base_damage[0]) <= 0 or int(base_damage[1]) < int(base_damage[0]):
            invalid_recruits.append(f"{recruit_id}:damage={base_damage}")
    audit.check("NG+ boss : rangs et dégâts alliés valides", not invalid_recruits, "; ".join(invalid_recruits))

    rule_errors: list[str] = []
    for rank, rule in capture_rules.items():
        ratio = float(rule.get("max_hp_ratio", 0))
        resistance = int(rule.get("resistance", -1))
        essence = int(rule.get("essence_cost", -1))
        if not (0 < ratio <= 0.25):
            rule_errors.append(f"{rank}:ratio={ratio}")
        if not (0 <= resistance <= 90):
            rule_errors.append(f"{rank}:resistance={resistance}")
        if not (1 <= essence <= 18):
            rule_errors.append(f"{rank}:essence={essence}")
    audit.check("NG+ boss : règles de capture dans des bornes jouables", not rule_errors, "; ".join(rule_errors))
    ratios = {rank: float(rule.get("max_hp_ratio", 1)) for rank, rule in capture_rules.items()}
    ordered = all(rank in ratios for rank in ("deep_boss", "boss", "deep_miniboss", "miniboss")) and ratios["deep_boss"] <= ratios["boss"] <= ratios["deep_miniboss"] <= ratios["miniboss"]
    audit.check("NG+ boss : difficulté de seuil cohérente par rang", ordered, str(ratios))


def run(root: Path = ROOT) -> BalanceAudit:
    audit = BalanceAudit()
    audit_hero_progression(root, audit)
    audit_creature_progression(root, audit)
    audit_endings(root, audit)
    audit_postgame_economy(root, audit)
    audit_boss_recruitment(root, audit)
    return audit


def write_report(audit: BalanceAudit, outdir: Path) -> None:
    outdir.mkdir(parents=True, exist_ok=True)
    payload = {
        "summary": {
            "passed": sum(1 for item in audit.checks if item["ok"]),
            "errors": len(audit.errors),
            "warnings": len(audit.warnings),
            "total": len(audit.checks),
        },
        "checks": audit.checks,
        "info": audit.info,
    }
    (outdir / "balance-report.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit progression/équilibrage de Light in the Dark")
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--out", type=Path, default=ROOT / "reports")
    args = parser.parse_args()
    audit = run(args.root)
    write_report(audit, args.out)
    for item in audit.checks:
        prefix = "PASS" if item["ok"] else ("WARN" if item["severity"] == "warning" else "FAIL")
        print(prefix, "-", item["name"], item["detail"])
    print(f"RESULT: {len(audit.errors)} error(s), {len(audit.warnings)} warning(s), {len(audit.checks)} checks")
    return 1 if audit.errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
