from tools.qa.veilleurs_system_maturity_audit import main


def test_veilleurs_system_maturity_registry_is_coherent() -> None:
    assert main() == 0
