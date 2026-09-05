import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _load(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def test_entaille_anatomie_suture_are_explicit_prototype_bridges():
    contract = _load("data/veilleurs/skills/resolver_contract.json")
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
        coverage = family["coverage"]
        assert coverage["manual_actions"] is True
        assert coverage["posture"] is True
        assert coverage["reaction_hooks"] is False
        assert coverage["transformation_hooks"] is False


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


def test_main_v35_is_additive_and_only_intercepts_clinical_resolvers():
    scene = (ROOT / "scenes/Main.tscn").read_text(encoding="utf-8")
    bridge = (ROOT / "scripts/ui/main_v35.gd").read_text(encoding="utf-8")
    assert "main_v35.gd" in scene
    assert 'extends "res://scripts/ui/main_v34.gd"' in bridge
    assert '"anatomical_lesion", "anatomical_diagnostic", "medical_treatment"' in bridge
    assert "super._use_combat_skill(slot)" in bridge
    assert "super._resolve_skill_attack(hero, skill)" in bridge
    assert "VeilleursSkillResolverRouter.resolve_combat" in bridge


def test_suture_does_not_fallback_to_generic_hp_healing():
    runtime = (ROOT / "scripts/core/veilleurs_clinical_combat_runtime.gd").read_text(encoding="utf-8")
    assert 'profile["effect"] = "medical"' in runtime
    assert 'profile["target"] = "ally"' in runtime
    assert 'patient["bleeding"]' in runtime
    assert "treat_injury(" not in runtime
