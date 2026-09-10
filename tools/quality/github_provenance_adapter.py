#!/usr/bin/env python3
"""Bridge real GitHub commit / CI metadata into the LITD provenance chain.

This module consumes GitHub Actions environment variables or an explicit payload
and appends COMMIT / TEST / MEASUREMENT nodes only when the preceding Core
provenance chain already exists. It never fabricates a Core decision.
"""
from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from tools.quality.provenance_chain import ProvenanceChain


@dataclass(frozen=True)
class GitHubEvidence:
    repository: str
    commit_sha: str
    run_id: str
    run_attempt: str
    workflow: str
    job: str
    ref: str

    @property
    def run_url(self) -> str:
        return f"https://github.com/{self.repository}/actions/runs/{self.run_id}"

    @property
    def commit_url(self) -> str:
        return f"https://github.com/{self.repository}/commit/{self.commit_sha}"


def from_environment(env: dict[str, str] | None = None) -> GitHubEvidence:
    env = env or os.environ
    required = {
        "GITHUB_REPOSITORY": env.get("GITHUB_REPOSITORY", ""),
        "GITHUB_SHA": env.get("GITHUB_SHA", ""),
        "GITHUB_RUN_ID": env.get("GITHUB_RUN_ID", ""),
        "GITHUB_RUN_ATTEMPT": env.get("GITHUB_RUN_ATTEMPT", ""),
        "GITHUB_WORKFLOW": env.get("GITHUB_WORKFLOW", ""),
        "GITHUB_JOB": env.get("GITHUB_JOB", ""),
        "GITHUB_REF": env.get("GITHUB_REF", ""),
    }
    missing = sorted(key for key, value in required.items() if not value)
    if missing:
        raise ValueError(f"missing_github_environment:{','.join(missing)}")
    return GitHubEvidence(
        repository=required["GITHUB_REPOSITORY"],
        commit_sha=required["GITHUB_SHA"],
        run_id=required["GITHUB_RUN_ID"],
        run_attempt=required["GITHUB_RUN_ATTEMPT"],
        workflow=required["GITHUB_WORKFLOW"],
        job=required["GITHUB_JOB"],
        ref=required["GITHUB_REF"],
    )


def append_github_execution(
    chain: ProvenanceChain,
    *,
    core_decision_node_id: str,
    evidence_id: str,
    github: GitHubEvidence,
    tests_passed: bool,
    test_summary: dict[str, Any],
    measurement: dict[str, Any] | None = None,
) -> dict[str, str]:
    if not tests_passed:
        raise ValueError("cannot_record_successful_test_node_for_failed_ci")

    commit_node_id = f"commit:{github.commit_sha}"
    test_node_id = f"test:{github.run_id}:{github.run_attempt}:{github.job}"

    chain.append(
        node_id=commit_node_id,
        stage="COMMIT",
        parent_id=core_decision_node_id,
        evidence_id=evidence_id,
        external_ref=github.commit_sha,
        payload={
            "repository": github.repository,
            "sha": github.commit_sha,
            "commit_url": github.commit_url,
            "ref": github.ref,
        },
    )

    chain.append(
        node_id=test_node_id,
        stage="TEST",
        parent_id=commit_node_id,
        evidence_id=evidence_id,
        external_ref=f"github-run:{github.run_id}:attempt:{github.run_attempt}:job:{github.job}",
        payload={
            "workflow": github.workflow,
            "job": github.job,
            "run_id": github.run_id,
            "run_attempt": github.run_attempt,
            "run_url": github.run_url,
            "conclusion": "success",
            "summary": test_summary,
        },
    )

    result = {"commit_node_id": commit_node_id, "test_node_id": test_node_id}

    if measurement is not None:
        measurement_node_id = f"measurement:{github.run_id}:{github.run_attempt}:{github.job}"
        chain.append(
            node_id=measurement_node_id,
            stage="MEASUREMENT",
            parent_id=test_node_id,
            evidence_id=evidence_id,
            external_ref=f"measurement:{github.run_id}:attempt:{github.run_attempt}:job:{github.job}",
            payload=measurement,
        )
        result["measurement_node_id"] = measurement_node_id

    return result


def emit_provenance_event(output: str | Path, payload: dict[str, Any]) -> None:
    path = Path(output)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, sort_keys=True, indent=2), encoding="utf-8")
