extends Node

const REACTION_RUNTIME_SCRIPT := preload("res://scripts/core/veilleurs_clinical_reaction_runtime.gd")

var failures: Array[String] = []
var runtime: Node

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

    runtime = REACTION_RUNTIME_SCRIPT.new()
    add_child(runtime)

    var Mathilde := _hero("Mathilde")
    var Aurélien := _hero("Aurélien")
    var Marec := _hero("Marec")
    _check(not Mathilde.is_empty() and not Aurélien.is_empty() and not Marec.is_empty(), "Reaction smoke requires Mathilde, Aurélien and Marec")
    _check(not _party_ids(GameState.party).has("aurelien"), "Aurélien must never enter the Veilleurs reaction runtime")

    for hero_value: Variant in GameState.party:
        if hero_value is Dictionary:
            var hero: Dictionary = hero_value
            hero["level"] = 50
            hero["hp"] = int(hero.get("max_hp", 100))
            hero["unlocked_skills"] = []
            hero.erase("clinical_reaction_round_used")
            hero.erase("clinical_reaction_skill_used")

    Mathilde["combat_position"] = 1
    Aurélien["combat_position"] = 1
    Marec["combat_position"] = 2
    Mathilde["unlocked_skills"] = ["MA-ENT-03", "MA-ENT-04", "MA-ENT-07", "MA-ENT-11", "MA-ENT-13", "MA-ENT-15"]
    Aurélien["unlocked_skills"] = ["AU-ANA-03", "AU-ANA-04", "AU-ANA-07", "AU-ANA-11", "AU-ANA-13", "AU-ANA-15", "AU-SUT-03", "AU-SUT-04", "AU-SUT-07", "AU-SUT-11", "AU-SUT-13", "AU-SUT-15"]

    var enemy := {
        "id": 901,
        "name": "Cible réactive",
        "hp": 240,
        "max_hp": 240,
        "damage": [8, 12],
        "fear": 8,
        "combat_position": 1,
        "dismemberment_profile": "humanoid",
        "dismembered_parts": []
    }
    AnatomyRuntime.ensure_state(enemy)
    _check(not AnatomyRuntime.targetable_parts(enemy).is_empty(), "Reaction target must expose anatomy parts")

    # Réaction 1 : Retour de lame, puis vérification du budget partagé de Mathilde.
    var enemy_hp_before := int(enemy.get("hp", 0))
    var return_blade: Dictionary = runtime.on_enemy_miss(enemy, Mathilde, 1, GameState.party)
    _check(str(return_blade.get("skill_id", "")) == "MA-ENT-04", "Retour de lame must trigger after an enemy misses Mathilde")
    _check(int(enemy.get("hp", 0)) < enemy_hp_before, "Retour de lame must deal real damage")
    var same_round_movement: Array[Dictionary] = runtime.on_enemy_movement(enemy, 1, 2, 1, [Mathilde])
    _check(same_round_movement.is_empty(), "Mathilde must not spend two clinical reactions in the same round")

    # Réactions 2 et 3 : Fauchage réflexe + Réflexe musculaire sur un vrai changement de rang.
    var movement_results: Array[Dictionary] = runtime.on_enemy_movement(enemy, 1, 2, 2, GameState.party)
    _check(_contains_skill(movement_results, "MA-ENT-13"), "Fauchage réflexe must react to an enemy rank change")
    _check(_contains_skill(movement_results, "AU-ANA-13"), "Réflexe musculaire must react to an enemy rank change")

    # Réaction 4 : Déviation anatomique réduit le dommage sans annuler l'attaque.
    Aurélien.erase("clinical_reaction_round_used")
    var deflection: Dictionary = runtime.before_enemy_damage(enemy, Marec, 20, 3, GameState.party)
    var deflection_reaction: Dictionary = deflection.get("reaction", {})
    _check(str(deflection_reaction.get("skill_id", "")) == "AU-ANA-04", "Déviation anatomique must trigger on an adjacent ally")
    _check(int(deflection.get("damage", 20)) < 20 and int(deflection.get("damage", 0)) >= 1, "Déviation anatomique must reduce damage without granting invulnerability")

    # Réaction 5 : Intervention immédiate a priorité sur la déviation lors d'un passage en état critique.
    Aurélien.erase("clinical_reaction_round_used")
    Marec["max_hp"] = 100
    Marec["hp"] = 40
    Marec["bleeding"] = 4
    PersistentInjuryRuntime.prepare_character(Marec)
    PersistentInjuryRuntime.apply_injury(Marec, "deep_wound", "critical")
    var reserved: Dictionary = runtime.before_enemy_damage(enemy, Marec, 20, 4, GameState.party)
    _check((reserved.get("reaction", {}) as Dictionary).is_empty(), "Aurélien must reserve her reaction for a projected critical-state intervention")
    Marec["hp"] = 20
    var immediate: Dictionary = runtime.after_enemy_hit(enemy, Marec, 40, 4, 4, GameState.party)
    _check(str(immediate.get("skill_id", "")) == "AU-SUT-13", "Intervention immédiate must trigger when an ally crosses the critical threshold")
    _check(bool(Marec.get("transportable", false)), "Intervention immédiate must make a recoverable critical ally transportable")

    # Réaction 6 : Main réflexe répond à une nouvelle hémorragie importante sur un round suivant.
    Aurélien.erase("clinical_reaction_round_used")
    Marec["hp"] = 60
    Marec["bleeding"] = 6
    var reflex_hand: Dictionary = runtime.after_enemy_hit(enemy, Marec, 60, 2, 5, GameState.party)
    _check(str(reflex_hand.get("skill_id", "")) == "AU-SUT-04", "Main réflexe must trigger on a major new hemorrhage")
    _check(int(Marec.get("bleeding", 0)) < 6, "Main réflexe must reduce actual bleeding")

    # Transformations/passifs : une blessure visible parle, Mathilde privilégie une faiblesse et Médecine de guerre trie le groupe.
    var target_part := str((AnatomyRuntime.targetable_parts(enemy)[0] as Dictionary).get("id", ""))
    AnatomyRuntime.register_targeted_hit(Mathilde, enemy, "technique", 18, target_part, "MA-ENT-15")
    runtime.refresh_passive_states(GameState.party, [enemy])
    _check(bool(Mathilde.get("entaille_weakness_hunter", false)), "Chasseur des faiblesses must activate as a transformation")
    _check(str(enemy.get("mathilde_auto_weakness_part", "")) != "", "Chasseur des faiblesses must privilege an actually injured anatomy part")
    _check(bool(Aurélien.get("all_wounds_speak", false)), "Toute blessure parle must activate as a transformation")
    _check(not (enemy.get("aurelien_diagnostics", {}) as Dictionary).is_empty(), "Toute blessure parle must reveal visible lesions without a manual diagnostic button")
    _check(bool(Aurélien.get("war_medicine_active", false)), "Médecine de guerre must activate as a transformation")
    _check(int(Marec.get("war_medicine_priority_score", 0)) > 0, "Médecine de guerre must assign medical priority from real body state")

    # Les réactions restent des hooks, jamais des boutons manuels.
    var mathilde_reaction_profile := VeilleursSkillResolverRouter.combat_profile(Mathilde, _skill_node(Mathilde, "MA-ENT-04"))
    var aurelien_reaction_profile := VeilleursSkillResolverRouter.combat_profile(Aurélien, _skill_node(Aurélien, "AU-SUT-13"))
    _check(str(mathilde_reaction_profile.get("effect", "")) == "resolver_required" and not bool(mathilde_reaction_profile.get("manual_combat_usable", true)), "Mathilde reaction must remain automatic, not a manual skill button")
    _check(str(aurelien_reaction_profile.get("effect", "")) == "resolver_required" and not bool(aurelien_reaction_profile.get("manual_combat_usable", true)), "Aurélien reaction must remain automatic, not a manual skill button")

    # Expiration réelle des postures et états temporaires.
    Mathilde["predator_posture_rounds"] = 1
    Mathilde["predator_defense_penalty"] = 10
    Aurélien["clinical_posture_rounds"] = 1
    Aurélien["clinical_defense_penalty"] = 10
    Aurélien["triage_posture_rounds"] = 1
    Aurélien["medical_priority_auto"] = true
    runtime.advance_round_state(GameState.party)
    _check(int(Mathilde.get("predator_posture_rounds", -1)) == 0 and not Mathilde.has("predator_defense_penalty"), "Predator posture must really expire")
    _check(int(Aurélien.get("clinical_posture_rounds", -1)) == 0 and not Aurélien.has("clinical_defense_penalty"), "Clinical posture must really expire")
    _check(int(Aurélien.get("triage_posture_rounds", -1)) == 0 and not Aurélien.has("medical_priority_auto"), "Triage posture must really expire")

    _finish(original_ids)

func _contains_skill(results: Array[Dictionary], skill_id: String) -> bool:
    for result: Dictionary in results:
        if str(result.get("skill_id", "")) == skill_id:
            return true
    return false

func _hero(hero_id: String) -> Dictionary:
    for value: Variant in GameState.party:
        if value is Dictionary and str((value as Dictionary).get("id", "")) == hero_id:
            return value
    return {}

func _skill_node(hero: Dictionary, skill_id: String) -> Dictionary:
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
        failures.append("Clinical reaction smoke cleanup must restore the original party")
    if failures.is_empty():
        print("VEILLEURS_CLINICAL_REACTIONS_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_CLINICAL_REACTIONS_SMOKE: " + failure)
    print("VEILLEURS_CLINICAL_REACTIONS_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
