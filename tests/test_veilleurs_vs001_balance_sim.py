from tools.qa.veilleurs_vs001_balance_sim import build_report


def test_vs001_synthetic_balance_guardrails_hold():
    report = build_report(runs=400, seed=1001)
    assert report["ok"], report["errors"]
    assert report["human_playtest_still_required"] is True


def test_vs001_careful_recruitment_beats_immediate_force():
    report = build_report(runs=200, seed=1001)
    careful = report["recruitment"]["careful_sequence"]["success_percent"]
    force = report["recruitment"]["immediate_force"]["success_percent"]
    assert 70 <= careful <= 90
    assert 20 <= force <= 45
    assert careful > force


def test_vs001_synthetic_profiles_create_distinct_pressure():
    report = build_report(runs=200, seed=1001)
    balanced = report["profiles"]["balanced"]
    thorough = report["profiles"]["thorough"]
    rush = report["profiles"]["rush"]
    assert thorough["light_on_s7_entry"]["median"] < balanced["light_on_s7_entry"]["median"]
    assert rush["light_on_s7_entry"]["median"] > balanced["light_on_s7_entry"]["median"]
    assert rush["peak_noise"]["median"] > balanced["peak_noise"]["median"]
