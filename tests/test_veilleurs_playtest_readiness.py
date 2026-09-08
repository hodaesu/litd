from __future__ import annotations

import json
from pathlib import Path

from tools.playtest.prepare_naive_tester_pack import prepare_pack
from tools.playtest.summarize_naive_playtests import summarize
from tools.qa.veilleurs_playtest_readiness_audit import validate


def test_readiness_contract_is_coherent() -> None:
    assert validate() == []


def test_naive_pack_contains_five_neutral_sessions(tmp_path: Path) -> None:
    commit = "0123456789abcdef0123456789abcdef01234567"
    pack = prepare_pack(tmp_path / "pack", 5, commit)
    manifest = json.loads((pack / "PACK_MANIFEST.json").read_text(encoding="utf-8"))
    assert manifest["validation_status"] == "NOT_RUN"
    assert len(manifest["testers"]) == 5

    for tester_id in manifest["testers"]:
        report = json.loads((pack / tester_id / "player_validation.json").read_text(encoding="utf-8"))
        assert report["build_commit"] == commit
        assert report["testers"] == [tester_id]
        assert all(gate["status"] == "NOT_RUN" for gate in report["gates"])
        assert all(gate["evidence"] == [] for gate in report["gates"])
        session = json.loads((pack / tester_id / "session_manifest.json").read_text(encoding="utf-8"))
        assert session["prior_litd_experience"] is False
        assert session["status"] == "NOT_RUN"


def test_summary_never_decides_human_gate(tmp_path: Path) -> None:
    pack = prepare_pack(tmp_path / "pack", 5, "abc123")
    payload = summarize(pack)
    assert payload["automatic_human_gate_decision"] == "FORBIDDEN"
    assert payload["requires_human_review"] is True
    assert payload["pack_validation_status"] == "NOT_RUN"
    assert payload["errors"] == []


def test_pack_refuses_less_than_five_naive_testers(tmp_path: Path) -> None:
    try:
        prepare_pack(tmp_path / "pack", 4, "abc123")
    except ValueError as exc:
        assert "minimum naïf 5" in str(exc)
    else:
        raise AssertionError("Le pack ne doit jamais préparer moins de cinq testeurs naïfs")
