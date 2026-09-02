from __future__ import annotations

import json
from pathlib import Path

from tools.qa.language_system_audit import audit_language_system


def _copy_minimal_tree(tmp_path: Path) -> Path:
    root = Path(__file__).resolve().parents[1]
    for rel in (
        "universe/lore/language_system.json",
        "docs/LITD_UNIVERSE_SYSTEME_LINGUISTIQUE.md",
        "docs/LITD_UNIVERSE_PEUPLES_CULTURES_VIVANTES.md",
        "docs/LORE_BIBLE.md",
        "docs/HISTOIRE_TROIS_EVEILS.md",
        "docs/CONCORDE_MONDE_POLITIQUE.md",
        "docs/CIVILISATIONS_ETRANGERES_APRES_CHUTE.md",
        "docs/LITD_UNIVERSE_CREATION_PERSONNAGES.md",
        "docs/LITD1_DECISIONS_SEPT_TRAME_DRAGONS.md",
    ):
        src = root / rel
        dst = tmp_path / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
    return tmp_path


def _mutate(tmp_path: Path, mutator) -> dict:
    root = _copy_minimal_tree(tmp_path)
    path = root / "universe/lore/language_system.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    mutator(data)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return audit_language_system(root)


def test_language_system_is_valid() -> None:
    assert audit_language_system()["ok"] is True


def test_contact_register_cannot_replace_local_languages(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["contact_register"].__setitem__("replaces_local_languages", True))
    assert report["ok"] is False


def test_main_plot_cannot_be_permanently_language_locked(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["gameplay_rules"].__setitem__("critical_information_can_be_permanently_blocked_by_language", True))
    assert report["ok"] is False


def test_language_cannot_grant_intrinsic_combat_stats(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["identity_rules"].__setitem__("language_has_no_intrinsic_combat_stats", False))
    assert report["ok"] is False


def test_ancient_language_descent_cannot_be_invented(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["ancient_language_guardrails"].__setitem__("ashai_direct_ancestor", "confirmed"))
    assert report["ok"] is False


def test_effrie_tribe_language_stays_unconfirmed(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["effrie_guardrail"].__setitem__("tribe_language", "dragon_tongue"))
    assert report["ok"] is False
