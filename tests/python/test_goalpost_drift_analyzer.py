from tools.quality.goalpost_drift_analyzer import analyze


def snap(seq, target):
    return {"sequence": seq, "targets": {"combat.boss_rounds": target}}


def measurement(value):
    return {"canonical_metrics": {"combat.boss_rounds": value}}


def test_flags_relaxed_max_without_real_improvement():
    report = analyze(
        [snap(1, {"kind": "max", "max": 10.0}), snap(2, {"kind": "max", "max": 12.0})],
        [measurement(11.5), measurement(11.5)],
    )
    assert report["status"] == "REVIEW_REQUIRED"
    assert report["signals"][0]["verdict"] == "GOALPOST_DRIFT_REVIEW_REQUIRED"
    assert report["core_write_allowed"] is False
    assert report["automatic_target_change_allowed"] is False


def test_relaxed_max_with_real_improvement_is_not_flagged():
    report = analyze(
        [snap(1, {"kind": "max", "max": 10.0}), snap(2, {"kind": "max", "max": 12.0})],
        [measurement(11.5), measurement(10.5)],
    )
    assert report["status"] == "OK"
    assert report["signals"][0]["verdict"] == "NO_GOALPOST_SIGNAL"


def test_relaxed_min_without_improvement_is_flagged():
    snapshots = [
        {"sequence": 1, "targets": {"x": {"kind": "min", "min": 0.8}}},
        {"sequence": 2, "targets": {"x": {"kind": "min", "min": 0.7}}},
    ]
    report = analyze(snapshots, [{"canonical_metrics": {"x": 0.72}}, {"canonical_metrics": {"x": 0.71}}])
    assert report["status"] == "REVIEW_REQUIRED"


def test_window_uses_distance_to_original_window():
    snapshots = [
        {"sequence": 1, "targets": {"x": {"kind": "window", "min": 5.0, "max": 10.0}}},
        {"sequence": 2, "targets": {"x": {"kind": "window", "min": 4.0, "max": 12.0}}},
    ]
    report = analyze(snapshots, [{"canonical_metrics": {"x": 11.5}}, {"canonical_metrics": {"x": 10.5}}])
    assert report["status"] == "OK"


def test_insufficient_measurements_is_inconclusive_not_accusatory():
    report = analyze(
        [snap(1, {"kind": "max", "max": 10.0}), snap(2, {"kind": "max", "max": 12.0})],
        [measurement(11.5)],
    )
    assert report["signals"][0]["verdict"] == "INCONCLUSIVE"


def test_no_relaxation_means_no_signal():
    report = analyze(
        [snap(1, {"kind": "max", "max": 10.0}), snap(2, {"kind": "max", "max": 9.0})],
        [measurement(11.0), measurement(10.0)],
    )
    assert report["status"] == "NO_PERMISSIVE_TARGET_DRIFT"
    assert report["signals"] == []


def test_single_snapshot_is_inconclusive_and_never_writes_core():
    report = analyze([snap(1, {"kind": "max", "max": 10.0})], [measurement(11.0), measurement(10.0)])
    assert report["status"] == "INCONCLUSIVE"
    assert report["core_write_allowed"] is False
