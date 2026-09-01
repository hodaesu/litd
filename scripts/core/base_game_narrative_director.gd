extends Node

signal narration_selected(payload: Dictionary)

const STORY_PATH := "res://data/narrative/base_game_story_contract.json"
const NARRATOR_PATH := "res://data/narrative/base_game_narrator.json"
const KEY_SCENES_PATH := "res://data/narrative/base_game_key_scenes.json"
const CHARACTER_ARCS_PATH := "res://data/narrative/base_game_character_arcs.json"
const REVELATION_MATRIX_PATH := "res://data/narrative/base_game_revelation_matrix.json"

var story_data: Dictionary = {}
var narrator_data: Dictionary = {}
var key_scenes_data: Dictionary = {}
var character_arcs_data: Dictionary = {}
var revelation_matrix_data: Dictionary = {}
var _used_line_keys: Dictionary = {}
var _last_chapter_id := ""

func _ready() -> void:
    story_data = _load_dictionary(STORY_PATH)
    narrator_data = _load_dictionary(NARRATOR_PATH)
    key_scenes_data = _load_dictionary(KEY_SCENES_PATH)
    character_arcs_data = _load_dictionary(CHARACTER_ARCS_PATH)
    revelation_matrix_data = _load_dictionary(REVELATION_MATRIX_PATH)
    _last_chapter_id = CampaignState.current_chapter_id
    if not CampaignState.campaign_changed.is_connected(_on_campaign_changed):
        CampaignState.campaign_changed.connect(_on_campaign_changed)
    if is_cycle_zero_contract():
        select_and_log("opening", _last_chapter_id)

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("BaseGameNarrativeDirector: missing data file " + path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func chapter_contract(chapter_id: String = "") -> Dictionary:
    var target_id := chapter_id
    if target_id == "":
        target_id = CampaignState.current_chapter_id
    for value: Variant in story_data.get("chapters", []):
        var entry: Dictionary = value if value is Dictionary else {}
        if str(entry.get("id", "")) == target_id:
            return entry.duplicate(true)
    return {}

func current_human_question() -> String:
    return str(chapter_contract().get("human_question", ""))

func current_emotional_arc() -> Dictionary:
    var value: Variant = chapter_contract().get("emotional_arc", {})
    return value.duplicate(true) if value is Dictionary else {}

func current_player_knowledge() -> Dictionary:
    var contract := chapter_contract()
    return {
        "start": contract.get("player_knowledge_start", []).duplicate(true),
        "end": contract.get("player_knowledge_end", []).duplicate(true),
        "forbidden_reveals": contract.get("forbidden_reveals", []).duplicate(true)
    }

func environmental_beats(chapter_id: String = "") -> Array:
    return chapter_contract(chapter_id).get("environmental_beats", []).duplicate(true)

func character_pressure(chapter_id: String = "") -> Array:
    return chapter_contract(chapter_id).get("character_pressure", []).duplicate(true)

func choice_echoes(chapter_id: String = "") -> Array:
    return chapter_contract(chapter_id).get("choice_echoes", []).duplicate(true)

func transition_hook(chapter_id: String = "") -> String:
    return str(chapter_contract(chapter_id).get("transition_hook", ""))

func key_scenes(chapter_id: String = "") -> Array:
    var target_id := chapter_id
    if target_id == "":
        target_id = CampaignState.current_chapter_id
    var chapters: Dictionary = key_scenes_data.get("chapters", {})
    var values: Variant = chapters.get(target_id, [])
    return values.duplicate(true) if values is Array else []

func key_scene(scene_id: String, chapter_id: String = "") -> Dictionary:
    for value: Variant in key_scenes(chapter_id):
        var scene: Dictionary = value if value is Dictionary else {}
        if str(scene.get("id", "")) == scene_id:
            return scene.duplicate(true)
    return {}

func character_arc(character_id: String) -> Dictionary:
    for value: Variant in character_arcs_data.get("characters", []):
        var character: Dictionary = value if value is Dictionary else {}
        if str(character.get("id", "")) == character_id:
            return character.duplicate(true)
    return {}

func character_knowledge(character_id: String, chapter_id: String = "") -> String:
    var target_id := chapter_id
    if target_id == "":
        target_id = CampaignState.current_chapter_id
    var character := character_arc(character_id)
    var limits: Dictionary = character.get("knowledge_limits", {})
    return str(limits.get(target_id, ""))

func revelation(truth_id: String) -> Dictionary:
    for value: Variant in revelation_matrix_data.get("truths", []):
        var truth: Dictionary = value if value is Dictionary else {}
        if str(truth.get("id", "")) == truth_id:
            return truth.duplicate(true)
    return {}

func revelation_established(truth_id: String, chapter_number: int = -1) -> bool:
    var truth := revelation(truth_id)
    if truth.is_empty():
        return false
    var current_number := chapter_number
    if current_number < 0:
        current_number = CampaignState.current_chapter_number()
    return current_number >= int(truth.get("established_chapter", 999))

func revelation_can_be_clue(truth_id: String, chapter_number: int = -1) -> bool:
    var truth := revelation(truth_id)
    if truth.is_empty():
        return false
    var current_number := chapter_number
    if current_number < 0:
        current_number = CampaignState.current_chapter_number()
    return current_number >= int(truth.get("earliest_clue_chapter", 999))

func narrator_rules() -> Dictionary:
    var value: Variant = narrator_data.get("style_contract", {})
    return value.duplicate(true) if value is Dictionary else {}

func narrator_lines(event_id: String, chapter_id: String = "") -> Array[String]:
    var result: Array[String] = []
    var target_id := chapter_id
    if target_id == "":
        target_id = CampaignState.current_chapter_id
    var chapters: Dictionary = narrator_data.get("chapters", {})
    var chapter: Dictionary = chapters.get(target_id, {})
    var values: Variant = chapter.get(event_id, [])
    if values is Array:
        for value: Variant in values:
            var text := str(value)
            if text != "":
                result.append(text)
    if result.is_empty():
        var generic: Dictionary = narrator_data.get("generic_lines", {})
        var generic_values: Variant = generic.get(event_id, [])
        if generic_values is Array:
            for value: Variant in generic_values:
                var text := str(value)
                if text != "":
                    result.append(text)
    return result

func select_narration(event_id: String, chapter_id: String = "", allow_repeat: bool = false) -> Dictionary:
    var target_id := chapter_id
    if target_id == "":
        target_id = CampaignState.current_chapter_id
    var lines := narrator_lines(event_id, target_id)
    if lines.is_empty():
        return {"mode": "silence", "event": event_id, "chapter_id": target_id}

    var available: Array[String] = []
    for text: String in lines:
        var key := "%s|%s|%s" % [target_id, event_id, text]
        if allow_repeat or not bool(_used_line_keys.get(key, false)):
            available.append(text)
    if available.is_empty():
        if not allow_repeat:
            return {"mode": "silence", "event": event_id, "chapter_id": target_id, "reason": "authored_lines_exhausted"}
        available = lines

    var index_seed := absi(hash("%s|%s|%d" % [target_id, event_id, _used_line_keys.size()]))
    var selected := available[index_seed % available.size()]
    _used_line_keys["%s|%s|%s" % [target_id, event_id, selected]] = true
    var payload := {
        "mode": "narration",
        "speaker": str(narrator_data.get("speaker_label", "Narration")),
        "text": selected,
        "event": event_id,
        "chapter_id": target_id,
        "human_question": str(chapter_contract(target_id).get("human_question", ""))
    }
    narration_selected.emit(payload.duplicate(true))
    return payload

func select_and_log(event_id: String, chapter_id: String = "", allow_repeat: bool = false) -> Dictionary:
    if not is_cycle_zero_contract():
        return {"mode": "silence", "event": event_id, "reason": "cycle_initial_only"}
    var payload := select_narration(event_id, chapter_id, allow_repeat)
    if str(payload.get("mode", "")) == "narration":
        GameState.add_log("%s — %s" % [str(payload.get("speaker", "Narration")), str(payload.get("text", ""))])
    return payload

func _on_campaign_changed() -> void:
    if not is_cycle_zero_contract():
        _last_chapter_id = CampaignState.current_chapter_id
        return
    var current_id := CampaignState.current_chapter_id
    if current_id == _last_chapter_id:
        return
    if _last_chapter_id != "":
        select_and_log("closing", _last_chapter_id)
    _last_chapter_id = current_id
    select_and_log("opening", current_id)

func reset_session_memory() -> void:
    _used_line_keys.clear()

func is_cycle_zero_contract() -> bool:
    return EndgameState.active_cycle <= 0

func narrative_expansion_allowed() -> bool:
    return is_cycle_zero_contract()
