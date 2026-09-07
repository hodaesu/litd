import json
import subprocess
import sys
from copy import deepcopy
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MATRIX = ROOT / "data" / "veilleurs" / "qa" / "premerge_playtest_matrix_v1.json"
TEMPLATE = ROOT / "data" / "veilleurs" / "qa" / "premerge_playtest_results_template_v1.json"
TOOL = ROOT / "tools" / "qa" / "veilleurs_pr173_playtest_gate.py"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def run_tool(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(TOOL), *args],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def test_results_template_covers_exactly_the_39_matrix_cases():
    matrix = load(MATRIX)
    template = load(TEMPLATE)
    matrix_ids = [row["id"] for row in matrix["cases"]]
    result_ids = [row["id"] for row in template["results"]]
    assert len(matrix_ids) == len(result_ids) == 39
    assert matrix_ids == result_ids
    assert all(row["result"] == "NOT_RUN" for row in template["results"])


def test_gate_tool_accepts_the_clean_template_structure():
    result = run_tool("--validate-template")
    assert result.returncode == 0, result.stdout + result.stderr
    assert "VEILLEURS_PR173_PLAYTEST_TEMPLATE_OK: 39/39" in result.stdout


def test_gate_tool_returns_merge_only_when_all_required_cases_and_workflows_pass(tmp_path: Path):
    payload = load(TEMPLATE)
    payload["tested_commit"] = "test-green-head"
    payload["workflow_status"] = {key: "SUCCESS" for key in payload["workflow_status"]}
    for row in payload["results"]:
        row["result"] = "PASS"
    results_path = tmp_path / "green.json"
    results_path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")

    result = run_tool("--results", str(results_path), "--json")
    assert result.returncode == 0, result.stdout + result.stderr
    report = json.loads(result.stdout)
    assert report["verdict"] == "MERGE"
    assert report["reasons"] == []
    assert report["counts"] == {"PASS": 39}


def test_gate_tool_refuses_not_run_blocking_cases_and_open_blockers(tmp_path: Path):
    payload = load(TEMPLATE)
    payload["tested_commit"] = "test-red-head"
    payload["workflow_status"] = {key: "SUCCESS" for key in payload["workflow_status"]}
    for row in payload["results"]:
        row["result"] = "PASS"
    payload["results"][0]["result"] = "NOT_RUN"
    payload["open_bugs"] = [
        {
            "id": "VPR173-001",
            "severity": "BLOCKER",
            "status": "OPEN",
            "reproducible": True,
            "core_system": True,
        }
    ]
    results_path = tmp_path / "blocked.json"
    results_path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")

    result = run_tool("--results", str(results_path), "--json")
    assert result.returncode == 1
    report = json.loads(result.stdout)
    assert report["verdict"] == "NO_MERGE"
    assert "PRE-01" in report["blocking_not_passed"]
    assert report["open_blockers"] == ["VPR173-001"]


def test_nonblocking_case_can_fail_without_overriding_the_declared_gate(tmp_path: Path):
    payload = load(TEMPLATE)
    payload["tested_commit"] = "test-nonblocking-fail"
    payload["workflow_status"] = {key: "SUCCESS" for key in payload["workflow_status"]}
    for row in payload["results"]:
        row["result"] = "PASS"
    target = next(row for row in payload["results"] if row["id"] == "BAL-02")
    target["result"] = "FAIL"
    results_path = tmp_path / "nonblocking.json"
    results_path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")

    result = run_tool("--results", str(results_path), "--json")
    assert result.returncode == 0, result.stdout + result.stderr
    report = json.loads(result.stdout)
    assert report["verdict"] == "MERGE"
    assert report["counts"] == {"FAIL": 1, "PASS": 38}
