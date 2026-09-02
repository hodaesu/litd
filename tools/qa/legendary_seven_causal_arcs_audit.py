from __future__ import annotations

import itertools
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ARCS_PATH = ROOT / "universe/lore/legendary_seven_relationship_causal_arcs.json"
REL_PATH = ROOT / "universe/lore/legendary_seven_relationships.json"
FORMATION_PATH = ROOT / "universe/lore/legendary_seven_formation.json"

REQUIRED_STAGES = ["opening", "friction", "rupture", "repair", "durable", "bereavement"]
SEVEN = {
    "hero.aurelien",
    "hero.effrie",
    "hero.lya",
    "hero.mathilde",
    "hero.marec",
    "hero.zeje",
    "hero.anouk",
}


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def run() -> None:
    arcs = _load(ARCS_PATH)
    rel = _load(REL_PATH)
    formation = _load(FORMATION_PATH)

    rules = arcs["rules"]
    assert rules["pair_count"] == 21
    assert rules["reuse_existing_stages"] == REQUIRED_STAGES
    assert rules["no_new_relationship_meter"] is True
    assert rules["no_automatic_romance"] is True
    assert rules["rupture_requires_prior_friction_memory"] is True
    assert rules["rupture_requires_concrete_consequence"] is True
    assert rules["repair_not_guaranteed"] is True
    assert rules["repair_requires_new_event_and_cost"] is True
    assert rules["repair_never_erases_history"] is True
    assert rules["durable_does_not_mean_agreement"] is True
    assert rules["bereavement_can_interrupt_any_stage"] is True
    assert rules["dead_hero_never_speaks"] is True
    assert rules["no_posthumous_reconciliation"] is True
    assert rules["remanence_forward_only"] is True
    assert rules["backward_causation"] is False
    assert rules["runtime_implementation_deferred_until_playtest"] is True

    canon_pairs = {item["id"]: tuple(item["heroes"]) for item in rel["pairs"]}
    arc_pairs = {item["pair_id"]: item for item in arcs["arcs"]}
    assert len(canon_pairs) == 21
    assert len(arc_pairs) == 21
    assert set(canon_pairs) == set(arc_pairs)

    expected_unordered = {frozenset(pair) for pair in itertools.combinations(SEVEN, 2)}
    actual_unordered = {frozenset(canon_pairs[item["pair_id"]]) for item in arcs["arcs"]}
    assert actual_unordered == expected_unordered

    formation_ids = {item["id"] for item in formation["recruitments"]}
    for item in arcs["arcs"]:
        assert item["formation_event"] in formation_ids
        assert item["seed"].strip()
        assert item["rupture"].strip()
        assert item["repair"].strip()
        assert item["remanence"].strip()

    assert arc_pairs["marec_anouk"]["seed"] == "fraternite_sans_dette"
    assert arc_pairs["mathilde_marec"]["seed"] == "proteger_sans_infantiliser"
    assert arc_pairs["mathilde_anouk"]["seed"] == "protection_contre_surprotection"
    assert arc_pairs["zeje_anouk"]["seed"] == "ressenti_contre_etabli"
    assert arc_pairs["aurelien_mathilde"]["seed"] == "cout_acceptable"

    serialized = json.dumps(arcs, ensure_ascii=False).lower()
    forbidden = [
        "relationship_score",
        "romance_score",
        "approval_score",
        "morality_meter",
        "good_ending_combo",
        "posthumous_dialogue",
    ]
    for token in forbidden:
        assert token not in serialized, token


def main() -> None:
    run()
    print("OK — 21 arcs relationnels causaux des Sept validés")


if __name__ == "__main__":
    main()
