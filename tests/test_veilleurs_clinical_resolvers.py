import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _load(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def test_entaille_anatomie_suture_are_explicit_prototype_bridges():
    contract = _load("data/veilleurs/skills/resolver_contract.json")
    assert contract["version"] >= 3
    expected = {
        "Entaille": "anatomical_lesion",
        "Anatomie": "anatomical_diagnostic",
        "Suture": "medical_treatment",
    }
    for tree, resolver_id in expected.items():
        family = contract["tree_families"][tree]
        assert family["resolver_id"] == resolver_id
        assert family["status"] == "prototype_bridge"
        assert family["entrypoint"] == "VeilleursClinicalCombatRuntime.resolve"
        assert family["reaction_entrypoint"] == "VeilleursClinicalReactionRuntime"
        coverage = family["coverage"]
        assert coverage["manual_actions"] is True
        assert coverage["posture"] is True
        assert coverage["reaction_hooks"] is True
        assert coverage["transformation_hooks"] is True


def test_unimplemented_trees_still_cannot_claim_runtime_execution():
    contract = _load("data/veilleurs/skills/resolver_contract.json")
    for tree in ["Bastion", "Brisure", "Serment", "Traque", "Disparition", "Hémocorde", "Sentence", "Concorde", "Dissidence"]:
        assert contract["tree_families"][tree]["status"] == "required"


def test_clinical_runtime_uses_existing_body_and_persistent_injury_systems():
    runtime = (ROOT / "scripts/core/veilleurs_clinical_combat_runtime.gd").read_text(encoding="utf-8")
    assert "AnatomyRuntime.register_targeted_hit" in runtime
    assert "InjuryRuntime.apply_if_needed" in runtime
    assert "PersistentInjuryRuntime.stabilize_in_field" in runtime
    assert 'GameState.supplies = maxi(0, int(GameState.supplies) - cost)' in runtime
    assert 'target["bleeding"]' in runtime
    assert 'patient["persistent_injuries"]' in runtime
    assert "resurrection" not in runtime.lower()


def test_main_v36_is_additive_and_keeps_clinical_and_item_layers():
    scene = (ROOT / "scenes/Main.tscn").read_text(encoding="utf-8")
    manual_bridge = (ROOT / "scripts/ui/main_v35.gd").read_text(encoding="utf-8")
    reaction_bridge = (ROOT / "scripts/ui/main_v36.gd").read_text(encoding="utf-8")
    assert "main_v36.gd" in scene
    assert 'extends "res://scripts/ui/main_v35.gd"' in reaction_bridge
    assert 'extends "res://scripts/ui/main_v34.gd"' in manual_bridge
    assert '"anatomical_lesion", "anatomical_diagnostic", "medical_treatment"' in manual_bridge
    assert "super._use_combat_skill(slot)" in manual_bridge
    assert "super._resolve_skill_attack(hero, skill)" in manual_bridge
    assert "VeilleursSkillResolverRouter.resolve_combat" in manual_bridge
    assert "before_enemy_damage" in reaction_bridge
    assert "after_enemy_hit" in reaction_bridge
    assert "on_enemy_miss" in reaction_bridge
    assert "on_enemy_movement" in reaction_bridge
    assert "advance_round_state" in reaction_bridge


def test_clinical_reactions_are_automatic_causal_hooks():
    runtime = (ROOT / "scripts/core/veilleurs_clinical_reaction_runtime.gd").read_text(encoding="utf-8")
    for skill_id in ["TA-ENT-04", "TA-ENT-13", "AÏ-ANA-04", "AÏ-ANA-13", "AÏ-SUT-04", "AÏ-SUT-13"]:
        assert skill_id in runtime
    assert 'actor["clinical_reaction_round_used"] = round_index' in runtime
    assert 'int(actor.get("clinical_reaction_round_used", -1)) != round_index' in runtime
    assert "projected_ratio <= 0.25" in runtime
    assert "position_before == position_after" in runtime
    assert "manual_combat_usable" not in runtime


def test_clinical_transformations_and_postures_have_runtime_state():
    runtime = (ROOT / "scripts/core/veilleurs_clinical_reaction_runtime.gd").read_text(encoding="utf-8")
    assert 'tarek["entaille_weakness_hunter"]' in runtime
    assert 'aisha["all_wounds_speak"]' in runtime
    assert 'aisha["war_medicine_active"]' in runtime
    assert 'enemy["tarek_auto_weakness_part"]' in runtime
    assert 'enemy["aisha_diagnostics"]' in runtime
    assert 'ally["war_medicine_priority_score"]' in runtime
    assert '"predator_posture_rounds", "clinical_posture_rounds", "triage_posture_rounds"' in runtime


def test_suture_does_not_fallback_to_generic_hp_healing():
    runtime = (ROOT / "scripts/core/veilleurs_clinical_combat_runtime.gd").read_text(encoding="utf-8")
    assert 'profile["effect"] = "medical"' in runtime
    assert 'profile["target"] = "ally"' in runtime
    assert 'patient["bleeding"]' in runtime
    assert "treat_injury(" not in runtime
