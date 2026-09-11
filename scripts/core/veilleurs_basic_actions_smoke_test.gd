extends Node

const SERVICE_SCRIPT := preload("res://scripts/core/veilleurs_basic_action_service.gd")
const RUNTIME_SCRIPT := preload("res://scripts/core/veilleurs_tactical_combat_runtime_v3.gd")

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
    _check(watchers.size() == 4, "four canonical Watchers have base actions")
    _check(enemies.size() == 24, "all 24 enemies have base actions")

    for entity_value: Variant in watchers.keys():
        var entity_id := str(entity_value)
        var actions := service.actions_for(entity_id)
        _check(actions.size() == 4, "%s has exactly four base actions" % entity_id)
        var natural := service.natural_ranks_for(entity_id)
        for rank: int in natural:
            _check(not service.available_actions(entity_id, {}, rank).is_empty(), "%s can act from natural R%d" % [entity_id, rank])
        for action: Dictionary in actions:
            _check(str(action.get("name", "")).to_lower() not in ["frappe", "soin"], "%s has no generic strike/heal name" % entity_id)

    for entity_value: Variant in enemies.keys():
        var entity_id := str(entity_value)
        var actions := service.actions_for(entity_id)
        _check(actions.size() == 4, "%s has exactly four base actions" % entity_id)
        for action: Dictionary in actions:
            _check(str(action.get("name", "")).to_lower() not in ["frappe", "soin"], "%s has no generic strike/heal name" % entity_id)

    var marec_actions := service.actions_for("ENT_WATCHER_marec")
    for action: Dictionary in marec_actions:
        _check(str(action.get("kind", "")).find("restore") < 0, "Marec has no free healing base action")

    var duplicate_row := {"definition_id":"ENT_ENEMY_GOULE_AFFAMEE"}
    var original := service.actions_for("ENT_ENEMY_GOULE_AFFAMEE")
    var recruited := service.actions_for("ENT_ENEMY_GOULE_AFFAMEE#02", duplicate_row)
    _check(original == recruited, "enemy/recruited duplicate keeps identical proprietary actions")

    var runtime := RUNTIME_SCRIPT.new() as VeilleursTacticalCombatRuntimeV3
    var setup := runtime.setup_first_combat()
    _check(bool(setup.get("ok", false)) and bool(setup.get("basic_actions_ready", false)), "runtime v3 initializes with base actions")
    if bool(setup.get("ok", false)):
        for watcher_id in ["ENT_WATCHER_marec", "ENT_WATCHER_mathilde", "ENT_WATCHER_anouk", "ENT_WATCHER_aurelien"]:
            _check(runtime.basic_actions_for(watcher_id).size() == 4, "%s exposes four actions at runtime" % watcher_id)
            _check(not runtime.available_basic_actions(watcher_id).is_empty(), "%s has an action from starter rank" % watcher_id)
        var forbidden := runtime.call("_enemy_support", "ENT_ENEMY_GOULE_AFFAMEE", "ENT_ENEMY_ECORCHEUSE", "legacy") as Dictionary
        _check(str(forbidden.get("reason", "")) == "generic_enemy_support_forbidden", "legacy generic enemy heal path is disabled")
        var ghoul_actions := runtime.basic_actions_for("ENT_ENEMY_GOULE_AFFAMEE")
        _check(ghoul_actions.size() == 4, "Ghoul exposes four proprietary actions at runtime")

    _finish()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_BASIC_ACTIONS_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_BASIC_ACTIONS: " + failure)
    print("VEILLEURS_BASIC_ACTIONS_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
