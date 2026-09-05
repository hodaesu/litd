from tools.qa.veilleurs_canonical_skills_audit import audit


def test_veilleurs_canonical_skills_contract_is_coherent():
    assert audit() == []
