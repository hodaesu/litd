extends RefCounted

static func preview(enemy: Dictionary) -> Dictionary:
    var readiness := CreatureManager.capture_readiness(enemy).duplicate(true)
    var state := str(readiness.get("state", "hidden"))
    var reason_code := ""
    var reason_text := ""
    match state:
        "weaken":
            reason_code = "target_too_strong"
            reason_text = "Affaiblir la cible avant de tenter le lien."
        "no_essence":
            reason_code = "insufficient_essence"
            reason_text = "Essence insuffisante pour tracer le sceau."
        "ready":
            reason_code = "ready"
            reason_text = "Les conditions du lien sont réunies."
        _:
            if not CreatureManager.is_capturable(enemy):
                reason_code = "not_capturable"
                reason_text = "Cette cible ne peut pas rejoindre les auxiliaires."
            elif int(enemy.get("hp", 0)) <= 0:
                reason_code = "target_dead"
                reason_text = "Le lien exige une cible encore vivante."
            elif bool(enemy.get("captured", false)):
                reason_code = "already_resolved"
                reason_text = "Le lien avec cette cible est déjà résolu."
            else:
                reason_code = "capture_locked"
                reason_text = "Le rite de liaison n'est pas encore accessible."
    readiness["reason_code"] = reason_code
    readiness["reason_text"] = reason_text
    if str(readiness.get("label", "")) == "" and reason_text != "":
        readiness["label"] = reason_text
    return readiness

static func attempt(enemy: Dictionary, roll_override: int = -1) -> Dictionary:
    var readiness := preview(enemy)
    if not bool(readiness.get("ready", false)):
        return {
            "success": false,
            "consumed": false,
            "reason_code": str(readiness.get("reason_code", "not_ready")),
            "message": str(readiness.get("reason_text", readiness.get("label", "Lien impossible."))),
            "target_remains_enemy": int(enemy.get("hp", 0)) > 0 and not bool(enemy.get("captured", false))
        }

    var definition: Dictionary = CreatureManager.definition_for_battle_enemy(enemy)
    if definition.is_empty():
        return {"success": false, "consumed": false, "reason_code": "definition_missing", "message": "Définition de capture absente."}
    var capture: Dictionary = definition.get("capture", {})
    var essence_cost := int(capture.get("essence_cost", 3))
    if GameState.essence < essence_cost:
        return {"success": false, "consumed": false, "reason_code": "insufficient_essence", "message": "Essence insuffisante."}

    GameState.essence -= essence_cost
    CreatureManager.capture_attempt_counter += 1
    var chance := CreatureManager.capture_chance(enemy)
    var roll := roll_override
    if roll < 1:
        var rng := RandomNumberGenerator.new()
        var encounter_hash := hash(str(definition.get("encounter_id", "")))
        rng.seed = CreatureManager.capture_seed ^ (int(enemy.get("id", 0)) * 73856093) ^ encounter_hash ^ (CreatureManager.capture_attempt_counter * 19349663)
        roll = rng.randi_range(1, 100)
    roll = clampi(roll, 1, 100)

    if roll > chance:
        var previous_resistance := int(enemy.get("remanence_capture_resistance", 0))
        var resistance_after := mini(40, previous_resistance + 5)
        enemy["remanence_capture_resistance"] = resistance_after
        enemy["capture_failure_count"] = int(enemy.get("capture_failure_count", 0)) + 1
        enemy["capture_rejection_aggressive"] = true
        enemy["intent"] = "aggressive_rejection"
        if str(enemy.get("remanence_id", "")) != "":
            RemanenceRuntime.record_enemy_event(enemy, "capture_escaped", {
                "attempt": int(enemy.get("capture_failure_count", 0)),
                "resistance_after": resistance_after,
                "summary": "Le sceau échoue et la cible mémorise le lien."
            })
        return {
            "success": false,
            "consumed": true,
            "reason_code": "capture_failed",
            "roll": roll,
            "chance": chance,
            "resistance_before": previous_resistance,
            "resistance_after": resistance_after,
            "target_remains_enemy": int(enemy.get("hp", 0)) > 0 and not bool(enemy.get("captured", false)),
            "updated_intent": EnemyCombatDirector.intent_preview(enemy),
            "message": "Le lien échoue ; la cible rejette le sceau et se prépare à riposter."
        }

    var creature_value: Variant = CreatureManager.call("_create_creature", definition)
    var creature: Dictionary = creature_value if creature_value is Dictionary else {}
    if creature.is_empty():
        return {"success": false, "consumed": true, "reason_code": "creature_creation_failed", "message": "Le lien n'a pas pu être matérialisé."}
    CreatureManager.captured_creatures.append(creature)
    if CreatureManager.active_instance_id == "":
        CreatureManager.active_instance_id = str(creature.get("instance_id", ""))
    enemy["hp"] = 0
    enemy["captured"] = true
    CreatureManager.creatures_changed.emit()
    CreatureManager.creature_captured.emit(creature.duplicate(true))
    return {
        "success": true,
        "consumed": true,
        "reason_code": "captured",
        "roll": roll,
        "chance": chance,
        "creature": creature.duplicate(true),
        "removed_from_combat": int(enemy.get("hp", 0)) <= 0 and bool(enemy.get("captured", false)),
        "auxiliary_only": true,
        "message": "%s rejoint les auxiliaires." % str(creature.get("name", "La créature"))
    }
