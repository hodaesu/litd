import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = ROOT / "data" / "canon" / "les_veilleurs_quartet.json"


def load_data():
    return json.loads(DATA_PATH.read_text(encoding="utf-8"))


def by_id(data, character_id):
    return next(character for character in data["characters"] if character["id"] == character_id)


def test_exact_canonical_quartet_and_party_size():
    data = load_data()
    contract = data["party_contract"]
    assert contract["main_party_size"] == 4
    assert contract["exact_ids"] == ["V01", "V02", "V03", "V04"]
    assert contract["exact_names"] == ["Nayra Orun", "Tarek Senn", "Aïsha Maren", "Idris Vael"]
    assert [character["name"] for character in data["characters"]] == contract["exact_names"]


def test_aurelien_and_obsolete_quartet_are_excluded():
    data = load_data()
    names = {character["name"] for character in data["characters"]}
    assert "Aurélien" not in names
    for obsolete in ["Sahen Varo", "Mira Sen", "Narem Osh", "Ysra Nahal"]:
        assert obsolete not in names
    rules = " ".join(data["rules"])
    assert "Aurélien" in rules
    assert "ne fait pas partie" in rules
    assert all(name in rules for name in ["Sahen Varo", "Mira Sen", "Narem Osh", "Ysra Nahal"])


def test_nayra_guard_contract():
    data = load_data()
    nayra = by_id(data, "V01")
    assert nayra["name"] == "Nayra Orun"
    assert nayra["title"] == "La Garde"
    assert nayra["personal_mechanic"]["name"] == "Détermination"
    assert nayra["skill_trees"] == ["Bastion", "Brisure", "Serment"]
    assert nayra["ultimates"] == ["La Ligne ne rompt pas", "Le Poids du Mur", "Pas un de plus"]
    assert nayra["age"] is None
    assert nayra["age_status"] == "not_locked_here"


def test_tarek_pisteur_contract_and_age():
    data = load_data()
    tarek = by_id(data, "V02")
    assert tarek["name"] == "Tarek Senn"
    assert tarek["title"] == "Le Pisteur"
    assert tarek["age"] == 29
    assert tarek["personal_mechanic"]["name"] == "Traque"
    assert tarek["personal_mechanic"]["levels"] == [
        "0 — Inconnue", "1 — Observation", "2 — Anticipation", "3 — Exploitation"
    ]
    assert tarek["skill_trees"] == ["Traque", "Entaille", "Disparition"]
    assert tarek["ultimates"] == ["JE SAIS OÙ TU VAS", "MILLE COUPURES", "TU M’AVAIS PERDU"]
    assert "pas un scan magique" in tarek["personal_mechanic"]["gain_rule"]


def test_aisha_anatomist_contract_without_invented_age():
    data = load_data()
    aisha = by_id(data, "V03")
    assert aisha["name"] == "Aïsha Maren"
    assert aisha["title"] == "L'Anatomiste"
    assert aisha["age"] is None
    assert aisha["age_status"] == "not_locked_here"
    assert aisha["personal_mechanic"]["name"] == "Diagnostic"
    assert aisha["personal_mechanic"]["levels"] == [
        "0 — Inconnu", "I — Observation", "II — Examen", "III — Cartographie"
    ]
    assert aisha["skill_trees"] == ["Anatomie", "Suture", "Hémocorde"]
    assert aisha["ultimates"] == [
        "Carte parfaite du vivant", "Tout ce qui peut être sauvé", "Le dernier battement"
    ]
    assert "ne révèle pas une anatomie inconnue par magie" in aisha["personal_mechanic"]["gain_rule"]


def test_idris_mediator_contract_without_invented_age():
    data = load_data()
    idris = by_id(data, "V04")
    assert idris["name"] == "Idris Vael"
    assert idris["title"] == "Le Médiateur"
    assert idris["age"] is None
    assert idris["age_status"] == "not_locked_here"
    assert idris["personal_mechanic"]["name"] == "Autorité"
    assert idris["personal_mechanic"]["linked_axis"] == "Concorde"
    assert idris["skill_trees"] == ["Sentence", "Concorde", "Dissidence"]
    assert idris["ultimates"] == ["Le verdict tombe", "Un seul mouvement", "Que l’ordre se brise"]
    assert "ni charme magique ni contrôle mental" in idris["personal_mechanic"]["gain_rule"]


def test_every_character_has_five_act_hooks_and_narrative_pressure():
    data = load_data()
    for character in data["characters"]:
        assert list(character["five_act_hooks"].keys()) == ["I", "II", "III", "IV", "V"]
        assert all(character["five_act_hooks"][act] for act in ["I", "II", "III", "IV", "V"])
        assert character["narrative_pressure"]


def test_skill_tree_and_ultimate_targets_are_explicit():
    data = load_data()
    contract = data["party_contract"]
    assert contract["skills_per_character_target"] == 45
    assert contract["trees_per_character"] == 3
    assert contract["skills_per_tree_target"] == 15
    assert contract["ultimates_per_character"] == 3
    for character in data["characters"]:
        assert len(character["skill_trees"]) == 3
        assert len(character["ultimates"]) == 3


def test_relationships_are_not_invented_and_runtime_work_remains_measured():
    data = load_data()
    assert data["party_contract"]["interpersonal_relationships_status"] == (
        "preserve_existing_only_do_not_invent_new_canon_here"
    )
    pending = " ".join(data["runtime_pending"]).lower()
    for term in ["tactile", "clavier", "souris", "manette", "animations", "vfx", "blessures", "équilibrage"]:
        assert term in pending
