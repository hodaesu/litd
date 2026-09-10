extends "res://scripts/core/veilleurs_tactical_combat_runtime_v2.gd"
class_name VeilleursTacticalCombatRuntimeV3

const BASIC_ACTIONS_SCRIPT := preload("res://scripts/core/veilleurs_basic_action_service.gd")

var basic_actions: VeilleursBasicActionService

func _init() -> void:
    super()
    basic_actions = BASIC_ACTIONS_SCRIPT.new() as VeilleursBasicActionService

func setup_first_combat(enemy_ids: Array[String] = ["ENT_ENEMY_GOULE_AFFAMEE", "ENT_ENEMY_ECORCHEUSE", "ENT_ENEMY_FOUISSEUSE"]) -> Dictionary:
    var result := super.setup_first_combat(enemy_ids)
    if not bool(result.get("ok", false)):
        return result
    if basic_actions == null or not basic_actions.is_valid():
        return {"ok":false, "reason":"basic_action_contract_invalid", "errors":basic_actions.load_errors.duplicate() if basic_actions != null else ["service_missing"]}
    _attach_combat_ranks()
    result["basic_actions_ready"] = true
    return result

func basic_actions_for(entity_id: String) -> Array[Dictionary]:
    if basic_actions == null or not combatants.has(entity_id):
        return []
    return basic_actions.actions_for(entity_id, combatants[entity_id])

func available_basic_actions(entity_id: String) -> Array[Dictionary]:
    if basic_actions == null or not combatants.has(entity_id):
        return []
    var row: Dictionary = combatants[entity_id]
    return basic_actions.available_actions(entity_id, row, int(row.get("combat_rank", 1)))

func resolve_basic_action(attacker_id: String, target_id: String, action_id: String, zone: String = "torso", forced_roll: int = -1) -> Dictionary:
    if basic_actions == null or not basic_actions.is_valid():
        return {"ok":false, "reason":"basic_action_contract_invalid"}
    if not combatants.has(attacker_id):
        return {"ok":false, "reason":"unknown_combatant"}
    var attacker: Dictionary = combatants[attacker_id]
    var action: Dictionary = basic_actions.action(attacker_id, attacker, action_id)
    if action.is_empty():
        return {"ok":false, "reason":"basic_action_not_owned", "action_id":action_id}
    var rank := int(attacker.get("combat_rank", 1))
    if not (action.get("positions", []) as Array).has(rank):
        return {"ok":false, "reason":"basic_action_wrong_rank", "rank":rank, "action_id":action_id}
    var target_type := str(action.get("target", "enemy"))
    if target_type == "self":
        target_id = attacker_id
    if target_id == "" or not combatants.has(target_id):
        return {"ok":false, "reason":"basic_action_target_missing", "action_id":action_id}
    var target: Dictionary = combatants[target_id]
    if target_type == "enemy" and str(target.get("team", "")) == str(attacker.get("team", "")):
        return {"ok":false, "reason":"basic_action_target_team"}
    if target_type == "ally" and str(target.get("team", "")) != str(attacker.get("team", "")):
        return {"ok":false, "reason":"basic_action_target_team"}
    var kind := str(action.get("kind", ""))
    if _is_restore_kind(kind):
        return _resolve_justified_restore(attacker_id, target_id, action)
    if _is_reposition_kind(kind):
        return _resolve_basic_reposition(attacker_id, action)
    if _is_defense_kind(kind):
        return _resolve_basic_defense(attacker_id, target_id, action)
    if _is_non_damage_control(kind):
        return _resolve_basic_control(attacker_id, target_id, action)
    return _resolve_basic_damage(attacker_id, target_id, action, zone, forced_roll)

func enemy_step(enemy_id: String) -> Dictionary:
    if not combatants.has(enemy_id) or str((combatants[enemy_id] as Dictionary).get("team", "")) != "enemy":
        return {"ok":false, "reason":"not_enemy"}
    var decision: Dictionary = enemy_ai.decide(self, enemy_id)
    var action_kind := str(decision.get("action", "none"))
    if action_kind in ["move", "flee", "hold"]:
        return super.enemy_step(enemy_id)
    var target_id := str(decision.get("target", ""))
    var available := available_basic_actions(enemy_id)
    if available.is_empty():
        return {"ok":false, "reason":"no_rank_valid_basic_action", "enemy":enemy_id, "rank":int((combatants[enemy_id] as Dictionary).get("combat_rank", 1))}
    var chosen: Dictionary = {}
    if action_kind == "support":
        for candidate: Dictionary in available:
            var kind := str(candidate.get("kind", ""))
            if _is_defense_kind(kind) or _is_restore_kind(kind) or kind.find("debuff") >= 0:
                chosen = candidate
                break
    if chosen.is_empty():
        for candidate: Dictionary in available:
            if _is_damage_kind(str(candidate.get("kind", ""))):
                chosen = candidate
                break
    if chosen.is_empty():
        chosen = available[0]
    if str(chosen.get("target", "enemy")) == "self":
        target_id = enemy_id
    elif str(chosen.get("target", "enemy")) == "ally":
        var allies := alive_ids("enemy")
        if not allies.is_empty():
            target_id = allies[0]
    elif target_id == "" or not combatants.has(target_id):
        var watchers := alive_ids("watcher")
        if watchers.is_empty():
            return {"ok":false, "reason":"ai_no_target"}
        target_id = watchers[0]
    var result := resolve_basic_action(enemy_id, target_id, str(chosen.get("id", "")), str(decision.get("zone", "torso")), -1)
    result["decision_reason"] = str(decision.get("reason", "basic_action_ai"))
    return result

func _attach_combat_ranks() -> void:
    for entity_value: Variant in combatants.keys():
        var entity_id := str(entity_value)
        var row: Dictionary = combatants[entity_id]
        if str(row.get("team", "")) == "watcher":
            var definition := content_db.watcher(entity_id)
            row["combat_rank"] = int(definition.get("starter_rank", basic_actions.preferred_rank(entity_id, row)))
        else:
            row["combat_rank"] = basic_actions.preferred_rank(entity_id, row)
        combatants[entity_id] = row

func _resolve_basic_damage(attacker_id: String, target_id: String, action: Dictionary, zone: String, forced_roll: int) -> Dictionary:
    var kind := str(action.get("kind", "damage"))
    var multiplier := 0.72
    if kind.find("heavy") >= 0 or kind.find("execute") >= 0:
        multiplier = 0.95
    elif kind.find("precision") >= 0:
        multiplier = 0.78
    elif kind.find("control") >= 0:
        multiplier = 0.68
    var skill := {
        "skill_id":str(action.get("id", "")),
        "entity_id":attacker_id,
        "skill_index":1,
        "action_type":"attack",
        "mechanical_profile":"anatomy" if kind.find("precision") >= 0 else ("impact" if kind.find("control") >= 0 or kind.find("push") >= 0 else "assault"),
        "precision_mod":5 if kind.find("precision") >= 0 else 0,
        "effect_spec":{"damage_multiplier":multiplier, "trauma_multiplier":0.75, "forced_move":1 if kind.find("push") >= 0 else 0},
        "dismemberment_rules":{"allowed":false, "power":0}
    }
    var result: Dictionary = _resolve_damage_v2(attacker_id, target_id, skill, zone, forced_roll)
    result["basic_action"] = true
    result["basic_action_name"] = str(action.get("name", ""))
    if bool(result.get("hit", false)) and kind.find("drain") >= 0:
        var attacker: Dictionary = combatants[attacker_id]
        attacker["absorbed_vitality"] = int(attacker.get("absorbed_vitality", 0)) + maxi(1, int(result.get("damage", 0)) / 2)
        combatants[attacker_id] = attacker
        result["healing_provenance"] = "absorption"
    return result

func _resolve_basic_defense(attacker_id: String, target_id: String, action: Dictionary) -> Dictionary:
    var recipient_id := target_id if target_id != "" else attacker_id
    var row: Dictionary = combatants[recipient_id]
    var amount := 10
    row["guard_bonus"] = maxi(int(row.get("guard_bonus", 0)), amount)
    combatants[recipient_id] = row
    var result := {"ok":true, "hit":true, "non_damage":true, "basic_action":true, "action_id":str(action.get("id", "")), "basic_action_name":str(action.get("name", "")), "attacker":attacker_id, "target":recipient_id, "guard_delta":amount}
    action_log.append(result.duplicate(true))
    return result

func _resolve_basic_control(attacker_id: String, target_id: String, action: Dictionary) -> Dictionary:
    var target: Dictionary = combatants[target_id]
    var kind := str(action.get("kind", "control"))
    var status := "MARKED" if kind.find("mark") >= 0 or kind.find("diagnostic") >= 0 else ("DISORIENTED" if kind.find("fear") >= 0 or kind.find("debuff") >= 0 else "STAGGER")
    target["statuses"] = _add_status(target.get("statuses", {}), status, 1, 1)
    combatants[target_id] = target
    var result := {"ok":true, "hit":true, "non_damage":true, "basic_action":true, "action_id":str(action.get("id", "")), "basic_action_name":str(action.get("name", "")), "attacker":attacker_id, "target":target_id, "status_applied":status}
    action_log.append(result.duplicate(true))
    return result

func _resolve_basic_reposition(attacker_id: String, action: Dictionary) -> Dictionary:
    var row: Dictionary = combatants[attacker_id]
    var before := int(row.get("combat_rank", 1))
    var kind := str(action.get("kind", "reposition"))
    var after := before
    if kind.find("retreat") >= 0 or str(action.get("name", "")).to_lower().find("recul") >= 0:
        after = mini(4, before + 1)
    elif kind.find("advance") >= 0 or str(action.get("name", "")).to_lower().find("reprise") >= 0:
        after = maxi(1, before - 1)
    else:
        var natural := basic_actions.natural_ranks_for(attacker_id, row)
        if not natural.is_empty():
            var preferred := natural[0]
            if preferred > before:
                after = before + 1
            elif preferred < before:
                after = before - 1
    row["combat_rank"] = after
    combatants[attacker_id] = row
    var result := {"ok":true, "hit":true, "non_damage":true, "basic_action":true, "action_id":str(action.get("id", "")), "basic_action_name":str(action.get("name", "")), "attacker":attacker_id, "target":attacker_id, "rank_before":before, "rank_after":after}
    action_log.append(result.duplicate(true))
    return result

func _resolve_justified_restore(attacker_id: String, target_id: String, action: Dictionary) -> Dictionary:
    var kind := str(action.get("kind", ""))
    var attacker: Dictionary = combatants[attacker_id]
    var provenance := ""
    var amount := 0
    if kind == "self_restore_from_drain":
        amount = int(attacker.get("absorbed_vitality", 0))
        if amount <= 0:
            return {"ok":false, "reason":"no_absorbed_vitality", "action_id":str(action.get("id", ""))}
        attacker["absorbed_vitality"] = 0
        provenance = "absorption"
        combatants[attacker_id] = attacker
    elif kind == "restore_requires_resource":
        var resources := int(attacker.get("medical_resources", 0))
        if resources <= 0:
            return {"ok":false, "reason":"missing_healing_resource", "action_id":str(action.get("id", ""))}
        attacker["medical_resources"] = resources - 1
        combatants[attacker_id] = attacker
        amount = 10
        provenance = "consumable"
    else:
        return {"ok":false, "reason":"healing_provenance_missing", "action_id":str(action.get("id", ""))}
    var target: Dictionary = combatants[target_id]
    var before := int(target.get("hp", 0))
    target["hp"] = mini(int(target.get("max_hp", 1)), before + amount)
    combatants[target_id] = target
    var result := {"ok":true, "hit":true, "non_damage":true, "basic_action":true, "action_id":str(action.get("id", "")), "basic_action_name":str(action.get("name", "")), "attacker":attacker_id, "target":target_id, "healed":int(target["hp"]) - before, "healing_provenance":provenance, "persistent_injury_healed":false}
    action_log.append(result.duplicate(true))
    return result

func _is_restore_kind(kind: String) -> bool:
    return kind.find("restore") >= 0 or kind == "drain_heal"

func _is_reposition_kind(kind: String) -> bool:
    return kind.find("reposition") >= 0 or kind in ["advance", "retreat"]

func _is_defense_kind(kind: String) -> bool:
    return kind.find("guard") >= 0 or kind in ["defense", "adaptive_defense", "riposte"]

func _is_non_damage_control(kind: String) -> bool:
    return kind in ["mark", "fear", "madness_pressure", "debuff", "group_debuff", "interrupt", "timeline_control", "accuracy_control", "precision_setup", "diagnostic_debuff", "coordination", "formation", "control", "limb_control", "stability_control", "rank_lock", "grab", "pull"]

func _is_damage_kind(kind: String) -> bool:
    return not _is_restore_kind(kind) and not _is_reposition_kind(kind) and not _is_defense_kind(kind) and not _is_non_damage_control(kind)

func _enemy_support(attacker_id: String, target_id: String, reason: String) -> Dictionary:
    return {"ok":false, "reason":"generic_enemy_support_forbidden", "enemy":attacker_id, "target":target_id, "decision_reason":reason}
