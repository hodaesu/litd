from pathlib import Path

from tools.qa.music_library_audit import run


ROOT = Path(__file__).resolve().parents[1]


def test_music_library_audit_is_green() -> None:
    report = run(ROOT)
    failures = [item for item in report["checks"] if not item["ok"]]
    assert not failures, failures


def test_music_library_separates_license_risk_from_emotional_use() -> None:
    import json

    data = json.loads((ROOT / "data/music_library.json").read_text(encoding="utf-8"))
    tracks = data["tracks"]

    boss = [item for item in tracks if "combat_boss" in item.get("cues", [])]
    memorial = [item for item in tracks if "memorial" in item.get("cues", [])]
    assert any(item["legal_tier"] == "green" for item in boss)
    assert any(item["legal_tier"] == "green" for item in memorial)

    content_id = [item for item in tracks if item.get("content_id") is True]
    assert content_id
    assert all(item["legal_tier"] != "green" for item in content_id)


def test_mixkit_is_not_silently_treated_as_game_safe() -> None:
    import json

    data = json.loads((ROOT / "data/music_library.json").read_text(encoding="utf-8"))
    source = next(item for item in data["sources"] if item["id"] == "mixkit")
    assert source["default_tier"] == "red"
    assert any(item["source"] == "mixkit" for item in data["excluded_sources"])
