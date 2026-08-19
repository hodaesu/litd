from tools.qa.narrative_audio_audit import ROOT, run


def test_narrative_audio_scene_hooks_are_grounded_in_real_runtime_data() -> None:
    report = run(ROOT)
    failed = [item for item in report["checks"] if not item["ok"]]
    assert report["summary"]["errors"] == 0, failed
