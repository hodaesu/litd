extends Node

signal feedback_requested(title: String, text: String)
signal hero_psychology_changed(hero_id: String, event_id: String)

const DATA_PATH := "res://data/psychology_events.json"
const FEAR_MIN: int = 0
const FEAR_MAX: int = 100
const HISTORY_LIMIT: int = 24
const HOPE_HISTORY_LIMIT: int = 12

var data: Dictionary = {}
var events_by_id: Dictionary = {}
var events_by_trigger: Dictionary = {}

func _ready() -> void:
    _load_data()
    GameState.state_changed.connect(_on_game_state_changed)
    prepare_party()
    call_deferred("_connect_world_signals")

func _load_data() -> void:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    data = parsed if parsed is Dictionary else {}
    events_by_id.clear()
    events_by_trigger.clear()
    for event_value in data.get("events", []):
        var event: Dictionary = event_value
        var event_id := str(event.get("id", ""))
        var trigger := str(event.get("trigger", ""))
        if event_id == "":
            continue
        events_by_id[event_id] = event
        if trigger == "":
            continue
        var bucket: Array = events_by_trigger.get(trigger, [])
        bucket.append(event)
        events_by_trigger[trigger] = bucket

func _connect_world_signals() -> void:
    if not AshlandsRuntime.zone_discovered.is_connected(_on_zone_discovered):
        AshlandsRuntime.zone_discovered.connect(_on_zone_discovered)
    if not AshlandsRuntime.campfire_used.is_connected(_on_campfire_used):
        AshlandsRuntime.campfire_used.connect(_on_campfire_used)
    if not AshlandsRuntime.shortcut_unlocked.is_connected(_on_shortcut_unlocked):
        AshlandsRuntime.shortcut_unlocked.connect(_on_shortcut_unlocked)
    if not AshlandsRuntime.lore_discovered.is_connected(_on_lore_discovered):
        AshlandsRuntime.lore_discovered.connect(_on_lore_discovered)
    if not AshlandsCombatBridge.ashlands_combat_started.is_connected(_on_combat_started):
        AshlandsCombatBridge.ashlands_combat_started.connect(_on_combat_started)
    if not AshlandsCombatBridge.ashlands_combat_finished.is_connected(_on_combat_finished):
        AshlandsCombatBridge.ashlands_combat_finished.connect(_on_combat_finished)

func _on_game_state_changed() -> void:
    prepare_party()

func prepare_party() -> void:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        ensure_hero(hero)

func ensure_hero(hero: Dictionary) -> Dictionary:
    var psychology_value = hero.get("psychology", {})
    var psychology: Dictionary = psychology_value if psychology_value is Dictionary else {}
    if not psychology.has("fear_peak"):
        psychology["fear_peak"] = clampi(int(hero.get("fear", 0)), FEAR_MIN, FEAR_MAX)
    if not psychology.has("madness_exposure"):
        psychology["madness_exposure"] = clampi(int(hero.get("madness", 0)), 0, 100)
    if not psychology.has("legacy_hope_baseline"):
        psychology["legacy_hope_baseline"] = int(hero.get("hope", 0))
    if not psychology.has("traits") or not (psychology.get("traits", []) is Array):
        psychology["traits"] = []
    if not psychology.has("traumas") or not (psychology.get("traumas", []) is Array):
        psychology["traumas"] = []
    if not psychology.has("event_history") or not (psychology.get("event_history", []) is Array):
        psychology["event_history"] = []
    if not psychology.has("hope_history") or not (psychology.get("hope_history", []) is Array):
        psychology["hope_history"] = []
    if not psychology.has("temporary_madness_resistance"):
        psychology["temporary_madness_resistance"] = 0
    if not psychology.has("panic_count"):
        psychology["panic_count"] = 0
    hero["psychology"] = psychology
    hero["fear"] = clampi(int(hero.get("fear", 0)), FEAR_MIN, FEAR_MAX)
    return psychology

func state_for(hero: Dictionary) -> Dictionary:
    return ensure_hero(hero)

func fear_band(hero: Dictionary) -> Dictionary:
    var fear := clampi(int(hero.get("fear", 0)), FEAR_MIN, FEAR_MAX)
    for band_value in data.get("fear_bands", []):
        var band: Dictionary = band_value
        if fear >= int(band.get("min", 0)) and fear <= int(band.get("max", FEAR_MAX)):
            return band
    return {"id": "panic", "label": "Panique", "min": 100, "max": 100}

func fear_band_label(hero: Dictionary) -> String:
    return str(fear_band(hero).get("label", "Inconnu"))

func mental_summary(hero: Dictionary) -> String:
    var psychology := ensure_hero(hero)
    var traumas: Array = psychology.get("traumas", [])
    var traits: Array = psychology.get("traits", [])
    var parts: Array[String] = []
    if not traumas.is_empty():
        parts.append("Trauma : %s" % trait_label(str(traumas[-1])))
    if not traits.is_empty():
        parts.append("Trace : %s" % trait_label(str(traits[-1])))
    return " · ".join(parts) if not parts.is_empty() else "Aucune trace durable"

func trait_label(trait_id: String) -> String:
    return str(data.get("trait_definitions", {}).get(trait_id, {}).get("label", trait_id))

func apply_named_event(event_id: String, context: Dictionary = {}, targets: Array = []) -> Dictionary:
    var event: Dictionary = events_by_id.get(event_id, {})
    if event.is_empty():
        return {"applied": false, "reason": "unknown_event", "event_id": event_id}
    if not _matches_filter(event, context):
        return {"applied": false, "reason": "filter", "event_id": event_id}
    if bool(event.get("once_per_campaign", false)):
        var flag := _once_flag(event_id)
        if bool(CampaignState.chapter_flags.get(flag, false)):
            return {"applied": false, "reason": "already_applied", "event_id": event_id}
        CampaignState.set_chapter_flag(flag, true)

    var resolved_targets := _resolve_targets(event, targets)
    if resolved_targets.is_empty():
        return {"applied": false, "reason": "no_targets", "event_id": event_id}

    var changed_ids: Array[String] = []
    for hero_value in resolved_targets:
        var hero: Dictionary = hero_value
        if hero.is_empty() or int(hero.get("hp", 0)) <= 0:
            continue
        _apply_event_to_hero(hero, event, context)
        changed_ids.append(str(hero.get("id", "")))
        hero_psychology_changed.emit(str(hero.get("id", "")), event_id)

    if changed_ids.is_empty():
        return {"applied": false, "reason": "no_living_targets", "event_id": event_id}

    var log_text := str(event.get("log", ""))
    if log_text != "":
        GameState.add_log(log_text)
    else:
        GameState.state_changed.emit()

    var hope: Dictionary = event.get("hope", {})
    if not hope.is_empty():
        var title := str(hope.get("title", "ESPOIR"))
        var text := str(hope.get("text", ""))
        if text != "":
            feedback_requested.emit(title, text)
            GameState.add_log("%s — %s" % [title, text])

    return {"applied": true, "event_id": event_id, "heroes": changed_ids}

func _apply_event_to_hero(hero: Dictionary, event: Dictionary, context: Dictionary) -> void:
    var psychology := ensure_hero(hero)
    var event_id := str(event.get("id", ""))
    var before_fear := int(hero.get("fear", 0))
    var tags: Array = event.get("tags", [])
    var raw_delta := int(event.get("fear_delta", 0))
    var adjusted_delta := _adjusted_fear_delta(hero, raw_delta, tags, context)
    hero["fear"] = clampi(before_fear + adjusted_delta, FEAR_MIN, FEAR_MAX)

    var stabilize := maxi(0, int(event.get("stabilize_exposure", 0)))
    if stabilize > 0:
        psychology["madness_exposure"] = maxi(0, int(psychology.get("madness_exposure", 0)) - stabilize)

    var hope: Dictionary = event.get("hope", {})
    if not hope.is_empty():
        var relief := maxi(0, int(hope.get("fear_relief", 0)))
        if relief > 0:
            hero["fear"] = maxi(FEAR_MIN, int(hero.get("fear", 0)) - relief)
        psychology["temporary_madness_resistance"] = maxi(
            int(psychology.get("temporary_madness_resistance", 0)),
            maxi(0, int(hope.get("temporary_madness_resistance", 0)))
        )
        var hope_history: Array = psychology.get("hope_history", [])
        hope_history.append({"event_id": event_id, "fear_after": int(hero.get("fear", 0))})
        _trim_history(hope_history, HOPE_HISTORY_LIMIT)
        psychology["hope_history"] = hope_history

    psychology["fear_peak"] = maxi(int(psychology.get("fear_peak", 0)), int(hero.get("fear", 0)))
    var history: Array = psychology.get("event_history", [])
    history.append({
        "event_id": event_id,
        "fear_before": before_fear,
        "fear_after": int(hero.get("fear", 0)),
        "tags": tags.duplicate(true)
    })
    _trim_history(history, HISTORY_LIMIT)
    psychology["event_history"] = history

    var trace: Dictionary = event.get("trace", {})
    if not trace.is_empty():
        _try_add_trace(hero, event_id, trace)
    if int(hero.get("fear", 0)) >= FEAR_MAX and before_fear < FEAR_MAX:
        psychology["panic_count"] = int(psychology.get("panic_count", 0)) + 1
        if trace.is_empty():
            _try_add_trace(hero, event_id + "_panic", {"threshold": 100, "chance": 0.50, "pool": ["panic_memory"]})

    hero["psychology"] = psychology

func record_external_fear(hero: Dictionary, before_fear: int, source: String, context: Dictionary = {}) -> void:
    if hero.is_empty():
        return
    var psychology := ensure_hero(hero)
    var after_fear := clampi(int(hero.get("fear", 0)), FEAR_MIN, FEAR_MAX)
    var delta := after_fear - before_fear
    if delta <= 0:
        return
    var history: Array = psychology.get("event_history", [])
    history.append({
        "event_id": "external_%s" % source,
        "fear_before": before_fear,
        "fear_after": after_fear,
        "tags": [source],
        "context": context.duplicate(true)
    })
    _trim_history(history, HISTORY_LIMIT)
    psychology["event_history"] = history
    psychology["fear_peak"] = maxi(int(psychology.get("fear_peak", 0)), after_fear)
    if after_fear >= FEAR_MAX and before_fear < FEAR_MAX:
        psychology["panic_count"] = int(psychology.get("panic_count", 0)) + 1
        _try_add_trace(hero, "external_%s_panic" % source, {"threshold": 100, "chance": 0.50, "pool": ["panic_memory"]})
    hero["psychology"] = psychology

func _adjusted_fear_delta(hero: Dictionary, raw_delta: int, tags: Array, context: Dictionary) -> int:
    if raw_delta <= 0:
        return raw_delta
    var multiplier := 1.0
    var max_hp := maxi(1, int(hero.get("max_hp", 1)))
    if float(hero.get("hp", 0)) / float(max_hp) <= 0.25:
        multiplier *= 1.10
    if tags.has("dismemberment") and str(context.get("attacker_id", "")) == str(hero.get("id", "")):
        multiplier *= 0.50
    if tags.has("dismemberment") and bool(context.get("boss", false)):
        multiplier *= 1.20

    var psychology := ensure_hero(hero)
    for trait_value in psychology.get("traits", []):
        multiplier *= _trait_fear_multiplier(str(trait_value), tags)
    for trauma_value in psychology.get("traumas", []):
        multiplier *= _trait_fear_multiplier(str(trauma_value), tags)

    var custom_value = hero.get("psychology_modifiers", {})
    var custom: Dictionary = custom_value if custom_value is Dictionary else {}
    for tag_value in tags:
        var tag := str(tag_value)
        if custom.has(tag):
            multiplier *= float(custom.get(tag, 1.0))
    return maxi(0, int(round(float(raw_delta) * multiplier)))

func _trait_fear_multiplier(trait_id: String, tags: Array) -> float:
    var definition: Dictionary = data.get("trait_definitions", {}).get(trait_id, {})
    var multipliers: Dictionary = definition.get("fear_multipliers", {})
    var result := 1.0
    for tag_value in tags:
        var tag := str(tag_value)
        if multipliers.has(tag):
            result *= float(multipliers.get(tag, 1.0))
    return result

func _try_add_trace(hero: Dictionary, event_id: String, trace: Dictionary) -> bool:
    var threshold := clampi(int(trace.get("threshold", FEAR_MAX)), FEAR_MIN, FEAR_MAX)
    if int(hero.get("fear", 0)) < threshold:
        return false
    var pool: Array = trace.get("pool", [])
    if pool.is_empty():
        return false
    var psychology := ensure_hero(hero)
    var resistance := clampi(int(psychology.get("temporary_madness_resistance", 0)), 0, 90)
    var chance := clampf(float(trace.get("chance", 1.0)) * (1.0 - float(resistance) / 100.0), 0.0, 1.0)
    psychology["temporary_madness_resistance"] = 0
    if _stable_roll("%s|%s|%d" % [str(hero.get("id", "")), event_id, int(psychology.get("event_history", []).size())]) > chance:
        hero["psychology"] = psychology
        return false

    var index := _stable_index("%s|%s" % [str(hero.get("id", "")), event_id], pool.size())
    var trait_id := str(pool[index])
    var definition: Dictionary = data.get("trait_definitions", {}).get(trait_id, {})
    var kind := str(definition.get("kind", "trait"))
    var destination_key := "traumas" if kind == "trauma" else "traits"
    var destination: Array = psychology.get(destination_key, [])
    if destination.has(trait_id):
        hero["psychology"] = psychology
        return false
    destination.append(trait_id)
    psychology[destination_key] = destination
    psychology["madness_exposure"] = mini(100, int(psychology.get("madness_exposure", 0)) + 10)
    hero["psychology"] = psychology
    GameState.add_log("TRACE PSYCHOLOGIQUE — %s : %s." % [str(hero.get("name", "Héros")), trait_label(trait_id)])
    return true

func _stable_roll(key: String) -> float:
    var checksum := 17
    for index in range(key.length()):
        checksum = (checksum * 33 + key.unicode_at(index)) % 10000
    return float(checksum) / 10000.0

func _stable_index(key: String, size: int) -> int:
    if size <= 1:
        return 0
    var checksum := 23
    for index in range(key.length()):
        checksum = (checksum * 31 + key.unicode_at(index)) % 100000
    return checksum % size

func _trim_history(history: Array, limit: int) -> void:
    while history.size() > limit:
        history.pop_front()

func _resolve_targets(event: Dictionary, explicit_targets: Array) -> Array:
    if not explicit_targets.is_empty():
        return explicit_targets
    var scope := str(event.get("scope", "party"))
    if scope in ["party", "targets"]:
        return GameState.alive_heroes()
    return GameState.alive_heroes()

func _matches_filter(event: Dictionary, context: Dictionary) -> bool:
    var filter_value = event.get("filter", {})
    var filter: Dictionary = filter_value if filter_value is Dictionary else {}
    for key_value in filter.keys():
        var key := str(key_value)
        if key == "exclude_zone_ids":
            var excluded: Array = filter.get(key, [])
            if excluded.has(str(context.get("zone_id", ""))):
                return false
            continue
        if context.get(key, null) != filter.get(key):
            return false
    return true

func _once_flag(event_id: String) -> String:
    return "psychology_event_%s" % event_id

func _apply_trigger(trigger: String, context: Dictionary) -> void:
    for event_value in events_by_trigger.get(trigger, []):
        var event: Dictionary = event_value
        apply_named_event(str(event.get("id", "")), context)

func _on_zone_discovered(zone_id: String) -> void:
    _apply_trigger("zone_discovered", {"zone_id": zone_id})

func _on_campfire_used(zone_id: String) -> void:
    _apply_trigger("campfire_used", {"zone_id": zone_id})

func _on_shortcut_unlocked(shortcut_id: String) -> void:
    _apply_trigger("shortcut_unlocked", {"shortcut_id": shortcut_id, "zone_id": AshlandsRuntime.current_zone_id})

func _on_lore_discovered(entry: Dictionary) -> void:
    _apply_trigger("lore_discovered", {
        "lore_id": str(entry.get("id", "")),
        "collection": str(entry.get("collection", "")),
        "zone_id": str(entry.get("zone_id", AshlandsRuntime.current_zone_id))
    })

func _on_combat_started(encounter_id: String, encounter_type: String) -> void:
    _apply_trigger("combat_started", {
        "encounter_id": encounter_id,
        "encounter_type": encounter_type,
        "zone_id": AshlandsRuntime.current_zone_id
    })

func _on_combat_finished(encounter_id: String, victory: bool, _loot: Dictionary) -> void:
    _apply_trigger("combat_finished", {
        "encounter_id": encounter_id,
        "encounter_type": AshlandsCombatBridge.encounter_type,
        "zone_id": AshlandsRuntime.current_zone_id,
        "victory": victory
    })
