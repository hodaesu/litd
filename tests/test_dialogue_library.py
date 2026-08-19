from tools.qa.dialogue_library_audit import run


def test_dialogue_library_audit_has_no_errors():
    payload = run()
    failures = [item for item in payload["checks"] if not item["ok"]]
    assert not failures, failures


def test_dialogue_library_keeps_sources_as_abstract_reference_only():
    payload = run()
    rights_checks = [
        item for item in payload["checks"]
        if item["name"].startswith("Droits :")
        or item["name"].startswith("Références modernes :")
    ]
    assert rights_checks
    assert all(item["ok"] for item in rights_checks)


def test_dialogue_library_covers_voice_staging_and_subtext():
    payload = run()
    required_names = {
        "Dialogue : axe voice_specificity",
        "Dialogue : axe subtext",
        "Dialogue : technique objective_and_tactic",
        "Dialogue : technique subtext_gap",
        "Mise en scène : technique implied_stage_action",
        "Mise en scène : technique blocking_as_power",
        "Voix : mode de mensonge",
        "Voix : comportement du silence",
    }
    by_name = {item["name"]: item for item in payload["checks"]}
    assert required_names <= set(by_name)
    assert all(by_name[name]["ok"] for name in required_names)
