from __future__ import annotations

import json
from pathlib import Path

from tools.qa.artistic_musical_traditions_audit import audit_artistic_musical_traditions


def _copy_minimal_tree(tmp_path: Path) -> Path:
    root = Path(__file__).resolve().parents[1]
    for rel in (
        "universe/lore/artistic_musical_traditions.json",
        "docs/LITD_UNIVERSE_TRADITIONS_ARTISTIQUES_MUSICALES.md",
        "docs/LITD_UNIVERSE_PEUPLES_CULTURES_VIVANTES.md",
        "docs/LITD_UNIVERSE_SYSTEME_LINGUISTIQUE.md",
        "docs/LITD_UNIVERSE_ECOLES_MARTIALES_REGIONALES.md",
        "docs/HISTOIRE_TROIS_EVEILS.md",
        "docs/LORE_BIBLE.md",
        "docs/CONCORDE_MONDE_POLITIQUE.md",
        "docs/CIVILISATIONS_ETRANGERES_APRES_CHUTE.md",
        "docs/LITD_UNIVERSE_CREATION_PERSONNAGES.md",
        "docs/BIBLIOTHEQUE_ARTISTIQUE_MONDE.md",
        "docs/design/music_library.md",
        "data/music_library.json",
    ):
        src = root / rel
        dst = tmp_path / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
    return tmp_path


def _mutate(tmp_path: Path, mutator) -> dict:
    root = _copy_minimal_tree(tmp_path)
    path = root / "universe/lore/artistic_musical_traditions.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    mutator(data)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return audit_artistic_musical_traditions(root)


def test_artistic_musical_traditions_are_valid() -> None:
    assert audit_artistic_musical_traditions()["ok"] is True


def test_city_cannot_become_single_art_style(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["core_rules"].__setitem__("city_is_not_single_style", True))
    assert report["ok"] is False


def test_real_reference_library_cannot_become_diegetic_canon(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["real_world_reference_guardrails"].__setitem__("diegetic_canon", True))
    assert report["ok"] is False


def test_stock_music_cannot_become_world_canon(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["production_music_guardrails"].__setitem__("catalog_tracks_are_world_canon", True))
    assert report["ok"] is False


def test_signature_theme_stays_unlocked_until_approved(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["production_music_guardrails"].__setitem__("signature_theme_locked_by_this_pass", True))
    assert report["ok"] is False


def test_art_cannot_become_fourth_progression_tree(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["gameplay_rules"].__setitem__("art_is_fourth_mandatory_progression_system", True))
    assert report["ok"] is False


def test_music_cannot_mark_correct_moral_choice(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["gameplay_rules"].__setitem__("music_can_mark_morally_correct_choice", True))
    assert report["ok"] is False


def test_effrie_art_and_music_stay_unconfirmed(tmp_path: Path) -> None:
    report = _mutate(tmp_path, lambda d: d["effrie_guardrail"].__setitem__("tribe_music", "dragon_chants"))
    assert report["ok"] is False
