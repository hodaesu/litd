import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_hemocorde_is_a_separate_prototype_bridge_without_parallel_blood_hp():
    contract = json.loads((ROOT / "data/veilleurs/skills/resolver_contract.json").read_text(encoding="utf-8"))
    family = contract["tree_families"]["Hémocorde"]
    assert contract["version"] >= 5
    assert family["resolver_id"] == "vascular_bleeding"
    assert family["status"] == "prototype_bridge"
    assert family["entrypoint"] == "VeilleursHemocordeRuntime.resolve"
    assert family["reaction_entrypoint"] == "VeilleursClinicalReactionRuntime"
    assert family["coverage"]["manual_actions"] is True
    assert family["coverage"]["posture"] is True
    assert family["coverage"]["passive_readthrough"] is True
    assert family["coverage"]["transformation_hooks"] is True
    assert family["coverage"]["reaction_hooks"] is True

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


def test_hemocorde_reactions_are_automatic_and_share_aishas_budget():
    contract = json.loads((ROOT / "data/veilleurs/skills/resolver_contract.json").read_text(encoding="utf-8"))
    family = contract["tree_families"]["Hémocorde"]
    assert family["coverage"]["reaction_hooks"] is True
    assert family["reaction_entrypoint"] == "VeilleursClinicalReactionRuntime"
    assert contract["ultimate_family"]["status"] == "required"

    reaction_runtime = (ROOT / "scripts/core/veilleurs_clinical_reaction_runtime.gd").read_text(encoding="utf-8")
    assert 'AISHA_BLOOD_RETURN := "AÏ-HÉM-04"' in reaction_runtime
    assert 'AISHA_REFLEX_POINT := "AÏ-HÉM-13"' in reaction_runtime
    assert 'actor["clinical_reaction_round_used"] = round_index' in reaction_runtime
    assert 'int(actor.get("clinical_reaction_round_used", -1)) != round_index' in reaction_runtime
    assert 'int(enemy.get("bleeding", 0)) <= 0' in reaction_runtime
    assert '_known_vascular_part(enemy)' in reaction_runtime
    assert 'mini(position_before, position_after) <= 1' in reaction_runtime
    assert "refresh_specialized_target(enemy)" in reaction_runtime

    runtime = (ROOT / "scripts/core/veilleurs_hemocorde_runtime.gd").read_text(encoding="utf-8")
    assert 'canonical_type in ["Passif", "Réaction", "Transformation"]' in runtime
    assert '"effect": "resolver_required"' in runtime


def test_main_orders_medical_movement_then_blood_return():
    ui = (ROOT / "scripts/ui/main_v36.gd").read_text(encoding="utf-8")
    assert "after_enemy_action" in ui
    assert '"AÏ-HÉM-04"' in ui
    assert '"AÏ-HÉM-13"' in ui
    hit_index = ui.index("var hit_reaction")
    movement_index = ui.index("var movement_reactions", hit_index)
    blood_index = ui.index("var blood_return", movement_index)
    assert hit_index < movement_index < blood_index
    assert "blood_return_miss" in ui


def test_router_keeps_clinical_and_hemocorde_runtimes_separate():
    router = (ROOT / "scripts/core/veilleurs_skill_resolver_router.gd").read_text(encoding="utf-8")
    assert "VeilleursClinicalCombatRuntime" not in router  # class names are intentionally not hard-coded; paths are.
    assert "veilleurs_clinical_combat_runtime.gd" in router
    assert "veilleurs_hemocorde_runtime.gd" in router
    assert 'hemocorde_runtime.name = "HemocordeRuntime"' in router
    assert "func _runtime_for" in router
    assert "func refresh_specialized_target" in router
