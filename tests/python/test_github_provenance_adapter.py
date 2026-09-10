import tempfile
from pathlib import Path

from tools.quality.github_provenance_adapter import GitHubEvidence, append_github_execution, from_environment
from tools.quality.provenance_chain import ProvenanceChain


def seed_through_core(chain: ProvenanceChain) -> None:
    chain.append(node_id="source:1", stage="SOURCE", payload={"url": "https://example.com"}, evidence_id="ev-1")
    chain.append(node_id="document:1", stage="DOCUMENT", parent_id="source:1", payload={"title": "doc"}, evidence_id="ev-1")
    chain.append(node_id="discovery:1", stage="DISCOVERY", parent_id="document:1", payload={"found": True}, evidence_id="ev-1")
    chain.append(node_id="routing:1", stage="ROUTING_DECISION", parent_id="discovery:1", payload={"route": "LITD_LIBRARY"}, evidence_id="ev-1")
    chain.append(node_id="core:1", stage="CORE_DECISION", parent_id="routing:1", payload={"approved": True}, evidence_id="ev-1")


def github() -> GitHubEvidence:
    return GitHubEvidence(
        repository="hodaesu/litd",
        commit_sha="a" * 40,
        run_id="123",
        run_attempt="1",
        workflow="Knowledge Governance",
        job="guardian",
        ref="refs/heads/main",
    )


def test_environment_requires_real_github_fields():
    try:
        from_environment({})
    except ValueError as exc:
        assert "missing_github_environment" in str(exc)
    else:
        raise AssertionError("expected missing environment failure")


def test_github_execution_appends_commit_test_measurement():
    with tempfile.TemporaryDirectory() as td:
        chain = ProvenanceChain(Path(td) / "p.db")
        seed_through_core(chain)
        result = append_github_execution(
            chain,
            core_decision_node_id="core:1",
            evidence_id="ev-1",
            github=github(),
            tests_passed=True,
            test_summary={"passed": 12, "failed": 0},
            measurement={"metric": "knowledge_governance", "value": 1},
        )
        assert chain.chain_complete_through(result["measurement_node_id"], "MEASUREMENT")
        assert chain.verify_integrity() is True
        chain.close()


def test_failed_ci_cannot_be_recorded_as_successful_test():
    with tempfile.TemporaryDirectory() as td:
        chain = ProvenanceChain(Path(td) / "p.db")
        seed_through_core(chain)
        try:
            append_github_execution(
                chain,
                core_decision_node_id="core:1",
                evidence_id="ev-1",
                github=github(),
                tests_passed=False,
                test_summary={"passed": 0, "failed": 1},
            )
        except ValueError as exc:
            assert str(exc) == "cannot_record_successful_test_node_for_failed_ci"
        else:
            raise AssertionError("failed CI must not become successful TEST evidence")
        chain.close()


def test_adapter_cannot_skip_core_decision():
    with tempfile.TemporaryDirectory() as td:
        chain = ProvenanceChain(Path(td) / "p.db")
        chain.append(node_id="source:1", stage="SOURCE", payload={}, evidence_id="ev-1")
        try:
            append_github_execution(
                chain,
                core_decision_node_id="source:1",
                evidence_id="ev-1",
                github=github(),
                tests_passed=True,
                test_summary={"passed": 1, "failed": 0},
            )
        except ValueError as exc:
            assert "invalid_parent_stage:COMMIT" in str(exc)
        else:
            raise AssertionError("adapter must require CORE_DECISION parent")
        chain.close()
