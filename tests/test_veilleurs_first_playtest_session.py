import json
from pathlib import Path

from tools.playtest.prepare_veilleurs_first_playtest import ROOT, TEMPLATE, prepare_session


def test_prepared_first_playtest_session_never_fabricates_pass(tmp_path: Path) -> None:
    template_target = tmp_path / TEMPLATE.relative_to(ROOT)
    template_target.parent.mkdir(parents=True, exist_ok=True)
    template_target.write_text(TEMPLATE.read_text(encoding="utf-8"), encoding="utf-8")

    session = prepare_session(tmp_path, "tester-01", "windows", "PC test")
    report = json.loads((session / "player_validation.json").read_text(encoding="utf-8"))
    metadata = json.loads((session / "session.json").read_text(encoding="utf-8"))

    assert report["testers"] == ["tester-01"]
    assert report["build_commit"]
    assert report["tested_at"]
    assert all(gate["status"] == "NOT_RUN" for gate in report["gates"])
    assert all(not gate["evidence"] for gate in report["gates"])
    assert all(status == "NOT_RUN" for status in report["hardware_gate_results"].values())
    assert metadata["status"] == "PREPARED_NOT_RUN"
    assert (session / "observer_notes.md").is_file()
