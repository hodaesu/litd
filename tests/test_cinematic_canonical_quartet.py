import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_cinematic_proxemics_use_only_canonical_quartet() -> None:
    data = json.loads((ROOT / "data" / "relationship_proxemics.json").read_text(encoding="utf-8"))
    pairs = set(data["pair_defaults"])
    assert pairs == {
        "mathilde:aurelien",
        "mathilde:marec",
        "mathilde:anouk",
        "aurelien:marec",
        "aurelien:anouk",
        "marec:anouk",
    }

    serialized = json.dumps(data, ensure_ascii=False).lower()
    for legacy_name in ("darius", "malvor", "lysandra"):
        assert legacy_name not in serialized


def test_cinematic_smoke_targets_current_canon() -> None:
    smoke = (ROOT / "scripts" / "core" / "cinematic_direction_smoke_test.gd").read_text(encoding="utf-8")
    assert 'physical_profile("mathilde")' in smoke
    assert 'proxemic_pair("mathilde:aurelien")' in smoke
    assert 'dialogue_scene("demo_mathilde_ghoul_01")' in smoke
    for legacy_name in ("darius", "malvor", "lysandra"):
        assert legacy_name not in smoke.lower()
