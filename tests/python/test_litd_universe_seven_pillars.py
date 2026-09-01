import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PILLARS_PATH = ROOT / "litd_universe" / "seven_pillars.json"
CANON_PATH = ROOT / "litd_universe" / "SEVEN_PILLARS.md"
README_PATH = ROOT / "litd_universe" / "README.md"

EXPECTED_IDS = [
    "CHARACTER_CREATION",
    "SYSTEMIC_GORE_AND_BODILY_CONSEQUENCES",
    "PHILOSOPHY_AND_PSYCHOLOGY_IN_NARRATIVE",
    "ACCESSIBLE_HUMAN_DEPTH",
    "STRONG_NARRATIVE",
    "INTERCONNECTION_BETWEEN_GAMES",
    "KNOWLEDGE_REMANENCE",
]

EXPECTED_NAMES = [
    "Création de personnages",
    "Gore systémique et conséquences corporelles",
    "Philosophie et psychologie dans la narration",
    "Profondeur humaine accessible",
    "Narration forte",
    "Interconnexion des différents jeux",
    "Rémanence de la connaissance",
]


def load_pillars() -> dict:
    return json.loads(PILLARS_PATH.read_text(encoding="utf-8"))


def test_litd_universe_has_exactly_the_seven_immutable_pillars() -> None:
    data = load_pillars()
    assert data["status"] == "CANON_IMMUTABLE"
    assert data["immutable"] is True
    assert len(data["pillars"]) == 7
    assert [pillar["order"] for pillar in data["pillars"]] == list(range(1, 8))
    assert [pillar["id"] for pillar in data["pillars"]] == EXPECTED_IDS
    assert [pillar["name_fr"] for pillar in data["pillars"]] == EXPECTED_NAMES


def test_pillars_apply_to_every_litd_game_generation() -> None:
    data = load_pillars()
    assert data["applies_to"] == ["LITD_1", "LITD_2", "FUTURE_LITD_PROJECTS"]


def test_mutation_policy_forbids_changing_the_pillar_list() -> None:
    policy = load_pillars()["mutation_policy"]
    assert policy["allow_rename"] is False
    assert policy["allow_reorder"] is False
    assert policy["allow_remove"] is False
    assert policy["allow_merge"] is False
    assert policy["allow_add_eighth_pillar"] is False
    assert policy["game_specific_expression_may_vary"] is True
    assert policy["narrative_coherence_is_transversal_rule_not_pillar"] is True


def test_knowledge_remanence_keeps_canonical_progression() -> None:
    seventh = load_pillars()["pillars"][6]
    assert seventh["id"] == "KNOWLEDGE_REMANENCE"
    assert seventh["canonical_progression"] == ["Trace", "Écho", "Mémoire", "Concordance"]
    assert seventh["preserve_sources"] is True
    assert seventh["preserve_contradictions"] is True
    assert seventh["preserve_open_questions"] is True


def test_human_canon_and_root_readme_repeat_exact_pillars() -> None:
    canon = CANON_PATH.read_text(encoding="utf-8")
    readme = README_PATH.read_text(encoding="utf-8")
    for index, name in enumerate(EXPECTED_NAMES, start=1):
        assert f"{index}. **{name}**" in canon
        assert f"{index}. **{name}**" in readme

    assert "cohérence narrative" in canon.lower()
    assert "n'est pas un huitième pilier" in canon
