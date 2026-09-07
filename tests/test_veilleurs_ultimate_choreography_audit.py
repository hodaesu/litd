from tools.qa import veilleurs_ultimate_choreography_audit as audit


def test_veilleurs_ultimate_choreography_contract() -> None:
    assert audit.main() == 0
