from tools.qa.narrative_audio_audit import run


def test_narrative_audio_contract_is_valid() -> None:
    report = run()
    assert report["summary"]["errors"] == 0, report
