from tools.quality.repository_governance_audit import audit


def policy():
    return {
        "kind": "LITD_REPOSITORY_GOVERNANCE_POLICY",
        "target_branch": "main",
        "required": {
            "pull_request_required": True,
            "force_push_forbidden": True,
            "branch_deletion_forbidden": True,
            "required_status_checks": ["CI", "Knowledge Governance"],
            "bypass_allowed": False,
        },
    }


def test_unprotected_main_without_ruleset_is_non_compliant():
    result = audit(policy(), {"protected": False}, [])
    assert result["status"] == "NON_COMPLIANT"
    assert "main_has_no_server_side_protection" in result["findings"]


def test_active_ruleset_can_satisfy_policy():
    rulesets = [{
        "target": "branch",
        "enforcement": "active",
        "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"]}},
        "bypass_actors": [],
        "rules": [
            {"type": "pull_request"},
            {"type": "non_fast_forward"},
            {"type": "deletion"},
            {"type": "required_status_checks", "parameters": {"required_status_checks": [
                {"context": "CI"}, {"context": "Knowledge Governance"}
            ]}},
        ],
    }]
    result = audit(policy(), {"protected": False}, rulesets)
    assert result["status"] == "COMPLIANT"
    assert result["findings"] == []


def test_missing_required_check_is_detected():
    rulesets = [{
        "target": "branch", "enforcement": "active",
        "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"]}},
        "bypass_actors": [],
        "rules": [
            {"type": "pull_request"}, {"type": "non_fast_forward"}, {"type": "deletion"},
            {"type": "required_status_checks", "parameters": {"required_status_checks": [{"context": "CI"}]}},
        ],
    }]
    result = audit(policy(), {"protected": False}, rulesets)
    assert result["status"] == "NON_COMPLIANT"
    assert any(x.startswith("missing_required_status_checks:") for x in result["findings"])


def test_bypass_actor_is_detected():
    rulesets = [{
        "target": "branch", "enforcement": "active",
        "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"]}},
        "bypass_actors": [{"actor_id": 1}],
        "rules": [
            {"type": "pull_request"}, {"type": "non_fast_forward"}, {"type": "deletion"},
            {"type": "required_status_checks", "parameters": {"required_status_checks": [
                {"context": "CI"}, {"context": "Knowledge Governance"}
            ]}},
        ],
    }]
    result = audit(policy(), {"protected": False}, rulesets)
    assert "ruleset_bypass_present" in result["findings"]
