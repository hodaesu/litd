from tools.qa.veilleurs_vs001_legacy_audit import ROOT, audit


def test_vs001_compatibility_boundary_is_locked() -> None:
    result = audit(ROOT)
    assert result["ok"], "\n".join(result["errors"])


def test_vs001_runtime_surface_does_not_expand() -> None:
    result = audit(ROOT)
    assert result["legacy_scripts_actual"] == result["legacy_scripts_declared"] == 9
    assert result["unmanaged_legacy_scripts"] == []
    assert result["missing_legacy_scripts"] == []


def test_canonical_player_surface_has_no_vs001_dependency() -> None:
    result = audit(ROOT)
    assert result["canonical_vs001_refs"] == []


def test_old_save_gate_remains_pending_until_real_pc_validation() -> None:
    result = audit(ROOT)
    assert result["pc_old_save_gate_validated"] is False
