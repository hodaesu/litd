import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTRACT_PATH = ROOT / "data/veilleurs/vs001_legacy_boundary.json"
LEGACY_TOKENS = ("vs001", "VeilleursVS001", "VS001")


def _contract() -> dict:
    return json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))


def _is_legacy_owned(path: Path, prefixes: list[str]) -> bool:
    relative = path.relative_to(ROOT).as_posix()
    return any(relative.startswith(prefix) for prefix in prefixes)


def test_vs001_is_frozen_behind_compatibility_boundary() -> None:
    contract = _contract()
    assert contract["status"] == "frozen_legacy_compatibility"
    assert contract["compatibility"]["read_support_required"] is True
    assert contract["compatibility"]["new_gameplay_dependencies_allowed"] is False
    assert contract["replacement"]["runtime_version"] == "0.9.0"
    assert (ROOT / "scripts/core/veilleurs_production_runtime.gd").is_file()
    assert (ROOT / "scripts/core/veilleurs_vertical_slice_runtime_v09.gd").is_file()


def test_modern_veilleurs_runtime_does_not_depend_on_vs001() -> None:
    for relative in (
        "scripts/core/veilleurs_production_runtime.gd",
        "scripts/core/veilleurs_vertical_slice_runtime_v09.gd",
        "scripts/core/veilleurs_vertical_slice_runtime_v08.gd",
        "scripts/core/veilleurs_campaign_runtime_v07.gd",
    ):
        text = (ROOT / relative).read_text(encoding="utf-8")
        lowered = text.lower()
        assert "vs001" not in lowered, f"modern runtime must not depend on VS001: {relative}"


def test_no_new_active_script_may_reference_vs001() -> None:
    contract = _contract()
    allowed = set(contract["allowed_active_reference_files"])
    prefixes = list(contract["legacy_path_prefixes"])
    offenders: list[str] = []

    candidates = [ROOT / "project.godot"]
    candidates.extend((ROOT / "scripts").rglob("*.gd"))

    for path in candidates:
        relative = path.relative_to(ROOT).as_posix()
        if relative in allowed or _is_legacy_owned(path, prefixes):
            continue
        text = path.read_text(encoding="utf-8")
        if any(token in text for token in LEGACY_TOKENS):
            offenders.append(relative)

    assert offenders == [], (
        "VS001 is frozen compatibility code; new active references must use "
        "VeilleursProductionRuntime/v0.9 instead: " + ", ".join(offenders)
    )


def test_save_manager_keeps_legacy_read_path_and_has_v09_path() -> None:
    text = (ROOT / "scripts/core/save_manager.gd").read_text(encoding="utf-8")
    assert '"veilleurs_vs001"' in text
    assert '"veilleurs_v09"' in text
    assert "VeilleursProductionRuntime.serialize()" in text
    assert "VeilleursProductionRuntime.deserialize" in text
