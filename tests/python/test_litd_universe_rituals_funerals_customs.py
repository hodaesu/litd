from __future__ import annotations

import json
import shutil
from pathlib import Path

from tools.qa.rituals_funerals_customs_audit import audit_rituals_funerals_customs


ROOT = Path(__file__).resolve().parents[2]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_rituals_are_plural_and_not_a_shared_liturgy() -> None:
    data = load_json(ROOT / "universe/lore/rituals_funerals_customs.json")
    rules = data["core_rules"]
    assert rules["single_shared_concorde_liturgy"] is False
    assert rules["ritual_is_automatically_religious"] is False
    assert rules["single_funeral_method"] is False
    assert rules["single_confederal_calendar"] is False
    assert rules["local_and_religious_variation_is_normal"] is True


def test_return_the_name_and_distributed_memory_are_canon() -> None:
    data = load_json(ROOT / "universe/lore/rituals_funerals_customs.json")
    funerals = data["funerary_principles"]
    assert funerals["return_the_name"]["canonical_principle"] is True
    assert funerals["return_the_name"]["invent_missing_identity"] is False
    assert funerals["return_the_name"]["body_required_for_memorial"] is False
    memory = funerals["memory_distribution"]
    assert memory["shared_memorial_allowed"] is True
    assert memory["local_memorial_allowed"] is True
    assert memory["centralization_required"] is False


def test_sarn_is_commemoration_not_victory_festival() -> None:
    data = load_json(ROOT / "universe/lore/rituals_funerals_customs.json")
    sarn = data["sarn_commemorations"]
    assert sarn["exist"] is True
    assert sarn["victory_festival"] is False
    assert sarn["single_confederal_holiday"] is False
    assert sarn["transmit_hereditary_guilt"] is False


def test_three_awakenings_passages_stay_civic_and_local() -> None:
    data = load_json(ROOT / "universe/lore/rituals_funerals_customs.json")
    passage = data["three_awakenings_passage_ceremonies"]
    assert passage["exist_in_mature_concorde"] is True
    assert passage["religious_by_default"] is False
    assert passage["single_continental_name"] is False
    assert passage["single_required_age"] is False
    assert passage["magical_initiation"] is False


def test_post_fall_ritual_gameplay_does_not_undo_permadeath() -> None:
    data = load_json(ROOT / "universe/lore/rituals_funerals_customs.json")
    gameplay = data["gameplay"]
    assert gameplay["universal_ritual_meter"] is False
    assert gameplay["universal_hope_bonus_per_funeral"] is False
    assert gameplay["generic_resurrection_rite"] is False
    assert gameplay["litd1_permadeath_reversed"] is False
    chronology = {item["era"]: item for item in data["chronology"]}
    assert "persistent_corpses" in chronology["litd1_post_fall"]["features"]


def test_current_ritual_audit_passes() -> None:
    report = audit_rituals_funerals_customs(ROOT)
    assert report["ok"], report


def test_audit_rejects_universal_funeral_method(tmp_path: Path) -> None:
    shutil.copytree(ROOT / "universe", tmp_path / "universe")
    shutil.copytree(ROOT / "docs", tmp_path / "docs")
    data_path = tmp_path / "universe/lore/rituals_funerals_customs.json"
    data = load_json(data_path)
    data["core_rules"]["single_funeral_method"] = True
    data_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report = audit_rituals_funerals_customs(tmp_path)
    assert not report["ok"]
    assert any("single_funeral_method" in error for error in report["errors"]), report


def test_audit_rejects_invented_name_for_unknown_dead(tmp_path: Path) -> None:
    shutil.copytree(ROOT / "universe", tmp_path / "universe")
    shutil.copytree(ROOT / "docs", tmp_path / "docs")
    data_path = tmp_path / "universe/lore/rituals_funerals_customs.json"
    data = load_json(data_path)
    data["funerary_principles"]["return_the_name"]["invent_missing_identity"] = True
    data_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report = audit_rituals_funerals_customs(tmp_path)
    assert not report["ok"]
    assert any("nom inconnu" in error.lower() for error in report["errors"]), report


def test_audit_rejects_effrie_rites_being_silently_locked(tmp_path: Path) -> None:
    shutil.copytree(ROOT / "universe", tmp_path / "universe")
    shutil.copytree(ROOT / "docs", tmp_path / "docs")
    religion_path = tmp_path / "universe/lore/religions_beliefs.json"
    religion = load_json(religion_path)
    religion["effrie"]["rites"] = "dragon_fire_funeral"
    religion_path.write_text(json.dumps(religion, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report = audit_rituals_funerals_customs(tmp_path)
    assert not report["ok"]
    assert any("èffrie" in error.lower() for error in report["errors"]), report
