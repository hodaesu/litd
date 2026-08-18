extends Node

var data: Dictionary = {}

func _ready() -> void:
    _load_data()

func _load_data() -> void:
    if not data.is_empty():
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_injuries.json"))
    data = parsed if parsed is Dictionary else {}

func apply_if_needed(enemy: Dictionary, part_id: String, state: String) -> Dictionary:
    _load_data()
    if state not in ["injured", "critical"]:
        return {}
    var part := AnatomyRuntime.part_definition(enemy, part_id)
    if part.is_empty():
        return {}
    var applied: Dictionary = enemy.get("applied_injury_states", {})
    var previous := str(applied.get(part_id, ""))
    if _severity_rank(previous) >= _severity_rank(state):
        return {}
    applied[part_id] = state
    enemy["applied_injury_states"] = applied

    var rule := _rule_for_part(part)
    if rule.is_empty():
        return {}
    var effect := str(rule.get("effect", ""))
    _apply_effect(enemy, effect, state)
    if state == "critical" and bool(rule.get("critical_disables_part", false)):
        var disabled: Array = enemy.get("critically_disabled_parts", [])
        if not disabled.has(part_id):
            disabled.append(part_id)
        enemy["critically_disabled_parts"] = disabled
    return {
        "part_id": part_id,
        "part_name": str(part.get("name", part_id)),
        "state": state,
        "injury_name": str(rule.get("name", "Blessure fonctionnelle")),
        "effect": effect,
        "critical_disables_part": state == "critical" and bool(rule.get("critical_disables_part", false))
    }

func part_functional(enemy: Dictionary, part_id: String) -> bool:
    if enemy.get("dismembered_parts", []).has(part_id):
        return false
    if enemy.get("critically_disabled_parts", []).has(part_id):
        return false
    return true

func _rule_for_part(part: Dictionary) -> Dictionary:
    var rules: Dictionary = data.get("by_tag", {})
    for tag_value in part.get("tags", []):
        var tag := str(tag_value)
        if rules.has(tag):
            return rules[tag]
    return {}

func _severity_rank(state: String) -> int:
    return int(data.get("severity", {}).get(state, {}).get("rank", 0))

func _apply_effect(enemy: Dictionary, effect: String, state: String) -> void:
    var multiplier := float(data.get("severity", {}).get(state, {}).get("multiplier", 1.0))
    match effect:
        "break_guard":
            enemy["guarding"] = false
            enemy["broken"] = maxi(2, int(enemy.get("broken", 0)))
        "mobility_loss":
            enemy["mobility_injury"] = state
            if state == "critical" and int(enemy.get("hp", 0)) > 0:
                enemy["stunned"] = true
        "sensor_loss":
            enemy["fear"] = maxi(0, int(round(float(enemy.get("fear", 0)) * multiplier)))
            _scale_damage(enemy, 0.95 if state == "injured" else 0.85)
        "venom_loss":
            enemy["fear"] = maxi(0, int(round(float(enemy.get("fear", 0)) * multiplier)))
        "attack_loss":
            _scale_damage(enemy, multiplier)
        "anchor_loss":
            enemy["anatomy_anchor_injury"] = state
            enemy["fear"] = maxi(0, int(round(float(enemy.get("fear", 0)) * multiplier)))
        "veil_loss":
            enemy["veil_coherence_injury"] = state
            enemy["fear"] = maxi(0, int(round(float(enemy.get("fear", 0)) * multiplier)))
        "core_crack":
            enemy["broken"] = maxi(2, int(enemy.get("broken", 0)))
            enemy["core_vulnerability"] = 10 if state == "injured" else 20
        "support_loss":
            enemy["guarding"] = false
            if state == "critical" and int(enemy.get("hp", 0)) > 0:
                enemy["stunned"] = true

func _scale_damage(enemy: Dictionary, multiplier: float) -> void:
    var damage: Array = enemy.get("damage", [1, 1])
    if damage.size() < 2:
        return
    enemy["damage"] = [
        maxi(1, int(round(float(damage[0]) * multiplier))),
        maxi(1, int(round(float(damage[1]) * multiplier)))
    ]
