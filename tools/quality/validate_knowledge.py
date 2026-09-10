#!/usr/bin/env python3
"""Validate the minimal LITD Development Intelligence knowledge contract.

This deliberately uses only the Python standard library so the guard can run
in CI without adding a package dependency.
"""

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
RULES = ROOT / "docs" / "knowledge" / "guardian-rules.yml"
DECISION_TEMPLATE = ROOT / "docs" / "knowledge" / "templates" / "decision.md"
RESEARCH_TEMPLATE = ROOT / "docs" / "knowledge" / "templates" / "research.md"

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


def main() -> int:
    errors = []
    errors.extend(validate_rules())
    errors.extend(validate_template(DECISION_TEMPLATE, REQUIRED_DECISION_HEADINGS))
    errors.extend(validate_template(RESEARCH_TEMPLATE, REQUIRED_RESEARCH_HEADINGS))

    if errors:
        for error in errors:
            fail(error)
        return 1

    rule_count = len(parse_rules(RULES.read_text(encoding="utf-8")))
    print(f"Knowledge Guardian OK: {rule_count} rules validated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
