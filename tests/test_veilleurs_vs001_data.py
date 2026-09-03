from tools.qa.veilleurs_vs001_audit import audit


def test_veilleurs_vs001_contract_is_coherent():
    assert audit() == []
