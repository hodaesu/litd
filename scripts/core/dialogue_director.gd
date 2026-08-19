extends Node

signal line_selected(payload: Dictionary)
signal silence_selected(event_id: String)

const DIALOGUE_PATH := "res://data/reactive_dialogues.json"
const PROFILE_PATH := "res://data/voice_profiles.json"

var dialogue_data: Dictionary = {}
var profile_data: Dictionary = {}
var _profiles_by_id: Dictionary = {}
var _used_line_ids: Array[String] = []
var _event_counter: int = 0
var _fourth_wall_count: int = 0
var _last_fourth_wall_event: int = -9999

func _ready() -> void:
    _load_data()
    reset_run()
    if not GameState.new_game_reset.is_connected(_on_new_game_reset):
        GameState.new_game_reset.connect(_on_new_game_reset)
    if not ExpeditionManager.expedition_started.is_connected(_on_expedition_started):
        ExpeditionManager.expedition_started.connect(_on_expedition_started)

func _load_data() -> void:
    dialogue_data = _load_json_dictionary(DIALOGUE_PATH)
    profile_data = _load_json_dictionary(PROFILE_PATH)
    _profiles_by_id.clear()
    for value in profile_data.get("profiles", []):
        var profile: Dictionary = value if value is Dictionary else {}
        var hero_id: String = str(profile.get("hero_id", ""))
        if hero_id != "":
            _profiles_by_id[hero_id] = profile.duplicate(true)

func _load_json_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("DialogueDirector: missing data file " + path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func reset_run() -> void:
    _used_line_ids.clear()
    _event_counter = 0
    _fourth_wall_count = 0
    _last_fourth_wall_event = -9999

func _on_new_game_reset() -> void:
    reset_run()

func _on_expedition_started(_seed: int) -> void:
    reset_run()

func voice_profile(hero_id: String) -> Dictionary:
    var value: Variant = _profiles_by_id.get(hero_id, {})
    return value.duplicate(true) if value is Dictionary else {}

func request_line(event_id: String, context: Dictionary = {}) -> Dictionary:
    _event_counter += 1
    var candidates: Array[Dictionary] = []
    for value in dialogue_data.get("lines", []):
        var line: Dictionary = value if value is Dictionary else {}
        var line_event: String = str(line.get("event", ""))
        if line_event != event_id and line_event != "*":
            continue
        if not _line_allowed(line, event_id, context):
            continue
        candidates.append(line.duplicate(true))

    if candidates.is_empty():
        silence_selected.emit(event_id)
        return {"mode": "silence", "event": event_id}

    candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        var left_priority: int = int(left.get("priority", 0))
        var right_priority: int = int(right.get("priority", 0))
        if left_priority == right_priority:
            return str(left.get("id", "")) < str(right.get("id", ""))
        return left_priority > right_priority
    )

    var selected: Dictionary = _select_within_top_priority(candidates, event_id)
    var selected_id: String = str(selected.get("id", ""))
    if selected_id != "" and not _used_line_ids.has(selected_id):
        _used_line_ids.append(selected_id)

    var speaker_id: String = str(selected.get("speaker_id", "narrator"))
    selected["speaker"] = _speaker_name(speaker_id, str(selected.get("speaker", "")))
    selected["mode"] = "dialogue"
    selected["event"] = event_id

    if bool(selected.get("fourth_wall", false)):
        _fourth_wall_count += 1
        _last_fourth_wall_event = _event_counter

    line_selected.emit(selected.duplicate(true))
    return selected

func request_and_log(event_id: String, context: Dictionary = {}) -> Dictionary:
    var selected: Dictionary = request_line(event_id, context)
    if str(selected.get("mode", "")) != "dialogue":
        return selected
    var speaker: String = str(selected.get("speaker", ""))
    var text: String = str(selected.get("text", ""))
    if text != "":
        GameState.add_log("%s — %s" % [speaker, text])
    return selected

func _select_within_top_priority(candidates: Array[Dictionary], event_id: String) -> Dictionary:
    var top_priority: int = int(candidates[0].get("priority", 0))
    var top: Array[Dictionary] = []
    for candidate in candidates:
        if int(candidate.get("priority", 0)) != top_priority:
            break
        top.append(candidate)
    if top.size() == 1:
        return top[0].duplicate(true)
    var index_seed: int = absi(hash(event_id + ":" + str(_event_counter)))
    var index: int = index_seed % top.size()
    return top[index].duplicate(true)

func _line_allowed(line: Dictionary, event_id: String, context: Dictionary) -> bool:
    var line_id: String = str(line.get("id", ""))
    var is_fourth_wall: bool = bool(line.get("fourth_wall", false))
    var critical_story: bool = bool(context.get("critical_story", false)) or event_id == "critical_story"
    var speaker_id: String = str(line.get("speaker_id", "narrator"))

    if critical_story:
        if is_fourth_wall:
            return false
        if speaker_id != "narrator" and bool(dialogue_data.get("rules", {}).get("critical_story_never_depends_on_mortal_hero", true)):
            return false
        if not bool(line.get("critical_safe", speaker_id == "narrator")):
            return false

    var requested_speaker: String = str(context.get("speaker_id", ""))
    if requested_speaker != "" and speaker_id != requested_speaker:
        return false

    var hero: Dictionary = {}
    if speaker_id != "narrator":
        hero = _alive_hero(speaker_id)
        if hero.is_empty():
            return false

    if line_id != "" and _used_line_ids.has(line_id):
        return false

    var conditions_value: Variant = line.get("conditions", {})
    var conditions: Dictionary = conditions_value if conditions_value is Dictionary else {}
    if not _conditions_match(conditions, hero, context):
        return false

    if is_fourth_wall and not _fourth_wall_allowed(line, speaker_id, critical_story, context):
        return false

    return true

func _conditions_match(conditions: Dictionary, hero: Dictionary, context: Dictionary) -> bool:
    if conditions.is_empty():
        return true
    if conditions.has("fear_min") and int(hero.get("fear", 0)) < int(conditions.get("fear_min", 0)):
        return false
    if conditions.has("fear_max") and int(hero.get("fear", 0)) > int(conditions.get("fear_max", 100)):
        return false
    if conditions.has("hp_ratio_max"):
        var max_hp: int = maxi(1, int(hero.get("max_hp", 1)))
        var hp_ratio: float = float(hero.get("hp", 0)) / float(max_hp)
        if hp_ratio > float(conditions.get("hp_ratio_max", 1.0)):
            return false
    if conditions.has("hp_ratio_min"):
        var min_max_hp: int = maxi(1, int(hero.get("max_hp", 1)))
        var min_hp_ratio: float = float(hero.get("hp", 0)) / float(min_max_hp)
        if min_hp_ratio < float(conditions.get("hp_ratio_min", 0.0)):
            return false
    if conditions.has("min_alive") and GameState.alive_heroes().size() < int(conditions.get("min_alive", 0)):
        return false
    if conditions.has("max_alive") and GameState.alive_heroes().size() > int(conditions.get("max_alive", 999)):
        return false
    if conditions.has("min_party_deaths"):
        var deaths: int = int(context.get("party_deaths", _current_party_deaths()))
        if deaths < int(conditions.get("min_party_deaths", 0)):
            return false
    return true

func _fourth_wall_allowed(line: Dictionary, speaker_id: String, critical_story: bool, context: Dictionary) -> bool:
    if critical_story:
        return false
    if not bool(context.get("fourth_wall_allowed", true)):
        return false
    var policy_value: Variant = dialogue_data.get("fourth_wall", {})
    var policy: Dictionary = policy_value if policy_value is Dictionary else {}
    var max_per_expedition: int = int(policy.get("max_per_expedition", 2))
    if _fourth_wall_count >= max_per_expedition:
        return false

    var force_fourth_wall: bool = bool(context.get("force_fourth_wall", false))
    if force_fourth_wall:
        return true

    var minimum_gap: int = int(policy.get("minimum_gap_events", 8))
    if _event_counter - _last_fourth_wall_event < minimum_gap:
        return false

    var probability: float = float(policy.get("default_probability", 0.05))
    var profile: Dictionary = voice_profile(speaker_id)
    var affinity: int = clampi(int(profile.get("fourth_wall_affinity", 1)), 1, 3)
    probability *= 0.5 + float(affinity) * 0.25
    var meta_level: String = str(line.get("meta_level", "fissure"))
    if meta_level == "direct":
        probability *= 0.55
    elif meta_level == "abyssal":
        probability *= 0.25

    var roll_seed: int = absi(hash(str(line.get("id", "")) + ":" + str(_event_counter))) % 10000
    return float(roll_seed) < probability * 10000.0

func _alive_hero(hero_id: String) -> Dictionary:
    for value in GameState.party:
        var hero: Dictionary = value if value is Dictionary else {}
        if str(hero.get("id", "")) == hero_id and int(hero.get("hp", 0)) > 0:
            return hero
    return {}

func _speaker_name(speaker_id: String, fallback: String) -> String:
    if speaker_id == "narrator":
        return fallback if fallback != "" else "Narratrice"
    var hero: Dictionary = _alive_hero(speaker_id)
    return str(hero.get("name", speaker_id)) if not hero.is_empty() else fallback

func _current_party_deaths() -> int:
    var deaths: int = 0
    for value in GameState.party:
        var hero: Dictionary = value if value is Dictionary else {}
        if int(hero.get("hp", 0)) <= 0:
            deaths += 1
    return deaths

func fourth_wall_state() -> Dictionary:
    return {
        "count": _fourth_wall_count,
        "max": int(dialogue_data.get("fourth_wall", {}).get("max_per_expedition", 2)),
        "events_since_last": _event_counter - _last_fourth_wall_event
    }
