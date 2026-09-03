import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = ROOT / "data" / "canon" / "les_veilleurs_acts_1_2.json"


def load_data():
    return json.loads(DATA_PATH.read_text(encoding="utf-8"))


def all_zones(data):
    return [zone for act in data["acts"] for zone in act["zones"]]


def test_acts_i_ii_are_named_and_human_first():
    data = load_data()
    assert [act["id"] for act in data["acts"]] == ["I", "II"]
    zones = all_zones(data)
    assert len(zones) >= 8
    assert len({zone["id"] for zone in zones}) == len(zones)
    for zone in zones:
        assert zone["name"]
        assert zone["human_premise"]
        assert zone["gameplay_role"]
        assert "remanence_sources" in zone
        assert "hub_output" in zone


def test_relative_dating_and_era_guard_are_explicit():
    data = load_data()
    policy = data["dating_policy"]
    assert policy["mode"] == "relative_only"
    assert "Aucune année absolue" in policy["rule"]
    assert "Trois Éveils" in policy["era_guard"]
    assert "leur naissance n'est jamais rejouée" in policy["era_guard"]


def test_recruit_events_are_stateful_and_wound_aware():
    data = load_data()
    chains = data["recruit_event_chains"]
    expected = {
        "gardes_de_convoi",
        "molosses_de_convoi",
        "chirurgiens_de_releve",
        "tireurs_de_relais",
        "meneurs_de_voix",
        "sapeurs_de_passage",
        "gardiens_des_versions",
    }
    assert expected.issubset({chain["family_id"] for chain in chains})
    for chain in chains:
        assert [stage["id"] for stage in chain["stages"]] == ["encounter", "hub", "return"]
        assert chain["wound_variants"]
        for stage in chain["stages"]:
            assert stage["trigger"]
            assert stage["event"]


def test_knowledge_remanence_uses_four_stages_without_omniscience():
    data = load_data()
    bundles = data["remanence_bundles"]
    assert bundles
    for bundle in bundles:
        assert bundle["trace"]
        assert bundle["echo"]
        assert bundle["memory"]
        assert bundle["concordance"]
    manifestation = next(bundle for bundle in bundles if bundle["id"] == "manifestation_cuvette")
    assert "reste non résolue" in manifestation["concordance"]


def test_hub_growth_follows_field_consequences_not_generic_levels():
    data = load_data()
    stages = data["hub_progression"]
    assert [stage["order"] for stage in stages] == list(range(len(stages)))
    assert stages[0]["id"] == "poste_de_lisiere"
    ids = {stage["id"] for stage in stages}
    assert {"salle_de_releve", "quartier_des_rallies", "atelier_des_preuves", "atelier_de_passage"}.issubset(ids)
    for stage in stages[1:]:
        assert stage["trigger"]
        assert stage["function"]
        assert stage["choice_pressure"]


def test_combat_balance_is_explicitly_left_for_runtime_validation():
    data = load_data()
    pending = " ".join(data["runtime_pending"]).lower()
    for term in ["dégâts", "précision", "télégraphes", "cooldowns", "convalescence", "tactile", "cadavres"]:
        assert term in pending
    encoded = json.dumps(data, ensure_ascii=False).lower()
    assert '"damage":' not in encoded
    assert '"accuracy":' not in encoded
    assert '"cooldown":' not in encoded


def test_act_ii_seeds_later_institutional_themes_without_using_later_labels_as_zone_identity():
    data = load_data()
    act_ii = next(act for act in data["acts"] if act["id"] == "II")
    assert "indispensables" in act_ii["arc"]
    assert "provisoires" in act_ii["arc"]
    for zone in act_ii["zones"]:
        assert "Porte-Cendres" not in zone["name"]
        assert "Veines" not in zone["name"]


def test_manifestation_remains_functional_unknown_not_recruitable_ally():
    data = load_data()
    zone = next(zone for zone in all_zones(data) if zone["id"] == "cuvette_des_points_d_appui")
    text = json.dumps(zone, ensure_ascii=False)
    assert "structures fonctionnelles" in text
    assert "jamais par anatomie inventée" in text
    assert "coopérer temporairement" in text
    assert "Manifestation" not in " ".join(zone["recruit_hooks"])
