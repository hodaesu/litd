from tools.qa.veilleurs_vs001_playable_audit import audit


def test_veilleurs_vs001_playable_contract() -> None:
    assert audit() == []
