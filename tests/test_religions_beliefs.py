from __future__ import annotations

import json
from pathlib import Path

from tools.qa.religions_beliefs_audit import audit_religions_beliefs


def _copy_minimal_tree(tmp_path: Path) -> Path:
    root = Path(__file__).resolve().parents[1]
    for rel in (
        "universe/lore/religions_beliefs.json",
        "docs/LITD_UNIVERSE_RELIGIONS_CROYANCES.md",
        "docs/LORE_BIBLE.md",
        "docs/HISTOIRE_TROIS_EVEILS.md",
        "docs/LITD_UNIVERSE_PEUPLES_CULTURES_VIVANTES.md",
        "docs/LITD_UNIVERSE_REGLE_COHERENCE_NARRATIVE.md",
    ):
        src = root / rel
        dst = tmp_path / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
    return tmp_path


def _mutate(tmp_path: Path, mutator) -> dict:
    root = _copy_minimal_tree(tmp_path)
    path = root / "universe/lore/religions_beliefs.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    mutator(data)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return audit_religions_beliefs(root)


def test_religions_beliefs_are_valid() -> None:
    assert audit_religions_beliefs()["ok"] is True


def test_three_awakenings_cannot_become_religion(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["core_rules"].__setitem__("three_awakenings_are_religion", True))
    assert report["ok"] is False


def test_supernatural_effect_cannot_prove_theology(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["core_rules"].__setitem__("supernatural_effect_proves_theology", True))
    assert report["ok"] is False


def test_concorde_cannot_gain_single_official_theology(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["concorde_mature"].__setitem__("official_confederal_theology", True))
    assert report["ok"] is False


def test_azravel_cannot_become_monolithic(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["azravel"].__setitem__("internal_plurality", ["sincere_believers"]))
    assert report["ok"] is False


def test_veil_cannot_be_declared_afterlife_without_evidence(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["veil_and_supernatural"].__setitem__("veil_is_confirmed_afterlife", True))
    assert report["ok"] is False


def test_raised_dead_cannot_prove_soul_return(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["veil_and_supernatural"].__setitem__("raised_dead_prove_soul_return", True))
    assert report["ok"] is False


def test_effrie_legacy_pact_cannot_override_current_canon(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["effrie"].__setitem__("pact", "canonical_dragon_pact"))
    assert report["ok"] is False


def test_religion_cannot_add_faith_meter(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["gameplay"].__setitem__("universal_faith_meter", True))
    assert report["ok"] is False


def test_music_cannot_confirm_divine_moral_approval(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["staging"].__setitem__("music_or_light_confirms_divine_moral_approval", True))
    assert report["ok"] is False
