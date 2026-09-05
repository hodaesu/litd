import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_hemocorde_is_a_separate_prototype_bridge_without_parallel_blood_hp():
    contract = json.loads((ROOT / "data/veilleurs/skills/resolver_contract.json").read_text(encoding="utf-8"))
    family = contract["tree_families"]["Hémocorde"]
    assert contract["version"] >= 4
    assert family["resolver_id"] == "vascular_bleeding"
    assert family["status"] == "prototype_bridge"
    assert family["entrypoint"] == "VeilleursHemocordeRuntime.resolve"
    assert family["coverage"]["manual_actions"] is True
    assert family["coverage"]["posture"] is True
    assert family["coverage"]["passive_readthrough"] is True
    assert family["coverage"]["transformation_hooks"] is True
    assert family["coverage"]["reaction_hooks"] is False

    runtime = (ROOT / "scripts/core/veilleurs_hemocorde_runtime.gd").read_text(encoding="utf-8")
    assert "AnatomyRuntime.register_targeted_hit" in runtime
    assert 'target["bleeding"]' in runtime
    assert 'target["circulatory_shock"]' in runtime
    assert 'target["hemorrhage_risk"]' in runtime
    assert 'target["vascular_known_parts"]' in runtime
    assert "blood_hp" not in runtime.lower()
    assert "blood_pool" not in runtime.lower()
    assert "resurrection" not in runtime.lower()


def test_hemocorde_collapse_is_conditional_and_cannot_instant_kill():
    runtime = (ROOT / "scripts/core/veilleurs_hemocorde_runtime.gd").read_text(encoding="utf-8")
    assert 'shock_before >= 2 and bleeding_before >= 4 and known' in runtime
    assert 'target["hp"] = maxi(1,' in runtime
    assert 'anatomy_result["circulatory_collapse"] = false' in runtime
    assert 'target["stunned"] = true' in runtime


def test_hemocorde_reactions_and_ultimate_remain_explicitly_blocked():
    contract = json.loads((ROOT / "data/veilleurs/skills/resolver_contract.json").read_text(encoding="utf-8"))
    assert contract["tree_families"]["Hémocorde"]["coverage"]["reaction_hooks"] is False
    assert contract["ultimate_family"]["status"] == "required"
    runtime = (ROOT / "scripts/core/veilleurs_hemocorde_runtime.gd").read_text(encoding="utf-8")
    assert 'canonical_type in ["Passif", "Réaction", "Transformation"]' in runtime
    assert '"effect": "resolver_required"' in runtime


def test_router_keeps_clinical_and_hemocorde_runtimes_separate():
    router = (ROOT / "scripts/core/veilleurs_skill_resolver_router.gd").read_text(encoding="utf-8")
    assert "VeilleursClinicalCombatRuntime" not in router  # class names are intentionally not hard-coded; paths are.
    assert "veilleurs_clinical_combat_runtime.gd" in router
    assert "veilleurs_hemocorde_runtime.gd" in router
    assert 'hemocorde_runtime.name = "HemocordeRuntime"' in router
    assert "func _runtime_for" in router
