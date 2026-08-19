from tools.qa.audio_director_audit import run


def test_audio_director_contract_is_complete():
    payload = run()
    failures = [item for item in payload["checks"] if not item["ok"]]
    assert not failures, failures
