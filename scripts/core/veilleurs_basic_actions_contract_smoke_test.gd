extends Node

const SERVICE_SCRIPT := preload("res://scripts/core/veilleurs_basic_action_service.gd")

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var service := SERVICE_SCRIPT.new() as VeilleursBasicActionService
    _check(service != null and service.is_valid(), "base-action contract validates")
    if service == null:
        _finish()
        return

    var payload: Dictionary = service.payload
    var watchers: Dictionary = payload.get("watchers", {})
    var enemies: Dictionary = payload.get("enemies", {})
    _check(watchers.size() == 4, "four canonical Veilleurs have base actions")
    _check(enemies.size() == 24, "all 24 enemies have base actions")

    for entity_value: Variant in watchers.keys():
        var entity_id := str(entity_value)
        var actions := service.actions_for(entity_id)
        _check(actions.size() == 4, "%s has exactly four base actions" % entity_id)
        for rank: int in service.natural_ranks_for(entity_id):
            _check(not service.available_actions(entity_id, {}, rank).is_empty(), "%s can act from natural R%d" % [entity_id, rank])
        for action: Dictionary in actions:
            _check(str(action.get("name", "")).strip_edges().to_lower() not in ["frappe", "soin"], "%s has no generic strike/heal name" % entity_id)

    for entity_value: Variant in enemies.keys():
        var entity_id := str(entity_value)
        var actions := service.actions_for(entity_id)
        _check(actions.size() == 4, "%s has exactly four base actions" % entity_id)
        for action: Dictionary in actions:
            _check(str(action.get("name", "")).strip_edges().to_lower() not in ["frappe", "soin"], "%s has no generic strike/heal name" % entity_id)

    var recruited := service.actions_for("ENT_ENEMY_GOULE_AFFAMEE#02", {"definition_id":"ENT_ENEMY_GOULE_AFFAMEE"})
    _check(recruited == service.actions_for("ENT_ENEMY_GOULE_AFFAMEE"), "captured/recruited enemy keeps identical base actions")
    _finish()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_BASIC_ACTIONS_CONTRACT_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_BASIC_ACTIONS_CONTRACT: " + failure)
    print("VEILLEURS_BASIC_ACTIONS_CONTRACT_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
