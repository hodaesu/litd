import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EARLY = ROOT / "data" / "canon" / "les_veilleurs_acts_1_2.json"
LATE = ROOT / "data" / "canon" / "les_veilleurs_acts_3_5.json"
ENCOUNTERS = ROOT / "data" / "canon" / "les_veilleurs_encounter_compositions.json"


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def test_full_five_act_spine_is_contiguous():
    early, late = read(EARLY), read(LATE)
    acts = early["acts"] + late["acts"]
    assert [act["id"] for act in acts] == ["I", "II", "III", "IV", "V"]
    zone_ids = [zone["id"] for act in acts for zone in act["zones"]]
    assert len(zone_ids) == len(set(zone_ids))
    assert len(zone_ids) >= 20


def test_hub_progression_is_contiguous_from_post_to_open_archive():
    early, late = read(EARLY), read(LATE)
    stages = early["hub_progression"] + late["hub_progression_continuation"]
    assert [stage["order"] for stage in stages] == list(range(13))
    assert stages[0]["id"] == "poste_de_lisiere"
    assert stages[-1]["id"] == "archive_ouverte"


def test_every_combat_reference_across_all_five_acts_exists():
    early, late, encounters = read(EARLY), read(LATE), read(ENCOUNTERS)
    known = {
        encounter["id"]
        for act in encounters["acts"]
        for encounter in act["encounters"]
    }
    linked = {
        encounter_id
        for source in [early, late]
        for act in source["acts"]
        for zone in act["zones"]
        for encounter_id in zone["combat_encounters"]
    }
    assert linked.issubset(known)


def test_all_remanence_bundles_keep_four_stage_contract():
    early, late = read(EARLY), read(LATE)
    bundles = early["remanence_bundles"] + late["remanence_bundles"]
    assert len(bundles) >= 10
    for bundle in bundles:
        for key in ["trace", "echo", "memory", "concordance"]:
            assert bundle[key]
    for bundle in late["remanence_bundles"]:
        assert bundle["source_quality"]
        assert bundle["unresolved"]


def test_act_ii_to_iii_transition_uses_existing_persistent_flags():
    early, late = read(EARLY), read(LATE)
    available = set(early["persistent_flags"])
    transition = next(item for item in late["transitions"] if item["id"] == "II_to_III")
    assert set(transition["inputs"]).issubset(available)


def test_no_late_act_claim_overwrites_core_canon_boundaries():
    late = read(LATE)
    guardrails = " ".join(late["canon_guardrails"])
    assert "Aurélien" in guardrails and "ne fait pas partie" in guardrails
    assert "Trois Éveils existent avant" in guardrails
    assert "Vestige reste inconnu" in guardrails
    assert "Projet Seuil" in guardrails
    assert "omniscience" in guardrails
    assert late["dating_policy"]["mode"] == "relative_only"


def test_remaining_late_work_is_runtime_art_or_balance_validation():
    late = read(LATE)
    completion = late["authoring_completion"]
    assert completion["acts_III_to_V_story"] == "complete_before_runtime_validation"
    pending = " ".join(late["runtime_pending"]).lower()
    for term in ["godot", "blender", "mobile", "tactile", "audio", "collisions", "animations"]:
        assert term in pending
