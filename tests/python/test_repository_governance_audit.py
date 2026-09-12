from tools.quality.repository_governance_audit import audit


def policy():
    return {
        "kind": "LITD_REPOSITORY_GOVERNANCE_POLICY",
        "target_branch": "main",
        "required": {
            "pull_request_required": True,
            "direct_push_forbidden": True,
            "force_push_forbidden": True,
            "branch_deletion_forbidden": True,
            "required_status_checks": ["quality", "guardian"],
            "require_conversation_resolution": True,
            "require_up_to_date_before_merge": True,
            "bypass_allowed": False,
        },
    }


def compliant_ruleset():
    return [{
        "target": "branch",
        "enforcement": "active",
        "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"]}},
        "bypass_actors": [],
        "rules": [
            {"type": "pull_request", "parameters": {"required_review_thread_resolution": True}},
            {"type": "non_fast_forward"},
            {"type": "deletion"},
            {"type": "required_status_checks", "parameters": {
                "strict_required_status_checks_policy": True,
                "required_status_checks": [{"context": "quality"}, {"context": "guardian"}],
            }},
        ],
    }]


def test_unprotected_main_without_ruleset_is_non_compliant():
    result = audit(policy(), {"protected": False}, [])
    assert result["status"] == "NON_COMPLIANT"
    assert "main_has_no_active_ruleset" in result["findings"]


def test_active_ruleset_can_satisfy_policy():
    result = audit(policy(), {"protected": False}, compliant_ruleset())
    assert result["status"] == "COMPLIANT"
    assert result["findings"] == []


def test_evaluate_mode_does_not_count_as_enforcement():
    rulesets = compliant_ruleset()
    rulesets[0]["enforcement"] = "evaluate"
    result = audit(policy(), {"protected": True}, rulesets)
    assert result["status"] == "NON_COMPLIANT"
    assert "main_has_no_active_ruleset" in result["findings"]


def test_missing_required_check_is_detected():
    rulesets = compliant_ruleset()
    rulesets[0]["rules"][-1]["parameters"]["required_status_checks"] = [{"context": "quality"}]
    result = audit(policy(), {"protected": False}, rulesets)
    assert result["status"] == "NON_COMPLIANT"
    assert any(x.startswith("missing_required_status_checks:") for x in result["findings"])


def test_bypass_actor_is_detected_and_direct_push_not_fully_forbidden():
    rulesets = compliant_ruleset()
    rulesets[0]["bypass_actors"] = [{"actor_id": 1}]
    result = audit(policy(), {"protected": False}, rulesets)
    assert "ruleset_bypass_present" in result["findings"]
    assert "direct_push_not_fully_forbidden" in result["findings"]


def test_conversation_resolution_is_required():
    rulesets = compliant_ruleset()
    rulesets[0]["rules"][0]["parameters"]["required_review_thread_resolution"] = False
    result = audit(policy(), {"protected": False}, rulesets)
    assert "conversation_resolution_not_required" in result["findings"]


def test_strict_status_checks_are_required():
    rulesets = compliant_ruleset()
    rulesets[0]["rules"][-1]["parameters"]["strict_required_status_checks_policy"] = False
    result = audit(policy(), {"protected": False}, rulesets)
    assert "strict_status_checks_not_required" in result["findings"]
