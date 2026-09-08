from tools.qa.veilleurs_first_playtest_kit_audit import main


def test_veilleurs_first_playtest_kit_is_coherent() -> None:
    assert main() == 0
