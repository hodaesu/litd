from tools.qa.veilleurs_vs001_persistence_ui_audit import audit


def test_veilleurs_vs001_persistence_ui_contract() -> None:
    assert audit() == []
