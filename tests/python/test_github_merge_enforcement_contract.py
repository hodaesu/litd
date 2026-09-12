from tools.quality.github_merge_enforcement_contract import evaluate


def branch(protected: bool = True) -> dict:
    return {"name": "main", "protected": protected}


def strict_ruleset(*, bypass=None, include_check: bool = True) -> dict:
    checks = [{"context": "Merge Execution Gate"}] if include_check else [{"context": "CI"}]
    return {
        "id": 1,
        "name": "main-governance",
        "target": "branch",
        "enforcement": "active",
        "bypass_actors": [] if bypass is None else bypass,
        "conditions": {"ref_name": {"include": ["refs/heads/main"], "exclude": []}},
        "rules": [
            {"type": "pull_request"},
            {"type": "deletion"},
            {"type": "non_fast_forward"},
            {
                "type": "required_status_checks",
                "parameters": {"required_status_checks": checks},
            },
        ],
    }


def test_unprotected_main_fails_closed():
    result = evaluate(branch(False), [strict_ruleset()])
    assert result["external_merge_enforcement_verified"] is False
    assert "main_not_protected" in result["blockers"]


def test_missing_active_main_ruleset_fails_closed():
    result = evaluate(branch(True), [])
    assert result["external_merge_enforcement_verified"] is False
    assert "no_active_main_ruleset" in result["blockers"]


def test_ruleset_with_bypass_actor_is_not_accepted():
    result = evaluate(branch(True), [strict_ruleset(bypass=[{"actor_type": "RepositoryRole", "actor_id": 5}])])
    assert result["external_merge_enforcement_verified"] is False
    assert "no_ruleset_enforces_merge_execution_gate_without_bypass" in result["blockers"]


def test_ruleset_must_require_merge_execution_gate():
    result = evaluate(branch(True), [strict_ruleset(include_check=False)])
    assert result["external_merge_enforcement_verified"] is False
    assert "no_ruleset_enforces_merge_execution_gate_without_bypass" in result["blockers"]


def test_default_branch_token_is_accepted():
    ruleset = strict_ruleset()
    ruleset["conditions"]["ref_name"]["include"] = ["~DEFAULT_BRANCH"]
    result = evaluate(branch(True), [ruleset])
    assert result["external_merge_enforcement_verified"] is True
    assert result["status"] == "EXTERNAL_MERGE_ENFORCEMENT_VERIFIED"


def test_strict_main_ruleset_verifies_external_enforcement():
    result = evaluate(branch(True), [strict_ruleset()])
    assert result["external_merge_enforcement_verified"] is True
    assert result["blockers"] == []
