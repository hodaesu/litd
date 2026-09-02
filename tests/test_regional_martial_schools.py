from __future__ import annotations

import json
from pathlib import Path

from tools.qa.regional_martial_schools_audit import audit_regional_martial_schools


def _copy_minimal_tree(tmp_path: Path) -> Path:
    root = Path(__file__).resolve().parents[1]
    for rel in (
        "universe/lore/regional_martial_schools.json",
        "docs/LITD_UNIVERSE_ECOLES_MARTIALES_REGIONALES.md",
        "docs/HISTOIRE_TROIS_EVEILS.md",
        "docs/LITD_UNIVERSE_TROIS_FONDATEURS_CANON.md",
        "docs/CONCORDE_MONDE_POLITIQUE.md",
        "docs/CIVILISATIONS_ETRANGERES_APRES_CHUTE.md",
        "docs/LITD_UNIVERSE_PEUPLES_CULTURES_VIVANTES.md",
        "docs/LITD_UNIVERSE_SYSTEME_LINGUISTIQUE.md",
        "docs/LITD_UNIVERSE_CREATION_PERSONNAGES.md",
        "docs/LORE_BIBLE.md",
    ):
        src = root / rel
        dst = tmp_path / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
    return tmp_path


def _mutate(tmp_path: Path, mutator) -> dict:
    root = _copy_minimal_tree(tmp_path)
    path = root / "universe/lore/regional_martial_schools.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    mutator(data)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return audit_regional_martial_schools(root)


def test_regional_martial_schools_are_valid() -> None:
    assert audit_regional_martial_schools()["ok"] is True


def test_school_cannot_become_ethnicity(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["core_rules"].__setitem__("school_is_not_ethnicity", False))
    assert report["ok"] is False


def test_schools_cannot_become_extra_skill_trees(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["core_rules"].__setitem__("schools_add_separate_skill_trees", True))
    assert report["ok"] is False


def test_mature_schools_cannot_exist_in_litd2(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["chronology"][0].__setitem__("mature_six_schools_exist", True))
    assert report["ok"] is False


def test_khen_breath_cannot_become_magic(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["khen_breath"].__setitem__("is_magic", True))
    assert report["ok"] is False


def test_gore_cannot_become_school_bonus(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["body_consequence_rules"].__setitem__("gore_bonus_by_school", True))
    assert report["ok"] is False


def test_effrie_martial_practice_stays_unconfirmed(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["effrie_guardrail"].__setitem__("tribe_martial_practice", "dragon_style"))
    assert report["ok"] is False
