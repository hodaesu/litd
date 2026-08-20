from __future__ import annotations

import json
from pathlib import Path

from tools.voice.openvoice_v2_pipeline import build_plan

ROOT = Path(__file__).resolve().parents[2]


def _load(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def test_voice_production_contract_is_offline_and_rights_gated() -> None:
    production = _load("data/voice_production.json")
    engine = production["engine"]
    rules = production["rules"]

    assert engine["id"] == "openvoice_v2"
    assert engine["language"] == "FR"
    assert engine["openvoice_pinned_commit"] == "74a1d147b17a8c3092dd5430504bd83ef6c7eb23"
    assert engine["melotts_pinned_commit"] == "209145371cff8fc3bd60d7be902ea69cbdb7965a"
    assert rules["runtime_generation_in_game"] is False
    assert rules["authored_text_only"] is True
    assert rules["explicit_consent_record_required"] is True
    assert rules["reference_voice_must_be_original_or_authorized"] is True
    assert rules["celebrity_or_actor_imitation_forbidden"] is True
    assert rules["human_review_required_before_ingest"] is True


def test_generation_plan_covers_all_mortal_authored_lines() -> None:
    dialogues = _load("data/reactive_dialogues.json")
    demo = _load("data/demo_content_pack.json")
    reactive_mortal = [
        line
        for line in dialogues["lines"]
        if line.get("speaker_id") not in {"", "narrator"}
    ]
    demo_mortal = [
        line
        for line in demo["dialogue_barks"]
        if line.get("speaker") not in {"", "narration"}
    ]
    expected_ids = {line["id"] for line in reactive_mortal} | {line["id"] for line in demo_mortal}
    plan = build_plan(ROOT)

    assert plan["entry_count"] == len(expected_ids)
    assert plan["entry_count"] >= 40
    by_id = {entry["line_id"]: entry for entry in plan["entries"]}
    assert set(by_id) == expected_ids

    for entry in plan["entries"]:
        assert len(entry["text_sha256"]) == 64
        assert entry["render_path"].startswith("build/voice_rendered/")
        assert entry["shipping_path"].startswith("assets/audio/voices/")
        assert entry["shipping_path"].endswith(".wav")
        assert entry["reference_id"].endswith("_voice_reference")
        assert 0.65 <= float(entry["delivery"]["speed"]) <= 1.25
        assert entry["delivery"]["direction"]
        assert entry["voice_direction"]["emotion"]
        assert entry["voice_direction"]["backend_controls"]["directly_applied"] == ["speed"]


def test_fourth_wall_delivery_gets_quieter_not_more_showy() -> None:
    plan = build_plan(ROOT)
    by_id = {entry["line_id"]: entry for entry in plan["entries"]}

    assert float(by_id["fw_dar_abyss_02"]["delivery"]["speed"]) < float(
        by_id["fw_dar_fissure_01"]["delivery"]["speed"]
    )
    assert "pas d'effet horrifique démonstratif" in by_id["fw_dar_abyss_02"]["delivery"]["direction"]
    assert "présence incertaine" in by_id["fw_lys_direct_01"]["delivery"]["direction"]


def test_shipping_manifest_starts_empty_and_safe() -> None:
    manifest = _load("data/voice_assets.json")
    assert manifest["engine"] == "openvoice_v2"
    assert manifest["assets"] == []


def test_reference_registry_example_cannot_accidentally_authorize_a_voice() -> None:
    example = _load("docs/templates/voice_reference_registry.example.json")
    assert example["references"]
    for reference in example["references"]:
        assert reference["consent_confirmed"] is False
        assert reference["original_or_authorized"] is False
        assert reference["commercial_game_use"] is False
