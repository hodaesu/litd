extends Node

const DATA_PATH := "res://data/narrative_library.json"

var data: Dictionary = {}

func _ready() -> void:
    _load_data()

func _load_data() -> void:
    if not FileAccess.file_exists(DATA_PATH):
        data = {}
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    data = parsed if parsed is Dictionary else {}

func quality_axes() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value in data.get("quality_axes", []):
        var item: Dictionary = value if value is Dictionary else {}
        result.append(item.duplicate(true))
    return result

func device(device_id: String) -> Dictionary:
    for value in data.get("narrative_devices", []):
        var item: Dictionary = value if value is Dictionary else {}
        if str(item.get("id", "")) == device_id:
            return item.duplicate(true)
    return {}

func quest_narrative(quest: Dictionary) -> Dictionary:
    var value: Variant = quest.get("narrative", {})
    return value.duplicate(true) if value is Dictionary else {}

func quest_state_text(quest: Dictionary, state: String) -> String:
    var narrative: Dictionary = quest_narrative(quest)
    if narrative.is_empty():
        return str(quest.get("summary", ""))
    match state:
        "offered":
            return str(narrative.get("hook", quest.get("summary", "")))
        "active":
            return str(narrative.get("active", narrative.get("dramatic_question", quest.get("summary", ""))))
        "completed":
            return str(narrative.get("resolution", narrative.get("reframe", quest.get("summary", ""))))
        _:
            return str(quest.get("summary", ""))

func quest_reframe(quest: Dictionary) -> String:
    return str(quest_narrative(quest).get("reframe", ""))

func quest_theme(quest: Dictionary) -> String:
    return str(quest_narrative(quest).get("theme", ""))

func quest_dramatic_question(quest: Dictionary) -> String:
    return str(quest_narrative(quest).get("dramatic_question", ""))

func quest_devices(quest: Dictionary) -> Array[String]:
    var result: Array[String] = []
    var narrative: Dictionary = quest_narrative(quest)
    var values: Variant = narrative.get("devices", [])
    var devices: Array = values if values is Array else []
    for value in devices:
        var device_id := str(value)
        if device_id != "" and not result.has(device_id):
            result.append(device_id)
    return result

func originality_rules() -> Dictionary:
    var value: Variant = data.get("originality_protocol", {})
    return value.duplicate(true) if value is Dictionary else {}
