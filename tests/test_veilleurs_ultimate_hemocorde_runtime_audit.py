from tools.qa import veilleurs_v062_hemocorde_runtime_audit as audit


def test_veilleurs_v062_hemocorde_runtime_contract() -> None:
    assert audit.main() == 0
