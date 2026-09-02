from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCENES_PATH = ROOT / "universe/lore/legendary_seven_major_relationship_scenes.json"
REL_PATH = ROOT / "universe/lore/legendary_seven_relationships.json"
FORMATION_PATH = ROOT / "universe/lore/legendary_seven_formation.json"
CROSS_PATH = ROOT / "universe/lore/contextual_quest_cross_ramifications.json"

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
    data = _load(SCENES_PATH)
    rel = _load(REL_PATH)
    formation = _load(FORMATION_PATH)
    cross = _load(CROSS_PATH)

    rules = data["rules"]
    assert rules["major_scene_count"] == 9
    assert rules["all_21_pairs_have_at_least_one_major_scene"] is True
    assert rules["major_scene_is_never_mandatory_for_every_campaign"] is True
    assert rules["rupture_requires_prior_memory"] is True
    assert rules["rupture_requires_concrete_consequence"] is True
    assert rules["repair_requires_later_event"] is True
    assert rules["repair_requires_real_cost"] is True
    assert rules["repair_is_not_guaranteed"] is True
    assert rules["durable_disagreement_is_valid"] is True
    assert rules["bereavement_can_interrupt_any_stage"] is True
    assert rules["dead_hero_never_speaks"] is True
    assert rules["no_posthumous_reconciliation"] is True
    assert rules["no_new_relationship_meter"] is True
    assert rules["no_romance_inference"] is True
    assert rules["max_spoken_lines_per_major_scene"] == 2
    assert rules["remanence_forward_only"] is True
    assert rules["backward_causation"] is False

    canonical_pairs = {item["id"]: set(item["heroes"]) for item in rel["pairs"]}
    assert len(canonical_pairs) == 21

    scene_families = data["scene_families"]
    assert len(scene_families) == 9
    assert len({scene["id"] for scene in scene_families}) == 9

    formation_ids = {item["id"] for item in formation["recruitments"]}
    cross_ids = {item["id"] for item in cross["cross_events"]}
    cascade_ids = {item["id"] for item in cross["compound_cascades"]}
    external_triggers = set(cross["external_triggers"])
    valid_sources = formation_ids | cross_ids | cascade_ids | external_triggers

    covered_pairs: set[str] = set()
    for scene in scene_families:
        assert scene["title"].strip()
        assert scene["source_events"]
        for source in scene["source_events"]:
            assert source in valid_sources, (scene["id"], source)

        eligible = scene["eligible_pairs"]
        assert eligible
        assert len(set(eligible)) == len(eligible)
        for pair_id in eligible:
            assert pair_id in canonical_pairs, (scene["id"], pair_id)
        covered_pairs.update(eligible)

        rupture = scene["rupture"]
        repair = scene["repair"]
        assert rupture["trigger"].strip()
        assert rupture["consequence"].strip()
        assert rupture["stage_direction"].strip()
        assert rupture["material_trace"].strip()
        assert repair["trigger"].strip()
        assert repair["required_cost"].strip()
        assert repair["stage_direction"].strip()

        assert set(rupture["pair_lines"]) == set(eligible)
        assert set(repair["pair_lines"]) == set(eligible)
        for block in (rupture["pair_lines"], repair["pair_lines"]):
            for pair_id, line in block.items():
                assert line["speaker_id"] in canonical_pairs[pair_id]
                assert line["text"].strip()
                assert len(line["text"].split()) <= 45, (scene["id"], pair_id)

    assert covered_pairs == set(canonical_pairs)

    overlays = data["bereavement_overlays"]
    assert len(overlays) == 3
    assert {item["id"] for item in overlays} == {
        "bereavement.unresolved_rupture",
        "bereavement.after_repair",
        "bereavement.durable_disagreement",
    }
    for overlay in overlays:
        assert overlay["applies_when"].strip()
        assert overlay["stage_direction"].strip()
        assert overlay["material_rule"].strip()
        assert set(overlay["survivor_lines"]) == SEVEN
        for hero_id, text in overlay["survivor_lines"].items():
            assert hero_id in SEVEN
            assert text.strip()

    remanence = data["remanence_contract"]
    assert remanence["source"].strip()
    assert remanence["transmission"].strip()
    assert remanence["transformation"].strip()

    serialized = json.dumps(data, ensure_ascii=False).lower()
    for token in [
        "relationship_score",
        "romance_score",
        "approval_score",
        "morality_meter",
        "good_ending_combo",
        "ghost_dialogue",
        "posthumous_reconciliation_required",
    ]:
        assert token not in serialized, token

    # Canon-specific guardrails.
    dragon_scene = next(item for item in scene_families if item["id"] == "major.dragon_scarcity")
    dragon_text = json.dumps(dragon_scene, ensure_ascii=False).lower()
    for forbidden_claim in ["pacte ancestral confirmé", "ascendance draconique confirmée", "lien au voile confirmé"]:
        assert forbidden_claim not in dragon_text

    trame_scene = next(item for item in scene_families if item["id"] == "major.trame_overload")
    assert "marec_anouk" in trame_scene["eligible_pairs"]
    assert "mathilde_anouk" in trame_scene["eligible_pairs"]
    assert "zeje_anouk" in trame_scene["eligible_pairs"]


def main() -> None:
    run()
    print("OK — 9 scènes majeures des Sept, 21 couples et 3 deuils validés")


if __name__ == "__main__":
    main()
