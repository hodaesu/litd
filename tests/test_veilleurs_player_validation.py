from tools.qa.veilleurs_player_validation_audit import main


def test_veilleurs_player_validation_contract_is_coherent() -> None:
    assert main() == 0
