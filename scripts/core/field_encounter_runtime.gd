extends Node

signal encounter_opened(event_id: String)
signal encounter_resolved(event_id: String, outcome: String)
signal encounter_returned(event_id: String, source_event: String)

const DATA_PATH := "res://data/field_encounters.json"
const OVERLAY_NAME := "FieldEncounterOverlay"

var data: Dictionary = {}
var resolved: Dictionary = {}
var active_event_id: String = ""
var _overlay: CanvasLayer = null
var _disabled_parties: Array[Node] = []

func _ready() -> void:
    _load_data()

func _load_data() -> void:
    if not FileAccess.file_exists(DATA_PATH):
        data = {}
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    data = parsed if parsed is Dictionary else {}

func reset_new_game() -> void:
    resolved.clear()
    active_event_id = ""
    _close_overlay()

func definition(event_id: String) -> Dictionary:
    for value in data.get("encounters", []):
        var item: Dictionary = value if value is Dictionary else {}
        if str(item.get("id", "")) == event_id:
            return item.duplicate(true)
    return {}

func encounters_for(chapter_number: int, zone_id: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value in data.get("encounters", []):
        var item: Dictionary = value if value is Dictionary else {}
        if int(item.get("chapter", 0)) != chapter_number:
            continue
        if str(item.get("zone_id", "")) != zone_id:
            continue
        if can_spawn(item):
            result.append(item.duplicate(true))
    return result

func can_spawn(item: Dictionary) -> bool:
    var event_id: String = str(item.get("id", ""))
    if event_id == "" or resolved.has(event_id):
        return false
    var source_event: String = str(item.get("source_event", ""))
    if source_event != "":
        var source_state: Dictionary = _resolved_state(source_event)
        if source_state.is_empty():
            return false
        var allowed_value: Variant = item.get("source_outcomes", [])
        var allowed: Array = allowed_value if allowed_value is Array else []
        if not allowed.is_empty() and not allowed.has(str(source_state.get("outcome", ""))):
            return false
    var boss_condition_value: Variant = item.get("requires_boss_outcome", {})
    var boss_condition: Dictionary = boss_condition_value if boss_condition_value is Dictionary else {}
    if not boss_condition.is_empty():
        var encounter_id: String = str(boss_condition.get("encounter_id", ""))
        var required_outcome: String = str(boss_condition.get("outcome", ""))
        if _boss_outcome(encounter_id) != required_outcome:
            return false
    return true

func is_resolved(event_id: String) -> bool:
    return resolved.has(event_id)

func outcome_for(event_id: String) -> String:
    return str(_resolved_state(event_id).get("outcome", ""))

func open_encounter(event_id: String) -> bool:
    if active_event_id != "":
        return false
    var item: Dictionary = definition(event_id)
    if item.is_empty() or not can_spawn(item):
        return false
    active_event_id = event_id
    _disable_party_motion()
    _build_overlay(item)
    encounter_opened.emit(event_id)
    return true

func resolve_choice(event_id: String, choice_id: String) -> Dictionary:
    var item: Dictionary = definition(event_id)
    if item.is_empty() or resolved.has(event_id):
        return {"applied": false, "reason": "already_resolved"}
    if str(item.get("type", "")) != "survivor_choice":
        return {"applied": false, "reason": "not_a_choice"}
    var choice: Dictionary = _choice(item, choice_id)
    if choice.is_empty():
        return {"applied": false, "reason": "unknown_choice"}
    var cost_value: Variant = choice.get("cost", {})
    var cost: Dictionary = cost_value if cost_value is Dictionary else {}
    if not ExpeditionManager.can_pay(cost):
        return {"applied": false, "reason": "insufficient_resources", "missing": _missing(cost)}
    if not cost.is_empty():
        ExpeditionManager.consume_bundle(cost)
    var outcome: String = str(choice.get("outcome", choice_id))
    var witnesses: Array[String] = _witness_ids()
    resolved[event_id] = {
        "event_id": event_id,
        "type": str(item.get("type", "")),
        "choice_id": choice_id,
        "outcome": outcome,
        "chapter_id": CampaignState.current_chapter_id,
        "zone_id": AshlandsRuntime.current_zone_id,
        "witnesses": witnesses,
        "result": str(choice.get("result", ""))
    }
    var memory_choice: String = str(choice.get("memory_choice", "keep"))
    var memory_label: String = str(choice.get("memory_label", choice.get("label", choice_id)))
    FieldMemoryRuntime.record_resource_choice(event_id, memory_choice, memory_label)
    var result_text: String = str(choice.get("result", "Le groupe reprend sa route."))
    GameState.add_log("RENCONTRE — " + result_text)
    encounter_resolved.emit(event_id, outcome)
    _finish_active_event()
    return {"applied": true, "event_id": event_id, "outcome": outcome, "result": result_text}

func resolve_return(event_id: String) -> Dictionary:
    var item: Dictionary = definition(event_id)
    if item.is_empty() or resolved.has(event_id) or str(item.get("type", "")) != "return":
        return {"applied": false}
    if not can_spawn(item):
        return {"applied": false, "reason": "conditions_not_met"}
    var payload: Dictionary = _return_payload(item)
    var reward_value: Variant = payload.get("reward", item.get("reward", {}))
    var reward: Dictionary = reward_value if reward_value is Dictionary else {}
    for key_value in reward.keys():
        ExpeditionManager.add_resource(str(key_value), int(reward.get(key_value, 0)))
    var reevaluation: String = str(item.get("reevaluation", ""))
    if reevaluation != "":
        FieldMemoryRuntime.reevaluate(reevaluation, str(item.get("reevaluation_target", "")))
    var source_event: String = str(item.get("source_event", ""))
    var outcome: String = "returned"
    resolved[event_id] = {
        "event_id": event_id,
        "type": "return",
        "outcome": outcome,
        "chapter_id": CampaignState.current_chapter_id,
        "zone_id": AshlandsRuntime.current_zone_id,
        "source_event": source_event,
        "source_outcome": outcome_for(source_event),
        "reward": reward.duplicate(true),
        "witnesses": _witness_ids(),
        "result": str(payload.get("result", item.get("result", "")))
    }
    var result_text: String = str(payload.get("result", item.get("result", "Cette rencontre donne une suite au choix passé.")))
    GameState.add_log("RETOUR — " + result_text)
    encounter_returned.emit(event_id, source_event)
    encounter_resolved.emit(event_id, outcome)
    _finish_active_event()
    return {"applied": true, "event_id": event_id, "outcome": outcome, "reward": reward, "result": result_text}

func serialize() -> Dictionary:
    return {"resolved": resolved.duplicate(true)}

func deserialize(payload: Dictionary) -> void:
    var stored_value: Variant = payload.get("resolved", {})
    resolved = stored_value.duplicate(true) if stored_value is Dictionary else {}
    active_event_id = ""
    _close_overlay()

func _resolved_state(event_id: String) -> Dictionary:
    var value: Variant = resolved.get(event_id, {})
    return value if value is Dictionary else {}

func _choice(item: Dictionary, choice_id: String) -> Dictionary:
    for value in item.get("choices", []):
        var choice: Dictionary = value if value is Dictionary else {}
        if str(choice.get("id", "")) == choice_id:
            return choice
    return {}

func _return_payload(item: Dictionary) -> Dictionary:
    var variants_value: Variant = item.get("variants", {})
    var variants: Dictionary = variants_value if variants_value is Dictionary else {}
    if variants.is_empty():
        return item
    var source_event: String = str(item.get("source_event", ""))
    var source_outcome: String = outcome_for(source_event)
    var variant_value: Variant = variants.get(source_outcome, {})
    return variant_value if variant_value is Dictionary else item

func _boss_outcome(encounter_id: String) -> String:
    if encounter_id == "":
        return ""
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        var memories_value: Variant = hero.get("field_memories", [])
        var memories: Array = memories_value if memories_value is Array else []
        for memory_value in memories:
            var memory: Dictionary = memory_value if memory_value is Dictionary else {}
            if str(memory.get("encounter_id", "")) == encounter_id and str(memory.get("type", "")) in ["boss_spared", "boss_executed"]:
                return str(memory.get("outcome", ""))
    return ""

func _witness_ids() -> Array[String]:
    var result: Array[String] = []
    for hero_value in GameState.alive_heroes():
        var hero: Dictionary = hero_value
        var hero_id: String = str(hero.get("id", ""))
        if hero_id != "":
            result.append(hero_id)
    return result

func _missing(cost: Dictionary) -> Array[String]:
    var result: Array[String] = []
    for key_value in cost.keys():
        var key: String = str(key_value)
        if int(ExpeditionManager.inventory.get(key, 0)) < int(cost.get(key_value, 0)):
            result.append(key)
    return result

func _disable_party_motion() -> void:
    _disabled_parties.clear()
    for node_value in get_tree().get_nodes_in_group("player_party"):
        var node: Node = node_value
        if node.is_physics_processing():
            node.set_physics_process(false)
            _disabled_parties.append(node)

func _restore_party_motion() -> void:
    for node in _disabled_parties:
        if is_instance_valid(node):
            node.set_physics_process(true)
    _disabled_parties.clear()

func _finish_active_event() -> void:
    active_event_id = ""
    _close_overlay()
    _restore_party_motion()

func _close_overlay() -> void:
    if is_instance_valid(_overlay):
        _overlay.queue_free()
    _overlay = null

func _build_overlay(item: Dictionary) -> void:
    _close_overlay()
    _overlay = CanvasLayer.new()
    _overlay.name = OVERLAY_NAME
    _overlay.layer = 80
    get_tree().root.add_child(_overlay)

    var shade := ColorRect.new()
    shade.color = Color(0.01, 0.012, 0.018, 0.92)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _overlay.add_child(shade)

    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.position = Vector2(-390, -265)
    panel.size = Vector2(780, 530)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.035, 0.037, 0.048, 0.98)
    style.border_color = Color(0.45, 0.34, 0.20, 0.9)
    style.set_border_width_all(2)
    style.corner_radius_top_left = 6
    style.corner_radius_top_right = 6
    style.corner_radius_bottom_left = 6
    style.corner_radius_bottom_right = 6
    style.content_margin_left = 26
    style.content_margin_right = 26
    style.content_margin_top = 22
    style.content_margin_bottom = 22
    panel.add_theme_stylebox_override("panel", style)
    _overlay.add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    panel.add_child(box)

    var kicker := Label.new()
    kicker.text = "RENCONTRE DE TERRAIN"
    kicker.add_theme_font_size_override("font_size", 14)
    kicker.add_theme_color_override("font_color", Color("#a49884"))
    box.add_child(kicker)

    var title := Label.new()
    title.text = str(item.get("name", "Rencontre"))
    title.add_theme_font_size_override("font_size", 28)
    title.add_theme_color_override("font_color", Color("#d5b26c"))
    box.add_child(title)

    var payload: Dictionary = _return_payload(item) if str(item.get("type", "")) == "return" else item
    var description := Label.new()
    description.text = str(payload.get("prompt", item.get("prompt", "")))
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description.custom_minimum_size = Vector2(720, 120)
    description.add_theme_font_size_override("font_size", 17)
    description.add_theme_color_override("font_color", Color("#e5dccb"))
    box.add_child(description)

    var resources := Label.new()
    resources.text = _resource_line()
    resources.add_theme_font_size_override("font_size", 14)
    resources.add_theme_color_override("font_color", Color("#a49884"))
    box.add_child(resources)

    if str(item.get("type", "")) == "return":
        var continue_button := _make_choice_button("ÉCOUTER ET POURSUIVRE", "Ce qui revient aujourd'hui modifiera la mémoire du choix passé.")
        continue_button.pressed.connect(func() -> void: resolve_return(str(item.get("id", ""))))
        box.add_child(continue_button)
        return

    for choice_value in item.get("choices", []):
        var choice: Dictionary = choice_value if choice_value is Dictionary else {}
        var choice_id: String = str(choice.get("id", ""))
        var label: String = str(choice.get("label", choice_id))
        var detail: String = str(choice.get("detail", ""))
        var button := _make_choice_button(label, detail)
        var cost_value: Variant = choice.get("cost", {})
        var cost: Dictionary = cost_value if cost_value is Dictionary else {}
        button.disabled = not ExpeditionManager.can_pay(cost)
        if button.disabled:
            button.text += "\nRESSOURCES INSUFFISANTES"
        button.pressed.connect(func(id: String = choice_id) -> void: resolve_choice(str(item.get("id", "")), id))
        box.add_child(button)

func _make_choice_button(label: String, detail: String) -> Button:
    var button := Button.new()
    button.text = label + ("\n" + detail if detail != "" else "")
    button.custom_minimum_size = Vector2(720, 62)
    button.add_theme_font_size_override("font_size", 15)
    button.add_theme_color_override("font_color", Color("#e5dccb"))
    return button

func _resource_line() -> String:
    return "Réserves — nourriture %d · eau %d · bandages %d · médicaments %d · lumière %d" % [
        int(ExpeditionManager.inventory.get("food", 0)),
        int(ExpeditionManager.inventory.get("water", 0)),
        int(ExpeditionManager.inventory.get("bandages", 0)),
        int(ExpeditionManager.inventory.get("medicine", 0)),
        int(ExpeditionManager.inventory.get("light", 0))
    ]
