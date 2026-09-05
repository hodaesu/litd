extends Node

const RUNTIME_SCRIPT := preload("res://scripts/core/veilleurs_clinical_reaction_runtime.gd")

var failures: Array[String] = []
var runtime: Node = null

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

    runtime = RUNTIME_SCRIPT.new()
    runtime.name = "HemocordeReactionSmokeRuntime"
    add_child(runtime)

    var aisha := _hero("aisha_maren")
    var nayra := _hero("nayra_orun")
    _check(not aisha.is_empty() and not nayra.is_empty(), "Hemocorde reaction smoke requires Aïsha and Nayra")
    _check(not _party_ids(GameState.party).has("aurelien"), "Aurélien must never enter the Veilleurs Hemocorde reaction runtime")

    for hero_value: Variant in GameState.party:
        if hero_value is Dictionary:
            var hero: Dictionary = hero_value
            hero["level"] = 50
            hero["hp"] = int(hero.get("max_hp", 100))
            hero["unlocked_skills"] = []
            hero.erase("clinical_reaction_round_used")
            hero.erase("clinical_reaction_skill_used")
    aisha["unlocked_skills"] = ["AÏ-HÉM-04", "AÏ-HÉM-13"]
    aisha["combat_position"] = 1
    nayra["combat_position"] = 2

    # Retour sanguin : aucun déclenchement sans saignement préalable.
    var dry_enemy := _enemy(950, "Cible sèche")
    var dry_result: Dictionary = runtime.after_enemy_action(dry_enemy, aisha, 1, GameState.party)
    _check(dry_result.is_empty(), "Retour sanguin must require an enemy that is already bleeding")
    _check(int(aisha.get("clinical_reaction_round_used", -1)) != 1, "A failed Hemocorde reaction must not consume the round budget")

    # Retour sanguin : riposte légère, anatomique et circulatoire sur cible déjà saignante.
    var bleeding_enemy := _enemy(951, "Cible saignante")
    bleeding_enemy["bleeding"] = 3
    VeilleursSkillResolverRouter.refresh_specialized_target(bleeding_enemy)
    var hp_before_return := int(bleeding_enemy.get("hp", 0))
    var bleed_before_return := int(bleeding_enemy.get("bleeding", 0))
    var return_result: Dictionary = runtime.after_enemy_action(bleeding_enemy, aisha, 2, GameState.party)
    _check(str(return_result.get("skill_id", "")) == "AÏ-HÉM-04", "Retour sanguin must resolve through its canonical reaction id")
    _check(int(bleeding_enemy.get("hp", 0)) < hp_before_return, "Retour sanguin must inflict a light riposte")
    _check(int(bleeding_enemy.get("bleeding", 0)) == bleed_before_return + 1, "Retour sanguin must worsen the existing bleed rather than create a parallel blood pool")
    _check(str(return_result.get("part_id", "")) != "", "Retour sanguin must touch a real anatomy part")
    _check(int(aisha.get("clinical_reaction_round_used", -1)) == 2, "Retour sanguin must consume Aïsha's shared reaction budget")
    _check(int(bleeding_enemy.get("circulatory_shock", -1)) >= 0, "Retour sanguin must refresh the derived circulatory state")

    # Le même round ne peut pas produire une deuxième réaction Hémocorde.
    var known_part := _first_targetable_part(bleeding_enemy)
    bleeding_enemy["vascular_known_parts"] = {known_part: {"certainty": 2, "observer_id": "aisha_maren"}}
    var same_round: Array[Dictionary] = runtime.on_enemy_movement(bleeding_enemy, 2, 1, 2, GameState.party)
    _check(not _contains_skill(same_round, "AÏ-HÉM-13"), "Pointe réflexe must not fire after Retour sanguin already consumed the same round")

    # Pointe réflexe exige une vraie ouverture de rang ET une zone vasculaire connue.
    var unknown_enemy := _enemy(952, "Physiologie inconnue")
    var unknown_point: Array[Dictionary] = runtime.on_enemy_movement(unknown_enemy, 2, 1, 3, GameState.party)
    _check(not _contains_skill(unknown_point, "AÏ-HÉM-13"), "Pointe réflexe must not invent vascular knowledge")
    _check(int(aisha.get("clinical_reaction_round_used", -1)) != 3, "Unknown anatomy must not consume Pointe réflexe")

    var point_enemy := _enemy(953, "Ouverture vasculaire")
    var point_part := _first_targetable_part(point_enemy)
    point_enemy["vascular_known_parts"] = {point_part: {"certainty": 3, "observer_id": "aisha_maren"}}
    var hp_before_point := int(point_enemy.get("hp", 0))
    var point_results: Array[Dictionary] = runtime.on_enemy_movement(point_enemy, 2, 1, 4, GameState.party)
    var point_result := _result_for(point_results, "AÏ-HÉM-13")
    _check(not point_result.is_empty(), "Pointe réflexe must trigger on a close rank opening with known vascular anatomy")
    _check(int(point_enemy.get("hp", 0)) < hp_before_point, "Pointe réflexe must inflict a precise close reaction")
    _check(int(point_enemy.get("bleeding", 0)) == 1, "Pointe réflexe must create real bleeding on the exposed known zone")
    _check(str(point_result.get("part_id", "")) == point_part, "Pointe réflexe must use the known vascular zone")
    _check(int(aisha.get("clinical_reaction_round_used", -1)) == 4, "Pointe réflexe must consume the same shared reaction budget")

    # Un déplacement qui reste loin du premier plan n'ouvre pas Pointe réflexe.
    var distant_enemy := _enemy(954, "Déplacement lointain")
    var distant_part := _first_targetable_part(distant_enemy)
    distant_enemy["vascular_known_parts"] = {distant_part: {"certainty": 3, "observer_id": "aisha_maren"}}
    var distant_results: Array[Dictionary] = runtime.on_enemy_movement(distant_enemy, 3, 2, 5, GameState.party)
    _check(not _contains_skill(distant_results, "AÏ-HÉM-13"), "Pointe réflexe must remain a close-range opening reaction")

    # Si Pointe réflexe et Retour sanguin sont tous deux possibles, la fenêtre la plus spécifique gagne.
    var priority_enemy := _enemy(955, "Priorité Hémocorde")
    var priority_part := _first_targetable_part(priority_enemy)
    priority_enemy["vascular_known_parts"] = {priority_part: {"certainty": 3, "observer_id": "aisha_maren"}}
    priority_enemy["bleeding"] = 4
    var priority_move: Array[Dictionary] = runtime.on_enemy_movement(priority_enemy, 2, 1, 6, GameState.party)
    _check(_contains_skill(priority_move, "AÏ-HÉM-13"), "Pointe réflexe must win over generic Retour sanguin when a known close opening exists")
    var lower_priority_return: Dictionary = runtime.after_enemy_action(priority_enemy, aisha, 6, GameState.party)
    _check(lower_priority_return.is_empty(), "Retour sanguin must respect Pointe réflexe consuming the shared budget")

    # Une urgence médicale reste prioritaire même dans un harness multi-arbres.
    aisha["unlocked_skills"].append("AÏ-SUT-13")
    nayra["max_hp"] = 100
    nayra["hp"] = 20
    var medical_enemy := _enemy(956, "Priorité médicale")
    medical_enemy["bleeding"] = 4
    var medical_result: Dictionary = runtime.after_enemy_hit(medical_enemy, nayra, 30, 0, 7, GameState.party)
    _check(str(medical_result.get("skill_id", "")) == "AÏ-SUT-13", "Intervention immédiate must retain priority over offensive Hemocorde reactions")
    var blocked_return: Dictionary = runtime.after_enemy_action(medical_enemy, nayra, 7, GameState.party)
    _check(blocked_return.is_empty(), "The medical reaction must consume the same Aïsha reaction budget as Hemocorde")

    # Les deux réactions restent des hooks automatiques, jamais des boutons manuels.
    for skill_id in ["AÏ-HÉM-04", "AÏ-HÉM-13"]:
        var node := _skill_node(aisha, skill_id)
        var profile := VeilleursSkillResolverRouter.combat_profile(aisha, node)
        _check(str(profile.get("effect", "")) == "resolver_required", "%s must remain an automatic reaction profile" % skill_id)
        _check(not bool(profile.get("manual_combat_usable", true)), "%s must never become a manual combat button" % skill_id)

    var ultimate := VeilleursSkillResolverRouter.ultimate_contract(aisha, "hemocorde")
    _check(str(ultimate.get("status", "")) == "required", "Le Dernier Battement must remain outside the reaction lot")

    _finish(original_ids)

func _enemy(enemy_id: int, enemy_name: String) -> Dictionary:
    var enemy := {
        "id": enemy_id,
        "name": enemy_name,
        "hp": 140,
        "max_hp": 140,
        "damage": [7, 11],
        "fear": 0,
        "combat_position": 1,
        "dismemberment_profile": "humanoid",
        "dismembered_parts": [],
        "bleeding": 0
    }
    AnatomyRuntime.ensure_state(enemy)
    return enemy

func _first_targetable_part(enemy: Dictionary) -> String:
    AnatomyRuntime.ensure_state(enemy)
    var parts := AnatomyRuntime.targetable_parts(enemy)
    return str((parts[0] as Dictionary).get("id", "")) if not parts.is_empty() else ""

func _contains_skill(results: Array[Dictionary], skill_id: String) -> bool:
    return not _result_for(results, skill_id).is_empty()

func _result_for(results: Array[Dictionary], skill_id: String) -> Dictionary:
    for value: Variant in results:
        if value is Dictionary and str((value as Dictionary).get("skill_id", "")) == skill_id:
            return value
    return {}

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
    if runtime != null:
        runtime.queue_free()
    if VeilleursVS001PlayableBridge.is_watcher_party_active():
        VeilleursVS001PlayableBridge.restore_previous_party()
    if not original_ids.is_empty() and _party_ids(GameState.party) != original_ids:
        failures.append("Hemocorde reaction smoke cleanup must restore the original party")
    if failures.is_empty():
        print("VEILLEURS_HEMOCORDE_REACTIONS_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_HEMOCORDE_REACTIONS_SMOKE: " + failure)
    print("VEILLEURS_HEMOCORDE_REACTIONS_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
