import unittest

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


class GitHubMergeEnforcementContractTests(unittest.TestCase):
    def test_unprotected_main_fails_closed(self):
        result = evaluate(branch(False), [strict_ruleset()])
        self.assertFalse(result["external_merge_enforcement_verified"])
        self.assertIn("main_not_protected", result["blockers"])

    def test_missing_active_main_ruleset_fails_closed(self):
        result = evaluate(branch(True), [])
        self.assertFalse(result["external_merge_enforcement_verified"])
        self.assertIn("no_active_main_ruleset", result["blockers"])

    def test_ruleset_with_bypass_actor_is_not_accepted(self):
        result = evaluate(
            branch(True),
            [strict_ruleset(bypass=[{"actor_type": "RepositoryRole", "actor_id": 5}])],
        )
        self.assertFalse(result["external_merge_enforcement_verified"])
        self.assertIn("no_ruleset_enforces_merge_execution_gate_without_bypass", result["blockers"])

    def test_ruleset_must_require_merge_execution_gate(self):
        result = evaluate(branch(True), [strict_ruleset(include_check=False)])
        self.assertFalse(result["external_merge_enforcement_verified"])
        self.assertIn("no_ruleset_enforces_merge_execution_gate_without_bypass", result["blockers"])

    def test_default_branch_token_is_accepted(self):
        ruleset = strict_ruleset()
        ruleset["conditions"]["ref_name"]["include"] = ["~DEFAULT_BRANCH"]
        result = evaluate(branch(True), [ruleset])
        self.assertTrue(result["external_merge_enforcement_verified"])
        self.assertEqual(result["status"], "EXTERNAL_MERGE_ENFORCEMENT_VERIFIED")

    def test_strict_main_ruleset_verifies_external_enforcement(self):
        result = evaluate(branch(True), [strict_ruleset()])
        self.assertTrue(result["external_merge_enforcement_verified"])
        self.assertEqual(result["blockers"], [])


if __name__ == "__main__":
    unittest.main()
