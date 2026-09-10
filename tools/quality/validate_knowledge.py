#!/usr/bin/env python3
"""Validate the LITD Development Intelligence knowledge contract and safe game invariants.

The guard deliberately uses only Python's standard library so it stays fast,
portable and dependency-free in CI.
"""

from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
RULES = ROOT / "docs" / "knowledge" / "guardian-rules.yml"
DEPENDENCIES = ROOT / "docs" / "knowledge" / "dependencies.yml"
DECISION_TEMPLATE = ROOT / "docs" / "knowledge" / "templates" / "decision.md"
RESEARCH_TEMPLATE = ROOT / "docs" / "knowledge" / "templates" / "research.md"
CAPTURABLE_CREATURES = ROOT / "data" / "capturable_creatures.json"

ALLOWED_SEVERITIES = {"green", "yellow", "orange", "red"}
REQUIRED_DECISION_HEADINGS = {
    "## Qui ?",
    "## Quoi ?",
    "## Où ?",
    "## Pourquoi ?",
    "## Comment ?",
    "## Alternatives considérées",
    "## Éléments de preuve",
    "## Contre-preuves / tentative de réfutation",
    "## Dépendances impactées",
    "## Risques",
    "## Tests et métriques",
    "## Valeur joueur",
    "## Réversibilité / plan de retour arrière",
}
REQUIRED_RESEARCH_HEADINGS = {
    "## Hypothèses de départ",
    "## Sources",
    "## Résultats concordants",
    "## Contradictions / limites",
    "## Recherche opposée",
    "## Ce qui est vérifié dans LITD",
    "## Ce qui reste inconnu",
    "## Date ou condition de revalidation",
}


def fail(message: str) -> None:
    print(f"KNOWLEDGE_GUARDIAN_ERROR: {message}", file=sys.stderr)


def warn(message: str) -> None:
    print(f"KNOWLEDGE_GUARDIAN_WARNING: {message}")


def parse_rules(text: str) -> list[dict[str, str]]:
    rules: list[dict[str, str]] = []
    current: dict[str, str] | None = None
    for raw in text.splitlines():
        line = raw.strip()
        match = re.match(r"^- id:\s*([A-Za-z0-9_-]+)\s*$", line)
        if match:
            if current is not None:
                rules.append(current)
            current = {"id": match.group(1)}
            continue
        if current is None:
            continue
        field = re.match(r"^(severity|domain|description|validation):\s*(.*)$", line)
        if field:
            value = field.group(2).strip().strip('"').strip("'")
            current[field.group(1)] = value
    if current is not None:
        rules.append(current)
    return rules


def validate_rules() -> list[str]:
    errors: list[str] = []
    if not RULES.exists():
        return [f"missing {RULES.relative_to(ROOT)}"]

    text = RULES.read_text(encoding="utf-8")
    if not re.search(r"^version:\s*1\s*$", text, re.MULTILINE):
        errors.append("guardian-rules.yml must declare version: 1")

    rules = parse_rules(text)
    if not rules:
        errors.append("guardian-rules.yml contains no rules")
        return errors

    seen: set[str] = set()
    for rule in rules:
        rule_id = rule.get("id", "<unknown>")
        if rule_id in seen:
            errors.append(f"duplicate guardian rule id: {rule_id}")
        seen.add(rule_id)
        for field in ("severity", "domain", "description", "validation"):
            if not rule.get(field):
                errors.append(f"rule {rule_id} is missing {field}")
        severity = rule.get("severity")
        if severity and severity not in ALLOWED_SEVERITIES:
            errors.append(
                f"rule {rule_id} has invalid severity {severity!r}; "
                f"expected one of {sorted(ALLOWED_SEVERITIES)}"
            )
    return errors


def validate_template(path: Path, required: set[str]) -> list[str]:
    if not path.exists():
        return [f"missing {path.relative_to(ROOT)}"]
    text = path.read_text(encoding="utf-8")
    missing = sorted(heading for heading in required if heading not in text)
    return [f"{path.relative_to(ROOT)} missing heading: {heading}" for heading in missing]


def validate_dependency_graph() -> list[str]:
    if not DEPENDENCIES.exists():
        return [f"missing {DEPENDENCIES.relative_to(ROOT)}"]
    text = DEPENDENCIES.read_text(encoding="utf-8")
    if not re.search(r"^version:\s*1\s*$", text, re.MULTILINE):
        return ["dependencies.yml must declare version: 1"]

    node_ids = set(re.findall(r"^\s*- id:\s*([A-Za-z0-9_-]+)\s*$", text, re.MULTILINE))
    errors: list[str] = []
    if not node_ids:
        errors.append("dependencies.yml contains no nodes")
    for source, target in re.findall(
        r"^\s*- from:\s*([A-Za-z0-9_-]+)\s*\n\s+to:\s*([A-Za-z0-9_-]+)\s*$",
        text,
        re.MULTILINE,
    ):
        if source not in node_ids:
            errors.append(f"dependency edge references unknown source node: {source}")
        if target not in node_ids:
            errors.append(f"dependency edge references unknown target node: {target}")
    return errors


def validate_capturable_creatures() -> tuple[list[str], list[str]]:
    """Validate invariants that are already implemented; report future targets separately."""
    errors: list[str] = []
    warnings: list[str] = []
    if not CAPTURABLE_CREATURES.exists():
        return [f"missing {CAPTURABLE_CREATURES.relative_to(ROOT)}"], warnings

    try:
        creatures = json.loads(CAPTURABLE_CREATURES.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"invalid capturable_creatures.json: {exc}"], warnings

    if not isinstance(creatures, list):
        return ["capturable_creatures.json root must be a list"], warnings

    creature_ids: set[str] = set()
    skill_ids: set[str] = set()
    for index, creature in enumerate(creatures):
        if not isinstance(creature, dict):
            errors.append(f"capturable creature #{index} must be an object")
            continue
        creature_id = str(creature.get("id", "")).strip()
        if not creature_id:
            errors.append(f"capturable creature #{index} has no id")
            continue
        if creature_id in creature_ids:
            errors.append(f"duplicate capturable creature id: {creature_id}")
        creature_ids.add(creature_id)

        name = str(creature.get("name", ""))
        if creature_id.lower() in {"angel", "ange"} or name.strip().lower() == "ange":
            errors.append("the boss Ange must never appear in capturable_creatures.json")

        trees = creature.get("skill_trees")
        if not isinstance(trees, dict) or len(trees) != 3:
            count = len(trees) if isinstance(trees, dict) else 0
            errors.append(
                f"{creature_id}: expected exactly 3 skill trees, found {count}"
            )
            continue

        for tree_name, skills in trees.items():
            if not isinstance(skills, list):
                errors.append(f"{creature_id}/{tree_name}: skills must be a list")
                continue
            if len(skills) != 15:
                warnings.append(
                    f"{creature_id}/{tree_name}: canonical target is 15 skills; "
                    f"current data has {len(skills)}"
                )
            local_ids: set[str] = set()
            for skill in skills:
                if not isinstance(skill, dict):
                    errors.append(f"{creature_id}/{tree_name}: skill must be an object")
                    continue
                skill_id = str(skill.get("id", "")).strip()
                if not skill_id:
                    errors.append(f"{creature_id}/{tree_name}: skill without id")
                    continue
                if skill_id in local_ids:
                    errors.append(f"{creature_id}/{tree_name}: duplicate skill id {skill_id}")
                local_ids.add(skill_id)
                if skill_id in skill_ids:
                    errors.append(f"global duplicate skill id: {skill_id}")
                skill_ids.add(skill_id)

    return errors, warnings


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    errors.extend(validate_rules())
    errors.extend(validate_dependency_graph())
    errors.extend(validate_template(DECISION_TEMPLATE, REQUIRED_DECISION_HEADINGS))
    errors.extend(validate_template(RESEARCH_TEMPLATE, REQUIRED_RESEARCH_HEADINGS))

    data_errors, data_warnings = validate_capturable_creatures()
    errors.extend(data_errors)
    warnings.extend(data_warnings)

    for warning in warnings:
        warn(warning)

    if errors:
        for error in errors:
            fail(error)
        return 1

    rule_count = len(parse_rules(RULES.read_text(encoding="utf-8")))
    print(
        "Knowledge Guardian OK: "
        f"{rule_count} rules validated; "
        f"{len(warnings)} tracked canonical gaps"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
