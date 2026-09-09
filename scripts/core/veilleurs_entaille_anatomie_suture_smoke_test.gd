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

    var Mathilde := _hero("Mathilde")
    var Aurélien := _hero("Aurélien")
    var Marec := _hero("Marec")
    _check(not Mathilde.is_empty() and not Aurélien.is_empty() and not Marec.is_empty(), "Clinical smoke requires Mathilde, Aurélien and Marec")
    _check(not _party_ids(GameState.party).has("aurelien"), "Aurélien must never enter the Veilleurs clinical runtime")

    for hero_value: Variant in GameState.party:
        if hero_value is Dictionary:
            var hero: Dictionary = hero_value
            hero["level"] = 50
            hero["skill_points"] = 100
            hero["unlocked_skills"] = []
            hero["specialization"] = ""
            hero["combat_loadout"] = []
            HeroSkillManager.prepare_hero(hero)

    if not Mathilde.is_empty():
        Mathilde["unlocked_skills"] = ["MA-ENT-02", "MA-ENT-03", "MA-ENT-07", "MA-ENT-10", "MA-ENT-14", "MA-ENT-15"]
    if not Aurélien.is_empty():
        Aurélien["unlocked_skills"] = ["AU-ANA-01", "AU-ANA-05", "AU-ANA-06", "AU-ANA-10", "AU-SUT-01", "AU-SUT-05", "AU-SUT-06"]

    var enemy := {
        "id": 1,
        "name": "Cible clinique",
        "hp": 120,
        "max_hp": 120,
        "damage": [6, 10],
        "fear": 10,
        "dismemberment_profile": "humanoid",
        "dismembered_parts": []
    }
    AnatomyRuntime.ensure_state(enemy)
    _check(not AnatomyRuntime.targetable_parts(enemy).is_empty(), "Clinical target must expose anatomy parts")

    var entaille := HeroSkillManager.combat_skill(Mathilde, "MA-ENT-02")
    _check(str(entaille.get("resolver_status", "")) == "prototype_bridge", "Entaille must be a playable prototype bridge")
    _check(str(entaille.get("effect", "")) == "attack", "Coupe-tendon must produce an attack combat profile")
    _check(bool(entaille.get("manual_combat_usable", false)), "Manual Entaille action must be equipable")
    var entaille_result := VeilleursSkillResolverRouter.resolve_combat(Mathilde, enemy, entaille, 14, GameState.party)
    _check(bool(entaille_result.get("ok", false)), "Entaille resolver must execute")
    _check(int(entaille_result.get("bleed_added", 0)) > 0 and int(enemy.get("bleeding", 0)) > 0, "Entaille must create real bleeding")
    _check(_total_trauma(enemy) > 0, "Entaille must create real anatomy trauma")
    _check(str(enemy.get("tendon_compromised_part", "")) != "", "Coupe-tendon must remember the compromised part")

    var entaille_posture := HeroSkillManager.combat_skill(Mathilde, "MA-ENT-10")
    _check(str(entaille_posture.get("effect", "")) == "posture", "Posture du prédateur must expose posture effect")
    var posture_result := VeilleursSkillResolverRouter.resolve_combat(Mathilde, Mathilde, entaille_posture, 0, GameState.party)
    _check(bool(posture_result.get("ok", false)) and int(Mathilde.get("predator_posture_rounds", 0)) == 3, "Entaille posture must create a timed state")

    var reaction_node := _skill_node(Mathilde, "MA-ENT-04")
    var reaction_profile := VeilleursSkillResolverRouter.combat_profile(Mathilde, reaction_node)
    _check(str(reaction_profile.get("effect", "")) == "resolver_required", "Entaille reaction must remain a hook, not a manual button")
    _check(not bool(reaction_profile.get("manual_combat_usable", true)), "Reaction hooks must not be manually equipable")

    var diagnostic := HeroSkillManager.combat_skill(Aurélien, "AU-ANA-01")
    _check(str(diagnostic.get("effect", "")) == "diagnostic", "Examen bref must be a diagnostic action")
    var diagnostic_result := VeilleursSkillResolverRouter.resolve_combat(Aurélien, enemy, diagnostic, 0, GameState.party)
    _check(bool(diagnostic_result.get("ok", false)), "Anatomie diagnostic must execute")
    var diagnosed_part := str(diagnostic_result.get("part_id", ""))
    _check(diagnosed_part != "", "Diagnostic must select a concrete anatomy part")
    _check((enemy.get("aurelien_diagnostics", {}) as Dictionary).has(diagnosed_part), "Diagnostic knowledge must persist on the observed target")

    var expose := HeroSkillManager.combat_skill(Aurélien, "AU-ANA-05")
    var expose_result := VeilleursSkillResolverRouter.resolve_combat(Aurélien, enemy, expose, 0, GameState.party)
    _check(bool(expose_result.get("ok", false)), "Exposer l'articulation must execute")
    _check(str(enemy.get("exposed_anatomy_part", "")) != "" and int(enemy.get("exposed", 0)) >= 2, "Exposer l'articulation must create a concrete exposed anatomy state")

    var section := HeroSkillManager.combat_skill(Aurélien, "AU-ANA-06")
    var trauma_before := _total_trauma(enemy)
    var section_result := VeilleursSkillResolverRouter.resolve_combat(Aurélien, enemy, section, 12, GameState.party)
    _check(bool(section_result.get("ok", false)), "Section contrôlée must execute")
    _check(_total_trauma(enemy) > trauma_before, "Section contrôlée must add anatomy trauma")
    _check(str(enemy.get("controlled_section_part", "")) != "", "Section contrôlée must record its targeted function")

    PersistentInjuryRuntime.prepare_character(Marec)
    PersistentInjuryRuntime.apply_injury(Marec, "fracture_leg", "serious")
    PersistentInjuryRuntime.apply_injury(Marec, "deep_wound", "critical")
    Marec["bleeding"] = 8
    GameState.supplies = 10
    var supplies_before := int(GameState.supplies)

    var compression := HeroSkillManager.combat_skill(Aurélien, "AU-SUT-01")
    _check(str(compression.get("effect", "")) == "medical", "Compression must use medical resolver instead of generic healing")
    _check(int(compression.get("heal", 0)) == 0, "Suture must not masquerade as generic HP healing")
    var compression_result := VeilleursSkillResolverRouter.resolve_combat(Aurélien, Marec, compression, 0, GameState.party)
    _check(bool(compression_result.get("ok", false)), "Compression must execute")
    _check(int(Marec.get("bleeding", 0)) < 8, "Compression must reduce actual bleeding")
    _check(_has_stabilized_injury(Marec), "Compression must stabilize a real persistent injury")

    var attelle := HeroSkillManager.combat_skill(Aurélien, "AU-SUT-05")
    var attelle_result := VeilleursSkillResolverRouter.resolve_combat(Aurélien, Marec, attelle, 0, GameState.party)
    _check(bool(attelle_result.get("ok", false)), "Attelle must execute")
    _check(int(Marec.get("splinted_rounds", 0)) == 4, "Attelle must create a splint state")
    _check(_injury_stabilized(Marec, "fracture_leg"), "Attelle must stabilize the fracture without removing it")
    _check(_has_injury(Marec, "fracture_leg"), "Attelle must not magically erase the fracture")

    var field_suture := HeroSkillManager.combat_skill(Aurélien, "AU-SUT-06")
    var severity_before := _injury_severity(Marec, "deep_wound")
    var suture_result := VeilleursSkillResolverRouter.resolve_combat(Aurélien, Marec, field_suture, 0, GameState.party)
    _check(bool(suture_result.get("ok", false)), "Suture de terrain must execute")
    _check(_severity_rank(_injury_severity(Marec, "deep_wound")) < _severity_rank(severity_before), "Suture de terrain must reduce wound severity")
    _check(int(GameState.supplies) < supplies_before, "Medical interventions that require material must consume supplies")
    _check(_has_injury(Marec, "deep_wound"), "Field suture must reduce a wound, not erase its persistent consequence")

    var selected_patient := VeilleursSkillResolverRouter.select_medical_target(GameState.alive_heroes())
    _check(str(selected_patient.get("id", "")) == "Marec", "Medical target selection must prioritize the genuinely injured ally")

    var hemocorde_node := _skill_node(Aurélien, "AÏ-HÉM-01")
    var hemocorde_profile := VeilleursSkillResolverRouter.combat_profile(Aurélien, hemocorde_node)
    _check(str(hemocorde_profile.get("resolver_status", "")) == "prototype_bridge", "Hémocorde must now expose its dedicated prototype bridge")
    _check(str(hemocorde_profile.get("effect", "")) == "attack" and bool(hemocorde_profile.get("manual_combat_usable", false)), "Incision contrôlée must now be a playable manual Hémocorde action")
    var hemocorde_reaction := VeilleursSkillResolverRouter.combat_profile(Aurélien, _skill_node(Aurélien, "AÏ-HÉM-04"))
    _check(str(hemocorde_reaction.get("effect", "")) == "resolver_required" and not bool(hemocorde_reaction.get("manual_combat_usable", true)), "Hémocorde reactions must remain blocked until their reaction hooks exist")

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

func _total_trauma(enemy: Dictionary) -> int:
    var total := 0
    for value: Variant in (enemy.get("anatomy_part_trauma", {}) as Dictionary).values():
        total += int(value)
    return total

func _has_injury(character: Dictionary, injury_id: String) -> bool:
    return _injury_severity(character, injury_id) != ""

func _injury_severity(character: Dictionary, injury_id: String) -> String:
    for value: Variant in character.get("persistent_injuries", []):
        if value is Dictionary and str((value as Dictionary).get("id", "")) == injury_id:
            return str((value as Dictionary).get("severity", "minor"))
    return ""

func _injury_stabilized(character: Dictionary, injury_id: String) -> bool:
    for value: Variant in character.get("persistent_injuries", []):
        if value is Dictionary and str((value as Dictionary).get("id", "")) == injury_id:
            return bool((value as Dictionary).get("stabilized", false))
    return false

func _has_stabilized_injury(character: Dictionary) -> bool:
    for value: Variant in character.get("persistent_injuries", []):
        if value is Dictionary and bool((value as Dictionary).get("stabilized", false)):
            return true
    return false

func _severity_rank(severity: String) -> int:
    return int({"minor": 1, "serious": 2, "critical": 3}.get(severity, 0))

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
        failures.append("Clinical smoke cleanup must restore the original party")
    if failures.is_empty():
        print("VEILLEURS_ENTAILLE_ANATOMIE_SUTURE_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_ENTAILLE_ANATOMIE_SUTURE_SMOKE: " + failure)
    print("VEILLEURS_ENTAILLE_ANATOMIE_SUTURE_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
