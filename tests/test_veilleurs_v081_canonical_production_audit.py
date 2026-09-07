from tools.qa.veilleurs_v081_canonical_production_audit import main


def test_veilleurs_v081_canonical_production_contract() -> None:
    assert main() == 0
