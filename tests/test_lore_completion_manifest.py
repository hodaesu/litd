import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CANON = ROOT / "data" / "canon"


def load(name):
    return json.loads((CANON / name).read_text(encoding="utf-8"))


def test_core_lore_spine_is_declared_complete():
    data = load("lore_completion_manifest.json")
    assert data["status"] == "core_lore_spine_locked"
    assert data["core_canon_completion"] is True
    assert "civilisations anciennes" in data["core_canon_completion_definition"]
    assert "Chute" in data["core_canon_completion_definition"]
    assert "LITD 1" in data["core_canon_completion_definition"]


def test_master_chronology_runs_from_ashai_to_litd1():
    data = load("lore_completion_manifest.json")
    chronology = data["master_chronology"]
    assert chronology[0]["event"] == "Ashaï de Nhal"
    assert chronology[-1]["event"] == "LITD 1"
    events = [entry["event"] for entry in chronology]
    for required in [
        "Première Rupture",
        "Grande Fermeture",
        "Dernière Guerre",
        "Nuit de Sarn et naissance historique des Trois Éveils",
        "Premier Pacte",
        "Fondation progressive de la Concorde",
        "Premiers Sanctuaires institutionnels",
        "Campagne de Nayra Orun, Tarek Senn, Aïsha Maren et Idris Vael",
        "Début formel du Projet Seuil",
        "Chute",
    ]:
        assert required in events


def test_all_new_core_files_are_listed_and_exist():
    data = load("lore_completion_manifest.json")
    sources = data["source_order"]
    for relative in sources:
        path = ROOT / relative
        assert path.exists(), relative
        json.loads(path.read_text(encoding="utf-8"))
    for required in [
        "data/canon/night_of_sarn.json",
        "data/canon/litd2_epilogue.json",
        "data/canon/post_sarn_concorde.json",
        "data/canon/project_threshold_and_fall.json",
        "data/canon/post_fall_litd1.json",
        "data/canon/ancient_periods_and_mysteries.json",
    ]:
        assert required in sources


def test_night_of_sarn_births_awakenings_without_supernatural_revelation():
    data = load("night_of_sarn.json")
    assert data["dating"]["year"] == -1112
    assert "ni une révélation surnaturelle" in data["core_truth"]
    birth = data["birth_of_three_awakenings"]
    assert "Trois Éveils" in birth["within_months"]
    assert "ne sont pas une religion" in birth["religion_guard"]
    formulas = data["first_formulations"]
    assert formulas["sahra"]["future_awakening"] == "Corps"
    assert formulas["ilyan"]["future_awakening"] == "Esprit"
    assert formulas["tala"]["future_awakening"] == "Politique"


def test_litd2_epilogue_keeps_triad_fallible_and_non_sacred():
    data = load("litd2_epilogue.json")
    assert all(name in json.dumps(data, ensure_ascii=False) for name in ["Sahra", "Ilyan", "Tala"])
    shared = " ".join(data["shared_after_sarn"])
    assert "refusent" in shared.lower()
    assert "Conseil permanent des Trois" in shared
    assert "se contredire" in shared
    assert "Aucune canonisation religieuse" in data["mythification"]["religion_guard"]


def test_concorde_and_sanctuaries_are_post_sarn_and_not_a_religion():
    data = load("post_sarn_concorde.json")
    dating = data["dating"]
    assert dating["night_of_sarn"] < dating["first_pact"] < 0
    assert dating["first_pact"] < dating["concorde_foundation_center"] < 0
    assert data["concorde"]["definition"]
    assert "religion" in data["concorde"]["not"]
    guardrails = " ".join(data["first_sanctuaries"]["guardrails"])
    assert "pas des temples" in guardrails
    assert "n'exigent pas une croyance métaphysique" in guardrails


def test_veilleurs_campaign_and_quartet_are_fixed_in_concorde_period():
    data = load("post_sarn_concorde.json")
    faction = data["veilleurs_faction"]
    assert faction["campaign_center"] == -842
    assert faction["canonical_quartet"] == ["Nayra Orun", "Tarek Senn", "Aïsha Maren", "Idris Vael"]
    assert "Saan" in faction["name_truth"]


def test_project_threshold_replaces_simple_external_invasion_cause():
    data = load("project_threshold_and_fall.json")
    assert data["dating"]["fall"] == 0
    assert "n'est pas provoquée par un continent extérieur" in data["core_revision"]
    assert data["external_continents"]["status"] == "partners_and_rivals_not_single_aggressor"
    truth = data["fall_author_truth"]
    assert "condition directe" in truth["necessary_condition"]
    assert "Aucune personne" in truth["no_single_culprit"]
    assert "Vestige" in truth["vestige_relation"]


def test_post_fall_litd1_is_about_reconstruction_not_empty_world():
    data = load("post_fall_litd1.json")
    assert data["dating"]["litd1_campaign_center"] == 24
    assert "pas dans un monde totalement mort" in data["core_principle"]
    assert data["litd1"]["seven_legendary_heroes"] == [
        "Aurélien", "Èffrie", "Lya", "Mathilde", "Marec", "Zejé", "Anouk"
    ]
    assert data["litd1"]["currency"] == "or"
    assert "nombreux" in data["author_truths"][1]


def test_remaining_ancient_periods_are_now_bounded():
    data = load("ancient_periods_and_mysteries.json")
    periods = {item["id"]: item for item in data["civilization_periods"]}
    for civilization in ["vaor_khal", "lyr_mar", "sahm_ir", "ydris"]:
        assert periods[civilization]["status"] == "locked_now"
        start, end = periods[civilization]["period"]
        assert start < end < 0


def test_bounded_unknowns_are_not_treated_as_missing_lore():
    manifest = load("lore_completion_manifest.json")
    mysteries = load("ancient_periods_and_mysteries.json")
    assert manifest["intentionally_bounded_unknowns"]
    assert "ne sont plus considérés" in manifest["purpose"]
    assert "n'est pas un trou de lore" in mysteries["completion_rule"]
    by_id = {item["id"]: item for item in mysteries["mysteries"]}
    for mystery_id in ["first_rupture", "dhal", "manifestations", "vestige_creator", "fall_underlying_layer"]:
        assert by_id[mystery_id]["level"] == 3
        assert by_id[mystery_id]["locked_truths"]
        assert by_id[mystery_id]["intentionally_unknown"]


def test_three_remanences_remain_distinct_across_fall():
    data = load("project_threshold_and_fall.json")
    rem = data["remanence_systems_after_fall"]
    assert set(rem) == {"knowledge", "wounds", "vestige"}
    assert "propres règles" in rem["vestige"]


def test_master_catalog_exposes_completion_and_effective_pending_topics():
    path = ROOT / "scripts" / "core" / "lore_master_catalog.gd"
    text = path.read_text(encoding="utf-8")
    for token in [
        "class_name LoreMasterCatalog",
        "static func night_of_sarn(",
        "static func litd2_epilogue(",
        "static func post_sarn_concorde(",
        "static func project_threshold_and_fall(",
        "static func post_fall_litd1(",
        "static func completion_manifest(",
        "static func core_lore_complete(",
        "static func effective_pending_lore_topics(",
    ]:
        assert token in text
    assert "still_expandable_topics()" in text
