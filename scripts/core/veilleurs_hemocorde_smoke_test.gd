extends Node

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    GameState.reset_new_game()
    await get_tree().process_frame
    VeilleursSkillResolverRouter.reload()
    VeilleursSkillCatalog.reload()
    var original_ids := _party_ids(GameState.party)
    VeilleursVS001PlayableBridge.activate_watchers_party()
    await get_tree().process_frame

    var aisha := _hero("aisha_maren")
    _check(not aisha.is_empty(), "Hemocorde smoke requires Aïsha Maren")
    _check(not _party_ids(GameState.party).has("aurelien"), "Aurélien must never enter the Veilleurs Hemocorde runtime")
    aisha["level"] = 50
    aisha["hp"] = int(aisha.get("max_hp", 100))
    aisha["unlocked_skills"] = ["AÏ-HÉM-01", "AÏ-HÉM-03", "AÏ-HÉM-05", "AÏ-HÉM-06", "AÏ-HÉM-07", "AÏ-HÉM-08", "AÏ-HÉM-09", "AÏ-HÉM-10", "AÏ-HÉM-11", "AÏ-HÉM-12", "AÏ-HÉM-14", "AÏ-HÉM-15"]

    var enemy := {
        "id": 940,
        "name": "Sujet vasculaire",
        "hp": 220,
        "max_hp": 220,
        "damage": [8, 12],
        "fear": 6,
        "dismemberment_profile": "humanoid",
        "dismembered_parts": []
    }
    AnatomyRuntime.ensure_state(enemy)
    _check(not AnatomyRuntime.targetable_parts(enemy).is_empty(), "Hemocorde target must expose anatomy")

    var incision := HeroSkillManager.combat_skill(aisha, "AÏ-HÉM-01")
    _check(str(incision.get("effect", "")) == "attack", "Incision contrôlée must be a manual attack")
    var bleeding_before := int(enemy.get("bleeding", 0))
    var incision_result := VeilleursSkillResolverRouter.resolve_combat(aisha, enemy, incision, 12, GameState.party)
    _check(bool(incision_result.get("ok", false)), "Incision contrôlée must execute")
    _check(int(enemy.get("bleeding", 0)) > bleeding_before, "Incision contrôlée must create real bleeding")
    _check(str(incision_result.get("part_id", "")) != "", "Incision contrôlée must target a real anatomy part")

    var vascular_line := HeroSkillManager.combat_skill(aisha, "AÏ-HÉM-06")
    var line_result := VeilleursSkillResolverRouter.resolve_combat(aisha, enemy, vascular_line, 0, GameState.party)
    _check(bool(line_result.get("ok", false)), "Ligne vasculaire must execute as a diagnostic")
    _check(not (enemy.get("vascular_known_parts", {}) as Dictionary).is_empty(), "Ligne vasculaire must attach vascular knowledge to the target")
    _check(enemy.has("vascular_line_parts"), "Ligne vasculaire must expose plausible hemorrhage zones")

    var pulse := HeroSkillManager.combat_skill(aisha, "AÏ-HÉM-08")
    var pulse_result := VeilleursSkillResolverRouter.resolve_combat(aisha, enemy, pulse, 0, GameState.party)
    _check(bool(pulse_result.get("ok", false)), "Lire le pouls must execute")
    _check(enemy.has("pulse_reading"), "Lire le pouls must store a physiological reading")
    _check(int(pulse_result.get("hemorrhage_risk", -1)) >= 0, "Pulse reading must expose derived hemorrhage risk")

    var maintain := HeroSkillManager.combat_skill(aisha, "AÏ-HÉM-05")
    var before_maintain := int(enemy.get("bleeding", 0))
    var maintain_result := VeilleursSkillResolverRouter.resolve_combat(aisha, enemy, maintain, 10, GameState.party)
    _check(bool(maintain_result.get("ok", false)), "Entretenir l'ouverture must execute")
    _check(int(enemy.get("bleeding", 0)) > before_maintain, "Entretenir l'ouverture must aggravate existing bleeding")

    var rhythm := HeroSkillManager.combat_skill(aisha, "AÏ-HÉM-09")
    var rhythm_result := VeilleursSkillResolverRouter.resolve_combat(aisha, enemy, rhythm, 10, GameState.party)
    _check(bool(rhythm_result.get("ok", false)), "Rupture de rythme must execute")
    _check(int(enemy.get("rhythm_disrupted_rounds", 0)) > 0, "Rupture de rythme must disrupt a physiologically vulnerable target")

    var selected_part := str(incision_result.get("part_id", ""))
    enemy["anatomy_part_trauma"][selected_part] = maxi(20, int(enemy.get("anatomy_part_trauma", {}).get(selected_part, 0)))
    var open_wound := HeroSkillManager.combat_skill(aisha, "AÏ-HÉM-12")
    var wound_result := VeilleursSkillResolverRouter.resolve_combat(aisha, enemy, open_wound, 10, GameState.party)
    _check(bool(wound_result.get("ok", false)), "Plaie ouverte must execute")
    _check(int(wound_result.get("bleed_added", 0)) >= 1, "Plaie ouverte must operate on actual lesion/armor state")

    # Maîtrise vasculaire is passive: it must reveal likely vascular zones without a manual button.
    VeilleursSkillResolverRouter.refresh_specialized_passives(GameState.party, [enemy])
    _check(bool(aisha.get("vascular_mastery", false)), "Maîtrise vasculaire must activate as a transformation")
    _check(not (enemy.get("vascular_known_parts", {}) as Dictionary).is_empty(), "Maîtrise vasculaire must preserve target-bound vascular knowledge")

    # Effondrement circulatoire cannot cheat: healthy/uncompromised target first, then compromised target.
    var collapse := HeroSkillManager.combat_skill(aisha, "AÏ-HÉM-14")
    var healthy := {
        "id": 941,
        "name": "Sujet sain",
        "hp": 220,
        "max_hp": 220,
        "damage": [8, 12],
        "fear": 4,
        "dismemberment_profile": "humanoid",
        "dismembered_parts": []
    }
    AnatomyRuntime.ensure_state(healthy)
    var healthy_result := VeilleursSkillResolverRouter.resolve_combat(aisha, healthy, collapse, 14, GameState.party)
    _check(bool(healthy_result.get("ok", false)), "Effondrement circulatoire action must resolve even when its finisher condition fails")
    _check(not bool(healthy_result.get("circulatory_collapse", false)), "Effondrement circulatoire must not neutralize a healthy target")

    enemy["bleeding"] = maxi(8, int(enemy.get("bleeding", 0)))
    enemy["hp"] = 55
    VeilleursSkillResolverRouter.refresh_specialized_passives(GameState.party, [enemy])
    var hp_before_collapse := int(enemy.get("hp", 0))
    var collapse_result := VeilleursSkillResolverRouter.resolve_combat(aisha, enemy, collapse, 18, GameState.party)
    _check(bool(collapse_result.get("ok", false)), "Effondrement circulatoire must execute on a compromised target")
    _check(bool(collapse_result.get("circulatory_collapse", false)), "Effondrement circulatoire must require and recognize physiological compromise")
    _check(int(enemy.get("hp", 0)) >= 1, "Effondrement circulatoire resolver must never perform an instant kill")
    _check(int(enemy.get("hp", 0)) <= hp_before_collapse, "Effondrement circulatoire may worsen a compromised target but cannot heal it")

    var posture := HeroSkillManager.combat_skill(aisha, "AÏ-HÉM-10")
    var posture_result := VeilleursSkillResolverRouter.resolve_combat(aisha, aisha, posture, 0, GameState.party)
    _check(bool(posture_result.get("ok", false)), "Posture hémodynamique must execute")
    _check(int(aisha.get("hemodynamic_posture_rounds", 0)) == 3, "Posture hémodynamique must have a finite duration")
    VeilleursSkillResolverRouter.advance_specialized_round_states(GameState.party)
    _check(int(aisha.get("hemodynamic_posture_rounds", 0)) == 2, "Posture hémodynamique must decrement with round progression")

    var reaction_node := _skill_node(aisha, "AÏ-HÉM-04")
    var reaction_profile := VeilleursSkillResolverRouter.combat_profile(aisha, reaction_node)
    _check(str(reaction_profile.get("effect", "")) == "resolver_required", "Retour sanguin must remain blocked until the Hemocorde reaction hook is implemented")
    _check(not bool(reaction_profile.get("manual_combat_usable", true)), "Hemocorde reactions must never become manual buttons")
    var ultimate := VeilleursSkillResolverRouter.ultimate_contract(aisha, "hemocorde")
    _check(str(ultimate.get("status", "")) == "required", "Le Dernier Battement must remain on the dedicated ultimate sequence contract")

    _finish(original_ids)

func _hero(hero_id: String) -> Dictionary:
    for value: Variant in GameState.party:
        if value is Dictionary and str((value as Dictionary).get("id", "")) == hero_id:
            return value
    return {}

func _skill_node(hero: Dictionary, skill_id: String) -> Dictionary:
    if hero.is_empty():
        return {}
    for branch: String in HeroSkillManager.branches_for(hero):
        for value: Variant in HeroSkillManager.skill_nodes(hero, branch):
            if value is Dictionary and str((value as Dictionary).get("id", "")) == skill_id:
                return value
    return {}

func _party_ids(party_value: Array) -> Array[String]:
    var result: Array[String] = []
    for value: Variant in party_value:
        if value is Dictionary:
            result.append(str((value as Dictionary).get("id", "")))
    return result

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish(original_ids: Array[String]) -> void:
    if VeilleursVS001PlayableBridge.is_watcher_party_active():
        VeilleursVS001PlayableBridge.restore_previous_party()
    if not original_ids.is_empty() and _party_ids(GameState.party) != original_ids:
        failures.append("Hemocorde smoke cleanup must restore the original party")
    if failures.is_empty():
        print("VEILLEURS_HEMOCORDE_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_HEMOCORDE_SMOKE: " + failure)
    print("VEILLEURS_HEMOCORDE_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
