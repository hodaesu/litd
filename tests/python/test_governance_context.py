import pytest

from tools.quality.governance_context import compute_context_hash


def components():
    return {
        "core_state_hash": "1" * 64,
        "target_registry_hash": "2" * 64,
        "guardian_rules_hash": "3" * 64,
        "governance_contract_hash": "4" * 64,
    }


def test_context_hash_is_deterministic():
    assert compute_context_hash(components()) == compute_context_hash(components())


def test_any_critical_component_change_makes_receipt_stale():
    baseline = compute_context_hash(components())
    for key in components():
        changed = components()
        changed[key] = "f" * 64
        assert compute_context_hash(changed) != baseline


def test_cross_project_context_is_rejected():
    with pytest.raises(ValueError, match="project scope mismatch"):
        compute_context_hash(components(), project_id="COMPANY")


def test_cross_route_context_is_rejected():
    with pytest.raises(ValueError, match="route scope mismatch"):
        compute_context_hash(components(), target_route="COMPANY_LIBRARY")


def test_missing_critical_component_is_rejected():
    data = components()
    del data["guardian_rules_hash"]
    with pytest.raises(ValueError, match="missing critical context components"):
        compute_context_hash(data)


def test_unknown_context_component_is_rejected():
    data = components()
    data["unreviewed_extra"] = "5" * 64
    with pytest.raises(ValueError, match="unknown critical context components"):
        compute_context_hash(data)


def test_invalid_component_hash_is_rejected():
    data = components()
    data["core_state_hash"] = "G" * 64
    with pytest.raises(ValueError, match="lowercase hex"):
        compute_context_hash(data)
