from __future__ import annotations

import json
import shutil
from pathlib import Path

from tools.qa.living_cultures_audit import audit_living_cultures


ROOT = Path(__file__).resolve().parents[2]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_living_cultures_audit_passes() -> None:
    report = audit_living_cultures(ROOT)
    assert report["ok"], report


def test_living_cultures_required_groups_are_present() -> None:
    data = load_json(ROOT / "universe/lore/living_cultures.json")
    cultures = {item["id"]: item for item in data["cultures"]}
    assert set(cultures) == {
        "culture.concorde_common",
        "culture.jian_lu",
        "culture.sorye",
        "culture.dhor_khal",
        "culture.lhaor",
        "culture.tessen",
        "culture.orun_sai",
        "culture.varkhane",
        "culture.namar",
        "culture.azravel",
        "culture.kor_em",
        "culture.effrie_dragon_tribe",
    }
    assert cultures["culture.jian_lu"]["kind"] == "civic"
    assert cultures["culture.varkhane"]["kind"] == "imperial"
    assert cultures["culture.effrie_dragon_tribe"]["kind"] == "tribal"


def test_language_diversity_is_not_flattened() -> None:
    data = load_json(ROOT / "universe/lore/living_cultures.json")
    policy = data["language_policy"]
    assert policy["world_multilingual"] is True
    assert policy["concorde_single_common_language"] == "unconfirmed"
    assert policy["named_language_families"] == "unconfirmed"

    cultures = {item["id"]: item for item in data["cultures"]}
    assert "polyglotte" in cultures["culture.jian_lu"]["language"].lower()
    assert "traduction" in cultures["culture.orun_sai"]["language"].lower()
    assert "propres langues" in cultures["culture.varkhane"]["language"].lower()


def test_three_awakenings_are_not_a_religion() -> None:
    data = load_json(ROOT / "universe/lore/living_cultures.json")
    cultures = {item["id"]: item for item in data["cultures"]}
    concorde = cultures["culture.concorde_common"]
    assert "sans constituer une religion" in concorde["three_awakenings_relation"].lower()
    assert "pluralité religieuse" in concorde["religion"].lower()


def test_effrie_dragon_tribe_keeps_unknowns_open() -> None:
    data = load_json(ROOT / "universe/lore/living_cultures.json")
    cultures = {item["id"]: item for item in data["cultures"]}
    tribe = cultures["culture.effrie_dragon_tribe"]
    assert tribe["name"] == "Tribu d'Èffrie liée aux dragons"
    assert tribe["scope"] == "unknown"
    assert tribe["language"] == "unconfirmed"
    guardrails = " ".join(tribe["guardrails"]).lower()
    assert "aucun pacte ancestral" in guardrails
    assert "aucune ascendance draconique" in guardrails
    assert "aucun lien au voile" in guardrails


def test_ancient_cultures_do_not_create_automatic_ethnic_descendants() -> None:
    data = load_json(ROOT / "universe/lore/living_cultures.json")
    heritage = {item["id"]: item for item in data["ancient_heritage_sources"]}
    assert heritage["heritage.ashai"]["direct_modern_ethnic_descendants"] == "unconfirmed"
    assert heritage["heritage.or_silex"]["direct_modern_ethnic_descendants"] == "unconfirmed"
    assert heritage["heritage.saan"]["direct_modern_ethnic_descendants"] == "unconfirmed"
    assert heritage["heritage.outer_ancients"]["direct_legal_or_moral_continuity_to_modern_regimes"] is False


def test_cross_game_cultural_remanence_has_both_major_bridges() -> None:
    data = load_json(ROOT / "universe/lore/living_cultures.json")
    chains = {item["id"]: item for item in data["cross_game_remanence"]}
    assert chains["remanence.litd2_to_veilleurs.culture"]["from"] == "litd2"
    assert chains["remanence.litd2_to_veilleurs.culture"]["to"] == "litd_veilleurs"
    assert chains["remanence.veilleurs_to_litd1.culture"]["from"] == "litd_veilleurs"
    assert chains["remanence.veilleurs_to_litd1.culture"]["to"] == "litd1"
    assert "Aucune extension vers LITD2 ou Les Veilleurs" in chains["remanence.dragons_to_litd1"]["guardrail"]


def test_audit_rejects_invented_common_language(tmp_path: Path) -> None:
    shutil.copytree(ROOT / "universe", tmp_path / "universe")
    shutil.copytree(ROOT / "docs", tmp_path / "docs")

    path = tmp_path / "universe/lore/living_cultures.json"
    data = load_json(path)
    data["language_policy"]["concorde_single_common_language"] = "Langue de Concorde"
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    report = audit_living_cultures(tmp_path)
    assert not report["ok"]
    assert any("langue commune unique" in error.lower() for error in report["errors"]), report


def test_audit_rejects_invented_ashai_descendants(tmp_path: Path) -> None:
    shutil.copytree(ROOT / "universe", tmp_path / "universe")
    shutil.copytree(ROOT / "docs", tmp_path / "docs")

    path = tmp_path / "universe/lore/living_cultures.json"
    data = load_json(path)
    for item in data["ancient_heritage_sources"]:
        if item["id"] == "heritage.ashai":
            item["direct_modern_ethnic_descendants"] = "people.modern_ashai"
            break
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    report = audit_living_cultures(tmp_path)
    assert not report["ok"]
    assert any("descendance ethnique moderne inventée" in error.lower() for error in report["errors"]), report


def test_audit_rejects_invented_dragon_pact(tmp_path: Path) -> None:
    shutil.copytree(ROOT / "universe", tmp_path / "universe")
    shutil.copytree(ROOT / "docs", tmp_path / "docs")

    path = tmp_path / "universe/lore/living_cultures.json"
    data = load_json(path)
    for culture in data["cultures"]:
        if culture["id"] == "culture.effrie_dragon_tribe":
            culture["guardrails"] = [
                "Nom de la tribu non confirmé.",
                "Territoire non confirmé.",
                "Date de l'harmonie avec les dragons non confirmée.",
                "Un pacte ancestral est confirmé.",
                "Aucune ascendance draconique n'est confirmée.",
                "Aucun lien au Voile n'est confirmé."
            ]
            break
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    report = audit_living_cultures(tmp_path)
    assert not report["ok"]
    assert any("garde-fou draconique absent" in error.lower() for error in report["errors"]), report
