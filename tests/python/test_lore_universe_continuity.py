from __future__ import annotations

from copy import deepcopy

from tools.qa.lore_universe_audit import ROOT, audit


def test_shared_lore_is_consistent() -> None:
    report = audit(ROOT)
    assert report["ok"], report["errors"]
    assert report["summary"]["projects"] >= 2
    assert report["summary"]["facts"] >= 10


def test_audit_report_has_stable_shape() -> None:
    report = deepcopy(audit(ROOT))
    assert set(report) == {"ok", "errors", "warnings", "summary"}
    assert report["summary"]["canon_version"] == "1.0.0"
