extends Node

const ULTIMATE_STATE_SCRIPT := preload("res://scripts/core/veilleurs_ultimate_state_runtime.gd")
const CURRENT_ULTIMATES_PATH := "res://data/veilleurs/current_quartet_ultimate_sheets.json"

const EXPECTED_HEROES := {
    "mathilde": ["Cœur inébranlable", "Katana éternel", "Volonté transcendante"],
    "marec": ["Force primordiale", "Instinct parfait", "Légende vivante"],
    "anouk": ["Trame absolue", "Esprit transcendant", "Ange de la Trame"],
    "aurelien": ["Réminiscence du Sang", "Miroir du Jugement", "Réforme éternelle"],
}

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var state_runtime: VeilleursUltimateStateRuntime = ULTIMATE_STATE_SCRIPT.new() as VeilleursUltimateStateRuntime
    _check(state_runtime.charges_for_level(15) == 0, "ultimate locked before level 16")
    _check(state_runtime.charges_for_level(16) == 1, "level 16 grants one charge")
    _check(state_runtime.charges_for_level(32) == 2, "level 32 grants two charges")
    _check(state_runtime.charges_for_level(48) == 3, "level 48 grants three charges")

    var payload := _load_json(CURRENT_ULTIMATES_PATH)
    _check(str(payload.get("status", "")) == "CURRENT_QUARTET_AUTHORED_IDENTITY_LOCK", "current quartet identity lock is authoritative")
    var progression: Dictionary = payload.get("charge_progression", {})
    _check(int(progression.get("16", 0)) == 1, "identity contract keeps level 16 charge")
    _check(int(progression.get("32", 0)) == 2, "identity contract keeps level 32 charges")
    _check(int(progression.get("48", 0)) == 3, "identity contract keeps level 48 charges")

    var seen: Dictionary = {}
    var ultimate_count := 0
    for hero_value: Variant in payload.get("heroes", []):
        var hero: Dictionary = hero_value
        var hero_id := str(hero.get("hero_id", ""))
        seen[hero_id] = true
        var expected_names: Array = EXPECTED_HEROES.get(hero_id, [])
        var actual_names: Array[String] = []
        for ultimate_value: Variant in hero.get("ultimates", []):
            var ultimate: Dictionary = ultimate_value
            ultimate_count += 1
            actual_names.append(str(ultimate.get("name", "")))
            _check(bool(ultimate.get("identity_locked", false)), "%s ultimate identity remains locked" % hero_id)
            _check(str(ultimate.get("runtime_effect_status", "")) == "PENDING_RESOLVER_BINDING", "%s ultimate mechanics remain pending instead of inheriting legacy mechanics" % hero_id)
        _check(actual_names == expected_names, "%s exposes the three current canonical ultimate identities" % hero_id)

    _check(seen.size() == 4, "exactly four current heroes own ultimate sheets")
    for hero_id: String in EXPECTED_HEROES.keys():
        _check(bool(seen.get(hero_id, false)), "current ultimate sheet contains %s" % hero_id)
    _check(ultimate_count == 12, "current quartet owns twelve signature ultimates")

    var serialized := JSON.stringify(payload)
    _check(not serialized.contains("Le Dernier Battement"), "legacy Hemocorde ultimate is not rebound into the current quartet")
    _check(not serialized.contains("aisha_maren"), "legacy Aïsha binding is absent from the current ultimate authority")

    _finish()

func _load_json(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        failures.append("cannot open current quartet ultimate identity sheet")
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        failures.append("current quartet ultimate identity sheet must parse as an object")
        return {}
    return parsed as Dictionary

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_V062_HEMOCORDE_ULTIMATE_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_V062_ULTIMATE_IDENTITY: " + failure)
    print("VEILLEURS_V062_HEMOCORDE_ULTIMATE_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
