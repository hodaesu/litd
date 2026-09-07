from pathlib import Path

ROOT = Path(__file__).parents[1]
SAVE_MANAGER = ROOT / "scripts/core/save_manager.gd"
FACADE = ROOT / "scripts/core/veilleurs_runtime_facade.gd"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_save_manager_writes_only_neutral_veilleurs_key():
    text = _read(SAVE_MANAGER)
    assert 'const VEILLEURS_RUNTIME := preload("res://scripts/core/veilleurs_runtime_facade.gd")' in text
    assert '"mode": "veilleurs" if VEILLEURS_RUNTIME.is_active() else "litd1"' in text
    assert '"veilleurs": VEILLEURS_RUNTIME.serialize(),' in text
    assert '"veilleurs_vs001": VeilleursVS001PlayableBridge.serialize()' not in text
    assert "VeilleursVS001PlayableBridge" not in text
    assert "VeilleursVS001WorldRuntime" not in text


def test_old_vs001_save_key_is_read_only_migration_input():
    text = _read(SAVE_MANAGER)
    assert 'if not payload.has("veilleurs"):' in text
    assert 'payload["veilleurs"] = payload.get("veilleurs_vs001",{})' in text
    assert 'payload.erase("veilleurs_vs001")' in text
    assert text.count('"veilleurs_vs001"') == 2
    assert 'VEILLEURS_RUNTIME.deserialize(payload.get("veilleurs",{}))' in text


def test_save_version_remains_031_for_backward_compatibility():
    text = _read(SAVE_MANAGER)
    assert 'const SAVE_VERSION := "0.31"' in text


def test_canonical_facade_is_the_only_runtime_bridge():
    text = _read(FACADE)
    for api in ("is_active", "start_playable", "resume_playable", "serialize", "deserialize"):
        assert f"static func {api}" in text
    assert "VeilleursVS001WorldRuntime" in text
    assert "VeilleursVS001PlayableBridge" in text
