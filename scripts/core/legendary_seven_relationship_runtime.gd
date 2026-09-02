extends Node

signal pair_scene_presented(pair_id: String, stage: String, payload: Dictionary)

const CORE_PATH := "res://universe/lore/legendary_seven_relationships.json"
const DIALOGUE_PATHS := [
    "res://data/narrative/legendary_seven_relationship_dialogues_1.json",
    "res://data/narrative/legendary_seven_relationship_dialogues_2.json",
    "res://data/narrative/legendary_seven_relationship_dialogues_3.json"
]

var core: Dictionary = {}
var profiles: Dictionary = {}
var dialogues: Dictionary = {}
var _presenting: bool = false

func _ready() -> void:
    _load_data()
    if not GameState.screen_requested.is_connected(_on_screen_requested):
        GameState.screen_requested.connect(_on_screen_requested)

func _load_data() -> void:
    core = _load_json_dictionary(CORE_PATH)
    profiles = {}
    dialogues = {}
    for value: Variant in core.get("pairs", []):
        var pair: Dictionary = value if value is Dictionary else {}
        var pair_id: String = str(pair.get("id", ""))
        if pair_id != "":
            profiles[pair_id] = pair.duplicate(true)
    for path: String in DIALOGUE_PATHS:
        var pack: Dictionary = _load_json_dictionary(path)
        for value: Variant in pack.get("pairs", []):
            var pair: Dictionary = value if value is Dictionary else {}
            var pair_id: String = str(pair.get("id", ""))
            if pair_id != "":
                dialogues[pair_id] = pair.duplicate(true)

func _load_json_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("LegendarySevenRelationshipRuntime: missing " + path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func pair_count() -> int:
    return profiles.size()

func profile_for_ids(left_id: String, right_id: String) -> Dictionary:
    var pair_id: String = pair_id_for_ids(left_id, right_id)
    var value: Variant = profiles.get(pair_id, {})
    return value.duplicate(true) if value is Dictionary else {}

func pair_id_for_ids(left_id: String, right_id: String) -> String:
    var left: String = _normalize_hero_id(left_id)
    var right: String = _normalize_hero_id(right_id)
    if left == "" or right == "" or left == right:
        return ""
    for key_value: Variant in profiles.keys():
        var pair_id: String = str(key_value)
        var profile_value: Variant = profiles.get(pair_id, {})
        var profile: Dictionary = profile_value if profile_value is Dictionary else {}
        var heroes_value: Variant = profile.get("heroes", [])
        var heroes: Array = heroes_value if heroes_value is Array else []
        if heroes.size() != 2:
            continue
        var a: String = _normalize_hero_id(str(heroes[0]))
        var b: String = _normalize_hero_id(str(heroes[1]))
        if (a == left and b == right) or (a == right and b == left):
            return pair_id
    return ""

func relationship_stage_for_ids(left_id: String, right_id: String) -> String:
    var pair_id: String = pair_id_for_ids(left_id, right_id)
    if pair_id == "":
        return "absent"
    var left: Dictionary = _party_hero(left_id)
    var right: Dictionary = _party_hero(right_id)
    if left.is_empty() or right.is_empty():
        return "absent"
    var left_alive: bool = int(left.get("hp", 0)) > 0
    var right_alive: bool = int(right.get("hp", 0)) > 0
    if left_alive != right_alive:
        return "bereavement"
    if not left_alive and not right_alive:
        return "silent"

    var state: Dictionary = RelationshipRuntime.pair_state(left, right)
    var trust: int = int(state.get("trust", 0))
    var tension: int = int(state.get("tension", 0))
    var thresholds_value: Variant = core.get("stage_derivation", {})
    var thresholds: Dictionary = thresholds_value if thresholds_value is Dictionary else {}
    var rupture_min: int = int(thresholds.get("rupture", {}).get("tension_min", 70))
    var friction_min: int = int(thresholds.get("friction", {}).get("tension_min", 45))
    if tension >= rupture_min:
        return "rupture"
    if tension >= friction_min:
        return "friction"
    if _has_repair_signal(left, right) and not _stage_seen(left, right, pair_id, "repair"):
        return "repair"
    var qualitative_count: int = _qualitative_memory_count(left, right)
    var durable_value: Variant = thresholds.get("durable", {})
    var durable: Dictionary = durable_value if durable_value is Dictionary else {}
    if trust >= int(durable.get("trust_min", 60)) and qualitative_count >= int(durable.get("qualitative_memories_min", 2)):
        return "durable"
    var opening_value: Variant = thresholds.get("opening", {})
    var opening: Dictionary = opening_value if opening_value is Dictionary else {}
    if trust >= int(opening.get("trust_min", 15)) or qualitative_count >= int(opening.get("or_qualitative_memories_min", 1)):
        return "opening"
    return "dormant"

func _has_repair_signal(left: Dictionary, right: Dictionary) -> bool:
    var state: Dictionary = RelationshipRuntime.relation(left, right)
    var history_value: Variant = state.get("history", [])
    var history: Array = history_value if history_value is Array else []
    var disagreement_seen: bool = false
    for value: Variant in history:
        var entry: Dictionary = value if value is Dictionary else {}
        var tag: String = str(entry.get("qualitative_tag", ""))
        var event_id: String = str(entry.get("event_id", ""))
        if tag == "desaccord_persistant":
            disagreement_seen = true
            continue
        if disagreement_seen and (tag == "responsabilite_partagee" or event_id == "sanctuary_reconcile"):
            return true
    return false

func _qualitative_memory_count(left: Dictionary, right: Dictionary) -> int:
    var seen: Dictionary = {}
    for source_target: Array in [[left, right], [right, left]]:
        var source: Dictionary = source_target[0]
        var target: Dictionary = source_target[1]
        var state: Dictionary = RelationshipRuntime.relation(source, target)
        var history_value: Variant = state.get("history", [])
        var history: Array = history_value if history_value is Array else []
        for value: Variant in history:
            var entry: Dictionary = value if value is Dictionary else {}
            var tag: String = str(entry.get("qualitative_tag", ""))
            if tag == "":
                continue
            var event_id: String = str(entry.get("event_id", ""))
            if event_id != "":
                seen[event_id] = true
    return seen.size()

func _on_screen_requested(screen_name: String) -> void:
    if screen_name != "sanctuary":
        return
    call_deferred("present_best_pending_scene")

func present_best_pending_scene() -> Dictionary:
    if _presenting or GameState.current_screen != "sanctuary":
        return {}
    if SystemicCrossNarrativeRuntime.has_pending_scene():
        return {}
    if SystemicCrossAfterlifeRuntime.pending_beat_count() > 0:
        return {}

    var candidates: Array[Dictionary] = []
    for pair_value: Variant in core.get("pairs", []):
        var profile: Dictionary = pair_value if pair_value is Dictionary else {}
        var pair_id: String = str(profile.get("id", ""))
        var heroes_value: Variant = profile.get("heroes", [])
        var heroes: Array = heroes_value if heroes_value is Array else []
        if pair_id == "" or heroes.size() != 2:
            continue
        var left: Dictionary = _party_hero(str(heroes[0]))
        var right: Dictionary = _party_hero(str(heroes[1]))
        if left.is_empty() or right.is_empty():
            continue
        var stage: String = relationship_stage_for_ids(str(heroes[0]), str(heroes[1]))
        if stage in ["absent", "silent", "dormant"]:
            continue
        if _stage_seen(left, right, pair_id, stage):
            continue
        var payload: Dictionary = _resolved_scene(pair_id, stage, left, right)
        if payload.is_empty():
            continue
        candidates.append({
            "pair_id": pair_id,
            "stage": stage,
            "score": _stage_priority(stage),
            "payload": payload,
            "left": left,
            "right": right
        })

    if candidates.is_empty():
        return {}
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var left_score: int = int(a.get("score", 0))
        var right_score: int = int(b.get("score", 0))
        if left_score == right_score:
            return str(a.get("pair_id", "")) < str(b.get("pair_id", ""))
        return left_score > right_score
    )
    var selected: Dictionary = candidates[0]
    var payload_value: Variant = selected.get("payload", {})
    var payload: Dictionary = payload_value if payload_value is Dictionary else {}
    _presenting = true
    _mark_stage_seen(selected.get("left", {}), selected.get("right", {}), str(selected.get("pair_id", "")), str(selected.get("stage", "")))
    _log_scene(payload)
    pair_scene_presented.emit(str(selected.get("pair_id", "")), str(selected.get("stage", "")), payload.duplicate(true))
    _presenting = false
    return payload

func _resolved_scene(pair_id: String, stage: String, left: Dictionary, right: Dictionary) -> Dictionary:
    var dialogue_value: Variant = dialogues.get(pair_id, {})
    var dialogue: Dictionary = dialogue_value if dialogue_value is Dictionary else {}
    var stages_value: Variant = dialogue.get("stages", {})
    var stages: Dictionary = stages_value if stages_value is Dictionary else {}
    var stage_value: Variant = stages.get(stage, {})
    var stage_data: Dictionary = stage_value if stage_value is Dictionary else {}
    if stage_data.is_empty():
        return {}
    var lines: Array[Dictionary] = []
    if stage == "bereavement":
        var survivor: Dictionary = left if int(left.get("hp", 0)) > 0 else right
        var survivor_key: String = "hero." + _normalize_hero_id(str(survivor.get("id", "")))
        var survivor_lines_value: Variant = stage_data.get("survivor_lines", {})
        var survivor_lines: Dictionary = survivor_lines_value if survivor_lines_value is Dictionary else {}
        var text: String = str(survivor_lines.get(survivor_key, ""))
        if text != "":
            lines.append({"speaker_id": survivor_key, "speaker": str(survivor.get("name", survivor_key)), "text": text})
    else:
        var line_value: Variant = stage_data.get("line", {})
        var line: Dictionary = line_value if line_value is Dictionary else {}
        var speaker_id: String = str(line.get("speaker_id", ""))
        var speaker: Dictionary = _party_hero(speaker_id)
        if speaker_id != "" and not speaker.is_empty() and int(speaker.get("hp", 0)) > 0:
            lines.append({"speaker_id": speaker_id, "speaker": str(speaker.get("name", speaker_id)), "text": str(line.get("text", ""))})
    if lines.is_empty():
        return {}
    return {
        "pair_id": pair_id,
        "stage": stage,
        "direction": str(stage_data.get("stage_direction", "")),
        "lines": lines,
        "memory_topic": _latest_qualitative_topic(left, right),
        "profile": profiles.get(pair_id, {}).duplicate(true)
    }

func _stage_priority(stage: String) -> int:
    match stage:
        "bereavement": return 100
        "rupture": return 90
        "friction": return 80
        "repair": return 70
        "durable": return 60
        "opening": return 40
    return 0

func _stage_seen(left: Dictionary, right: Dictionary, pair_id: String, stage: String) -> bool:
    var marker: String = pair_id + ":" + stage
    for source_target: Array in [[left, right], [right, left]]:
        var source: Dictionary = source_target[0]
        var target: Dictionary = source_target[1]
        if source.is_empty() or target.is_empty():
            continue
        var state: Dictionary = RelationshipRuntime.relation(source, target)
        var seen_value: Variant = state.get("narrative_seen", [])
        var seen: Array = seen_value if seen_value is Array else []
        if seen.has(marker):
            return true
    return false

func _mark_stage_seen(left: Dictionary, right: Dictionary, pair_id: String, stage: String) -> void:
    var marker: String = pair_id + ":" + stage
    for source_target: Array in [[left, right], [right, left]]:
        var source: Dictionary = source_target[0]
        var target: Dictionary = source_target[1]
        if source.is_empty() or target.is_empty() or int(source.get("hp", 0)) <= 0:
            continue
        var state: Dictionary = RelationshipRuntime.relation(source, target)
        var seen_value: Variant = state.get("narrative_seen", [])
        var seen: Array = seen_value if seen_value is Array else []
        if not seen.has(marker):
            seen.append(marker)
        state["narrative_seen"] = seen
        var relationships_value: Variant = source.get("relationships", {})
        var relationships: Dictionary = relationships_value if relationships_value is Dictionary else {}
        relationships[str(target.get("id", ""))] = state
        source["relationships"] = relationships

func _latest_qualitative_topic(left: Dictionary, right: Dictionary) -> String:
    var state: Dictionary = RelationshipRuntime.relation(left, right)
    var history_value: Variant = state.get("history", [])
    var history: Array = history_value if history_value is Array else []
    for index: int in range(history.size() - 1, -1, -1):
        var entry: Dictionary = history[index] if history[index] is Dictionary else {}
        var topic: String = str(entry.get("topic", ""))
        if topic != "":
            return topic
    return ""

func _log_scene(payload: Dictionary) -> void:
    var pair_id: String = str(payload.get("pair_id", ""))
    var stage: String = str(payload.get("stage", ""))
    GameState.add_log("LIEN DES SEPT — %s · %s" % [pair_id.replace("_", " ↔ "), stage])
    var direction: String = str(payload.get("direction", ""))
    if direction != "":
        GameState.add_log(direction)
    for value: Variant in payload.get("lines", []):
        var line: Dictionary = value if value is Dictionary else {}
        if str(line.get("text", "")) != "":
            GameState.add_log("%s — %s" % [str(line.get("speaker", "Héros")), str(line.get("text", ""))])

func _party_hero(registry_id: String) -> Dictionary:
    var normalized: String = _normalize_hero_id(registry_id)
    for value: Variant in GameState.party:
        var hero: Dictionary = value if value is Dictionary else {}
        if _normalize_hero_id(str(hero.get("id", ""))) == normalized:
            return hero
    return {}

func _normalize_hero_id(value: String) -> String:
    var normalized: String = value.strip_edges().to_lower()
    if normalized.begins_with("hero."):
        normalized = normalized.trim_prefix("hero.")
    return normalized
