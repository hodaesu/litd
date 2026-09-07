from tools.qa.veilleurs_repository_integrity_audit import main


def test_veilleurs_repository_integrity():
    assert main() == 0
