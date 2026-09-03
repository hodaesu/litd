import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = ROOT / "data" / "canon" / "les_veilleurs_acts_3_5.json"
ENCOUNTERS_PATH = ROOT / "data" / "canon" / "les_veilleurs_encounter_compositions.json"


def load_data():
    return json.loads(DATA_PATH.read_text(encoding="utf-8"))


def all_zones(data):
    return [zone for act in data["acts"] for zone in act["zones"]]


def test_acts_iii_v_are_complete_human_first_and_named():
    data = load_data()
    assert [act["id"] for act in data["acts"]] == ["III", "IV", "V"]
    assert [act["title"] for act in data["acts"]] == ["Les Veines", "Porte-Cendres", "Ce que nous transmettons"]
    zones = all_zones(data)
    assert len(zones) == 12
    assert len({zone["id"] for zone in zones}) == 12
    for zone in zones:
        assert zone["human_premise"]
        assert zone["combat_encounters"]
        assert zone["noncombat_encounters"]
        assert zone["body_and_corpse_use"]
        assert zone["remanence_sources"]
        assert zone["hub_output"]


def test_transition_from_act_ii_to_veins_is_explicit():
    data = load_data()
    transitions = data["transitions"]
    assert [(item["from"], item["to"]) for item in transitions] == [("II", "III"), ("III", "IV"), ("IV", "V")]
    first = transitions[0]
    assert "fonctions invisibles" in first["revelation"]
    assert {"a2_both_orders_preserved", "a2_specialist_relieved", "a2_neutral_care_protected"}.issubset(first["inputs"])


def test_all_late_act_combat_links_exist_in_encounter_catalog():
    data = load_data()
    encounter_data = json.loads(ENCOUNTERS_PATH.read_text(encoding="utf-8"))
    encounter_ids = {
        encounter["id"]
        for act in encounter_data["acts"]
        if act["act"] in {"III", "IV", "V"}
        for encounter in act["encounters"]
    }
    linked = {encounter_id for zone in all_zones(data) for encounter_id in zone["combat_encounters"]}
    assert linked == encounter_ids


def test_noncombat_catalog_covers_every_zone():
    data = load_data()
    catalog = {item["id"]: item for item in data["noncombat_encounters"]}
    assert len(catalog) == 12
    for zone in all_zones(data):
        for encounter_id in zone["noncombat_encounters"]:
            assert encounter_id in catalog
            assert catalog[encounter_id]["premise"]
            assert len(catalog[encounter_id]["choices"]) >= 3


def test_remanence_preserves_uncertainty_and_source_quality():
    data = load_data()
    bundles = data["remanence_bundles"]
    assert len(bundles) >= 6
    assert {bundle["act"] for bundle in bundles} == {"III", "IV", "V"}
    for bundle in bundles:
        assert bundle["trace"]
        assert bundle["echo"]
        assert bundle["memory"]
        assert bundle["concordance"]
        assert bundle["source_quality"]
        assert bundle["unresolved"]
    encoded = json.dumps(bundles, ensure_ascii=False).lower()
    assert "omniscient" not in encoded


def test_hub_continues_act_i_ii_order_without_generic_levels():
    data = load_data()
    stages = data["hub_progression_continuation"]
    assert [stage["order"] for stage in stages] == list(range(6, 13))
    assert stages[-1]["id"] == "archive_ouverte"
    for stage in stages:
        assert stage["trigger"]
        assert stage["function"]
        assert stage["choice_pressure"]


def test_recruit_extensions_do_not_force_recruitability():
    data = load_data()
    extensions = data["recruit_event_extensions"]
    assert extensions
    for extension in extensions:
        assert extension["availability"] == "only_if_recruitable_in_recruitment_catalog"
        assert len(extension["stages"]) == 3


def test_copiste_finale_supports_revision_not_omniscience():
    data = load_data()
    finale = data["finale"]
    assert "jamais entité omnisciente" in finale["copiste_role"]
    assert {state["id"] for state in finale["ending_states"]} == {
        "archive_unifiee", "corpus_contradictoire", "concordance_revisable"
    }
    guardrails = " ".join(data["canon_guardrails"])
    assert "Aurélien" in guardrails
    assert "Vestige reste inconnu" in guardrails
    assert "Trois Éveils" in guardrails
    assert "Rémanence de la connaissance" in guardrails
    assert "omniscience" in guardrails


def test_runtime_numbers_and_device_validation_remain_pending():
    data = load_data()
    pending = " ".join(data["runtime_pending"]).lower()
    for term in ["dégâts", "précision", "cooldowns", "télégraphes", "mobile", "tactile", "manette", "godot", "blender", "audio"]:
        assert term in pending
    encoded = json.dumps(data, ensure_ascii=False).lower()
    assert '"damage":' not in encoded
    assert '"accuracy":' not in encoded
    assert '"cooldown":' not in encoded
