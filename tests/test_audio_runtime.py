from tools.qa.audio_runtime_audit import audit


def test_audio_runtime_contract() -> None:
    assert audit() == []
