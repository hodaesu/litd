extends Node

signal presentation_changed(items: Array)
signal event_presented(item: Dictionary)
signal event_deferred_to_journal(item: Dictionary)
signal event_dropped(item: Dictionary)
signal disclosure_level_changed(level: int)
signal confirmation_required(action_id: String)

const LEVEL_WORLD_ONLY := 0
const LEVEL_DANGER := 1
const LEVEL_CONTEXT := 2
const LEVEL_DECISION := 3
const LEVEL_INSPECTION := 4

const PRIORITY_WEIGHTS := {
    "CRITICAL": 400,
    "ACTIONABLE": 300,
    "CONTEXT": 200,
    "INFORMATION": 100,
    "DECORATIVE": 0,
}

const MAX_PRESENTED := 3
const MAX_STATUS_ICONS := 2
const DUPLICATE_WINDOW_SECONDS := 2.0

var disclosure_level: int = LEVEL_WORLD_ONLY
var current_screen: String = "exploration"
var reduced_motion: bool = false
var _presented: Array[Dictionary] = []
var _journal_backlog: Array[Dictionary] = []
var _last_seen_ms: Dictionary = {}
var _pending_confirmations: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func set_screen_context(screen_name: String) -> void:
    current_screen = screen_name
    match screen_name:
        "combat":
            set_disclosure_level(LEVEL_DECISION)
        "inventory", "equipment", "skill_trees", "journal", "settings", "inspection":
            set_disclosure_level(LEVEL_INSPECTION)
        _:
            set_disclosure_level(LEVEL_WORLD_ONLY)

func set_disclosure_level(level: int) -> void:
    var next_level := clampi(level, LEVEL_WORLD_ONLY, LEVEL_INSPECTION)
    if next_level == disclosure_level:
        return
    disclosure_level = next_level
    disclosure_level_changed.emit(disclosure_level)
    _refresh_presentation()

func set_reduced_motion(enabled: bool) -> void:
    reduced_motion = enabled

func priority_weight(priority: String) -> int:
    return int(PRIORITY_WEIGHTS.get(priority, 0))

func has_critical_event() -> bool:
    for item in _presented:
        if str(item.get("priority", "")) == "CRITICAL":
            return true
    return false

func route_event(
    event_id: String,
    priority: String,
    required_level: int,
    payload: Dictionary = {},
    ttl_seconds: float = -1.0
) -> Dictionary:
    var normalized_priority := priority.to_upper()
    if not PRIORITY_WEIGHTS.has(normalized_priority):
        normalized_priority = "INFORMATION"

    var now_ms := Time.get_ticks_msec()
    var previous_ms := int(_last_seen_ms.get(event_id, -1000000))
    if float(now_ms - previous_ms) / 1000.0 < DUPLICATE_WINDOW_SECONDS:
        var duplicate := _make_item(event_id, normalized_priority, required_level, payload, ttl_seconds)
        duplicate["decision"] = "drop_duplicate"
        event_dropped.emit(duplicate)
        return duplicate
    _last_seen_ms[event_id] = now_ms

    var item := _make_item(event_id, normalized_priority, required_level, payload, ttl_seconds)

    if normalized_priority == "DECORATIVE" and (has_critical_event() or disclosure_level >= LEVEL_DECISION):
        item["decision"] = "drop_decorative"
        event_dropped.emit(item)
        return item

    if has_critical_event() and normalized_priority == "INFORMATION":
        return _defer_to_journal(item, "critical_active")

    if required_level >= LEVEL_INSPECTION and disclosure_level < LEVEL_INSPECTION:
        return _defer_to_journal(item, "inspection_not_requested")

    var can_escalate_danger := normalized_priority == "CRITICAL" and required_level <= LEVEL_DANGER
    var can_escalate_context := normalized_priority in ["ACTIONABLE", "CONTEXT"] and required_level == LEVEL_CONTEXT and bool(payload.get("context_active", false))
    if required_level > disclosure_level and not can_escalate_danger and not can_escalate_context:
        if normalized_priority in ["INFORMATION", "DECORATIVE"]:
            return _defer_to_journal(item, "not_decision_relevant_now")
        item["decision"] = "suppress_until_relevant"
        event_dropped.emit(item)
        return item

    item["decision"] = "present"
    _presented.append(item)
    _sort_and_trim()
    event_presented.emit(item)
    presentation_changed.emit(_presented.duplicate(true))
    return item

func dismiss_event(event_id: String) -> void:
    for index in range(_presented.size() - 1, -1, -1):
        if str(_presented[index].get("id", "")) == event_id:
            _presented.remove_at(index)
    presentation_changed.emit(_presented.duplicate(true))

func clear_transient() -> void:
    _presented.clear()
    presentation_changed.emit([])

func get_presented() -> Array[Dictionary]:
    return _presented.duplicate(true)

func consume_journal_backlog() -> Array[Dictionary]:
    var result := _journal_backlog.duplicate(true)
    _journal_backlog.clear()
    return result

func journal_backlog_count() -> int:
    return _journal_backlog.size()

func summarize_statuses(statuses: Array) -> Dictionary:
    var visible: Array = []
    var count := mini(statuses.size(), MAX_STATUS_ICONS)
    for index in range(count):
        visible.append(statuses[index])
    return {
        "visible": visible,
        "overflow": maxi(statuses.size() - MAX_STATUS_ICONS, 0),
        "overflow_label": "+%d" % maxi(statuses.size() - MAX_STATUS_ICONS, 0) if statuses.size() > MAX_STATUS_ICONS else "",
    }

func request_action(action_id: String, requires_confirmation: bool) -> String:
    if not requires_confirmation:
        return "execute"
    if bool(_pending_confirmations.get(action_id, false)):
        _pending_confirmations.erase(action_id)
        return "execute"
    _pending_confirmations[action_id] = true
    confirmation_required.emit(action_id)
    return "confirm_required"

func cancel_action_confirmation(action_id: String) -> void:
    _pending_confirmations.erase(action_id)

func motion_profile() -> Dictionary:
    if reduced_motion:
        return {"appearance_seconds": 0.0, "impulse_once": false, "loop": false}
    return {"appearance_seconds": 0.15, "impulse_once": true, "loop": false}

func _make_item(event_id: String, priority: String, required_level: int, payload: Dictionary, ttl_seconds: float) -> Dictionary:
    var ttl := ttl_seconds
    if ttl < 0.0:
        if priority == "CRITICAL":
            ttl = 3.2
        elif priority == "CONTEXT":
            ttl = 1.4
        else:
            ttl = 2.2
    return {
        "id": event_id,
        "priority": priority,
        "weight": priority_weight(priority),
        "required_level": clampi(required_level, LEVEL_WORLD_ONLY, LEVEL_INSPECTION),
        "payload": payload.duplicate(true),
        "ttl_seconds": ttl,
        "created_ms": Time.get_ticks_msec(),
    }

func _defer_to_journal(item: Dictionary, reason: String) -> Dictionary:
    item["decision"] = "journal_silent"
    item["reason"] = reason
    _journal_backlog.append(item.duplicate(true))
    event_deferred_to_journal.emit(item)
    return item

func _sort_and_trim() -> void:
    _presented.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var weight_a := int(a.get("weight", 0))
        var weight_b := int(b.get("weight", 0))
        if weight_a == weight_b:
            return int(a.get("created_ms", 0)) < int(b.get("created_ms", 0))
        return weight_a > weight_b
    )
    while _presented.size() > MAX_PRESENTED:
        var removed: Dictionary = _presented.pop_back()
        if str(removed.get("priority", "")) == "INFORMATION":
            _defer_to_journal(removed, "presentation_capacity")
        else:
            removed["decision"] = "drop_capacity"
            event_dropped.emit(removed)

func _refresh_presentation() -> void:
    if disclosure_level >= LEVEL_INSPECTION:
        presentation_changed.emit(_presented.duplicate(true))
        return
    for index in range(_presented.size() - 1, -1, -1):
        var item: Dictionary = _presented[index]
        if int(item.get("required_level", LEVEL_WORLD_ONLY)) > disclosure_level and str(item.get("priority", "")) != "CRITICAL":
            _presented.remove_at(index)
    presentation_changed.emit(_presented.duplicate(true))
