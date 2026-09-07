extends RefCounted
class_name VeilleursBossRuleRuntime

const MAX_OBSERVED_ACTIONS := 8
const MAX_JUDGMENT_FLAGS := 4

var boss_id := ""
var phase := 1
var round_index := 0
var observed_actions: Array[String] = []
var campaign_flags: Array[String] = []
var locked_cells: Array[Vector2i] = []
var mutation_stacks := 0
var active_counter := ""

func begin(value: String, context: Dictionary = {}) -> Dictionary:
    boss_id = value
    phase = 1
    round_index = 0
    observed_actions.clear()
    locked_cells.clear()
    mutation_stacks = 0
    campaign_flags.clear()
    for flag_value: Variant in context.get("campaign_flags", []):
        var flag := str(flag_value)
        if flag != "" and not campaign_flags.has(flag):
            campaign_flags.append(flag)
        if campaign_flags.size() >= MAX_JUDGMENT_FLAGS:
            break
    active_counter = str(context.get("countermeasure", ""))
    return snapshot()

func register_player_action(action_tag: String) -> void:
    if action_tag == "":
        return
    observed_actions.append(action_tag)
    while observed_actions.size() > MAX_OBSERVED_ACTIONS:
        observed_actions.pop_front()

func before_round(runtime: Variant) -> Dictionary:
    round_index += 1
    phase = 1 + int(round_index >= 3) + int(round_index >= 6)
    match boss_id:
        "ENT_BOSS_GARDIEN_SEUIL":
            return _gardien_rule(runtime)
        "ENT_BOSS_CHOEUR_FENDU":
            return _choeur_rule()
        "ENT_BOSS_MERE_MUES":
            return _mere_rule(runtime)
        "ENT_BOSS_JUGE_SANS_VISAGE":
            return _juge_rule()
        "ENT_BOSS_ARCHIVISTE_AVEUGLE":
            return _archiviste_rule()
        _:
            return {"ok":false, "reason":"unknown_boss"}

func after_body_change(runtime: Variant) -> Dictionary:
    if boss_id != "ENT_BOSS_MERE_MUES" or runtime == null or not runtime.combatants.has(boss_id):
        return {}
    var row: Dictionary = runtime.combatants[boss_id]
    var body: Variant = row.get("body")
    if body == null or not body.has_method("serialize"):
        return {}
    var states: Dictionary = (body.call("serialize") as Dictionary).get("states", {})
    var severe := 0
    for state_value: Variant in states.values():
        var state := str(state_value)
        var level := int(state.trim_prefix("L")) if state.begins_with("L") else 0
        if level >= 3:
            severe += 1
    mutation_stacks = mini(3, severe)
    row["mutation_stacks"] = mutation_stacks
    row["evasive_bonus"] = mutation_stacks * 3
    row["guard_bonus"] = maxi(int(row.get("guard_bonus", 0)), mutation_stacks * 4)
    runtime.combatants[boss_id] = row
    return {"boss":boss_id, "mutation_stacks":mutation_stacks, "telegraph":"La Mère transforme ses blessures en nouvelle posture."}

func snapshot() -> Dictionary:
    return {
        "boss_id":boss_id,
        "phase":phase,
        "round":round_index,
        "observed_actions":observed_actions.duplicate(),
        "campaign_flags":campaign_flags.duplicate(),
        "locked_cells":_serialize_cells(locked_cells),
        "mutation_stacks":mutation_stacks,
        "active_counter":active_counter
    }

func restore(payload: Dictionary) -> void:
    boss_id = str(payload.get("boss_id", ""))
    phase = maxi(1, int(payload.get("phase", 1)))
    round_index = maxi(0, int(payload.get("round", 0)))
    observed_actions.clear()
    for value: Variant in payload.get("observed_actions", []):
        observed_actions.append(str(value))
    while observed_actions.size() > MAX_OBSERVED_ACTIONS:
        observed_actions.pop_front()
    campaign_flags.clear()
    for value: Variant in payload.get("campaign_flags", []):
        campaign_flags.append(str(value))
        if campaign_flags.size() >= MAX_JUDGMENT_FLAGS:
            break
    locked_cells.clear()
    for value: Variant in payload.get("locked_cells", []):
        if value is Array and (value as Array).size() >= 2:
            var coords: Array = value
            locked_cells.append(Vector2i(int(coords[0]), int(coords[1])))
    mutation_stacks = clampi(int(payload.get("mutation_stacks", 0)), 0, 3)
    active_counter = str(payload.get("active_counter", ""))

func _gardien_rule(runtime: Variant) -> Dictionary:
    locked_cells.clear()
    var desired := mini(3, phase)
    var candidates: Array[Vector2i] = [Vector2i(2, 1), Vector2i(2, 3), Vector2i(3, 2)]
    for cell: Vector2i in candidates:
        if locked_cells.size() >= desired:
            break
        if runtime != null and runtime.grid != null and runtime.grid.inside(cell) and not runtime.grid.occupied(cell):
            locked_cells.append(cell)
    return {"ok":true, "boss":boss_id, "phase":phase, "locked_cells":_serialize_cells(locked_cells), "counter":"change_lane_before_lock", "telegraph":"Le Gardien désigne les cases qui vont devenir interdites."}

func _choeur_rule() -> Dictionary:
    var uncertainty := mini(3, phase)
    return {"ok":true, "boss":boss_id, "phase":phase, "uncertainty_tokens":uncertainty, "counter":"compare_tells_and_previous_pattern", "telegraph":"Les voix divergent, mais une seule répétition conserve le même rythme."}

func _mere_rule(runtime: Variant) -> Dictionary:
    var mutation := after_body_change(runtime)
    mutation["ok"] = true
    mutation["phase"] = phase
    mutation["counter"] = "vary_damage_zones_and_delay_mutilation"
    if not mutation.has("telegraph"):
        mutation["telegraph"] = "La chair se prépare à répondre à la prochaine lésion grave."
    return mutation

func _juge_rule() -> Dictionary:
    var applied: Array[String] = []
    for flag: String in campaign_flags:
        applied.append(flag)
        if applied.size() >= phase + 1:
            break
    return {"ok":true, "boss":boss_id, "phase":phase, "judgments":applied, "counter":"use_recorded_context_and_accept_tradeoff", "telegraph":"Le Juge cite uniquement des choix réellement consignés dans la campagne."}

func _archiviste_rule() -> Dictionary:
    var frequencies: Dictionary = {}
    for action: String in observed_actions:
        frequencies[action] = int(frequencies.get(action, 0)) + 1
    var dominant := ""
    var dominant_count := 0
    for key_value: Variant in frequencies.keys():
        var key := str(key_value)
        var count := int(frequencies[key])
        if count > dominant_count:
            dominant_count = count
            dominant = key
    var adaptation := ""
    if dominant_count >= 3:
        adaptation = "counter_%s" % dominant
    return {"ok":true, "boss":boss_id, "phase":phase, "observations":observed_actions.size(), "adaptation":adaptation, "counter":"vary_actions", "telegraph":"L'Archiviste ne contre que les gestes qu'il a réellement vus se répéter."}

func _serialize_cells(cells: Array[Vector2i]) -> Array:
    var result: Array = []
    for cell: Vector2i in cells:
        result.append([cell.x, cell.y])
    return result
