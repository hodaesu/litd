from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MATRIX = ROOT / "data" / "veilleurs" / "qa" / "premerge_playtest_matrix_v1.json"
DEFAULT_TEMPLATE = ROOT / "data" / "veilleurs" / "qa" / "premerge_playtest_results_template_v1.json"


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_structure(matrix: dict[str, Any], results: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if results.get("protocol_id") != matrix.get("protocol_id"):
        errors.append("protocol_id mismatch")
    if results.get("pull_request") != matrix.get("pull_request"):
        errors.append("pull_request mismatch")

    cases = matrix.get("cases", [])
    result_rows = results.get("results", [])
    case_ids = [str(row.get("id", "")) for row in cases]
    result_ids = [str(row.get("id", "")) for row in result_rows]
    if len(case_ids) != len(set(case_ids)):
        errors.append("duplicate case id in matrix")
    if len(result_ids) != len(set(result_ids)):
        errors.append("duplicate case id in results")
    if set(case_ids) != set(result_ids):
        missing = sorted(set(case_ids) - set(result_ids))
        extra = sorted(set(result_ids) - set(case_ids))
        if missing:
            errors.append("missing result ids: " + ",".join(missing))
        if extra:
            errors.append("unknown result ids: " + ",".join(extra))

    allowed_results = set(matrix.get("results_schema", {}).get("allowed", []))
    for row in result_rows:
        if row.get("result") not in allowed_results:
            errors.append(f"invalid result for {row.get('id')}: {row.get('result')}")

    expected_workflows = set(matrix.get("merge_gate", {}).get("required_workflows", []))
    actual_workflows = set(results.get("workflow_status", {}))
    if expected_workflows != actual_workflows:
        errors.append("workflow_status keys mismatch")
    return errors


def evaluate(matrix: dict[str, Any], results: dict[str, Any]) -> dict[str, Any]:
    structure_errors = validate_structure(matrix, results)
    cases = {str(row["id"]): row for row in matrix.get("cases", [])}
    result_rows = {str(row["id"]): row for row in results.get("results", [])}
    reasons: list[str] = list(structure_errors)

    workflow_status = results.get("workflow_status", {})
    for workflow in matrix.get("merge_gate", {}).get("required_workflows", []):
        if str(workflow_status.get(workflow, "")).upper() != "SUCCESS":
            reasons.append(f"workflow not green: {workflow}={workflow_status.get(workflow, 'MISSING')}")

    blocking_not_passed: list[str] = []
    for case_id, case in cases.items():
        if bool(case.get("merge_blocking", False)) and str(result_rows.get(case_id, {}).get("result", "MISSING")) != "PASS":
            blocking_not_passed.append(case_id)
    if blocking_not_passed:
        reasons.append("merge-blocking cases not PASS: " + ",".join(sorted(blocking_not_passed)))

    open_blockers: list[str] = []
    open_repro_major_core: list[str] = []
    for bug in results.get("open_bugs", []):
        if str(bug.get("status", "OPEN")).upper() in {"FIXED", "CLOSED"}:
            continue
        severity = str(bug.get("severity", "")).upper()
        bug_id = str(bug.get("id", "UNTRACKED"))
        if severity == "BLOCKER":
            open_blockers.append(bug_id)
        if (
            severity == "MAJOR"
            and bool(bug.get("reproducible", False))
            and bool(bug.get("core_system", False))
        ):
            open_repro_major_core.append(bug_id)

    if len(open_blockers) > int(matrix.get("merge_gate", {}).get("max_open_blocker", 0)):
        reasons.append("open BLOCKER: " + ",".join(open_blockers))
    if len(open_repro_major_core) > int(matrix.get("merge_gate", {}).get("max_open_reproducible_major_core", 0)):
        reasons.append("open reproducible core MAJOR: " + ",".join(open_repro_major_core))

    result_counts = Counter(str(row.get("result", "MISSING")) for row in results.get("results", []))
    return {
        "protocol_id": matrix.get("protocol_id"),
        "pull_request": matrix.get("pull_request"),
        "tested_commit": results.get("tested_commit", ""),
        "verdict": "MERGE" if not reasons else "NO_MERGE",
        "reasons": reasons,
        "counts": dict(sorted(result_counts.items())),
        "blocking_not_passed": sorted(blocking_not_passed),
        "open_blockers": open_blockers,
        "open_reproducible_major_core": open_repro_major_core,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Evaluate the Les Veilleurs PR #173 human playtest gate.")
    parser.add_argument("--matrix", type=Path, default=DEFAULT_MATRIX)
    parser.add_argument("--results", type=Path)
    parser.add_argument("--validate-template", action="store_true")
    parser.add_argument("--json", action="store_true", dest="as_json")
    args = parser.parse_args()

    matrix = load(args.matrix)
    if args.validate_template:
        template = load(DEFAULT_TEMPLATE)
        errors = validate_structure(matrix, template)
        if errors:
            for error in errors:
                print(f"FAIL {error}")
            return 1
        print(f"VEILLEURS_PR173_PLAYTEST_TEMPLATE_OK: {len(matrix['cases'])}/{len(matrix['cases'])}")
        return 0

    if args.results is None:
        parser.error("--results is required unless --validate-template is used")

    report = evaluate(matrix, load(args.results))
    if args.as_json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(f"VEILLEURS_PR173_PLAYTEST_VERDICT: {report['verdict']}")
        for key, value in report["counts"].items():
            print(f"{key}: {value}")
        for reason in report["reasons"]:
            print(f"- {reason}")
    return 0 if report["verdict"] == "MERGE" else 1


if __name__ == "__main__":
    raise SystemExit(main())
