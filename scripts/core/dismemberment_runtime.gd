extends Node

var data: Dictionary = {}

func _ready() -> void:
    _load_data()

func _load_data() -> void:
    if not data.is_empty():
        return
    var text := FileAccess.get_file_as_string("res://data/combat_dismemberment.json")
    var parsed = JSON.parse_string(text)
    data = parsed if parsed is Dictionary else {}

func eligible(enemy: Dictionary) -> bool:
    _load_data()
    var name := str(enemy.get("name", ""))
    for keyword_value in data.get("immune_name_keywords", []):
        if name.contains(str(keyword_value)):
            return false
    return int(enemy.get("max_hp", enemy.get("hp", 0))) > 0

func ensure_state(enemy: Dictionary) -> void:
    if not eligible(enemy):
        return
    if str(enemy.get("dismemberment_profile", "")) == "":
        enemy["dismemberment_profile"] = _profile_id(enemy)
    enemy["dismemberment_trauma"] = maxi(0, int(enemy.get("dismemberment_trauma", 0)))
    enemy["dismembered_parts"] = enemy.get("dismembered_parts", [])

func register_hit(enemy: Dictionary, action: String, damage: int, technique_id: String = "") -> Dictionary:
    ensure_state(enemy)
    if bool(enemy.get("anatomy_v2_enabled", false)):
        return {"severed": false, "trauma_added": 0, "legacy_skipped": true}
    if not eligible(enemy):
        return {"severed": false, "trauma_added": 0}
    var mechanics: Dictionary = data.get("mechanics", {})
    var added := int(mechanics.get("strike_trauma", 8))
    if action == "heavy":
        added = int(mechanics.get("heavy_trauma", 35))
    elif action == "technique":
        added = 18
    if technique_id == "malvor_guard_break":
        added += int(mechanics.get("malvor_guard_break_bonus", 35))
    if int(enemy.get("broken", 0)) > 0:
        added += int(mechanics.get("broken_bonus", 25))
    if bool(enemy.get("stunned", false)):
        added += int(mechanics.get("stunned_bonus", 15))
    var hp_ratio := float(enemy.get("hp", 0)) / float(maxi(1, int(enemy.get("max_hp", 1))))
    if hp_ratio <= 0.25:
        added += int(mechanics.get("low_hp_bonus", 15))
    added += clampi(int(round(float(damage) * 0.35)), 0, 20)
    enemy["dismemberment_trauma"] = int(enemy.get("dismemberment_trauma", 0)) + added

    var threshold := int(mechanics.get("normal_threshold", 100))
    if _is_boss(enemy):
        threshold = int(mechanics.get("boss_threshold", 135))
    if int(enemy["dismemberment_trauma"]) < threshold:
        return {"severed": false, "trauma_added": added, "trauma": int(enemy["dismemberment_trauma"]), "threshold": threshold}

    var part := _next_part(enemy)
    if part.is_empty():
        enemy["dismemberment_trauma"] = mini(int(enemy["dismemberment_trauma"]), threshold)
        return {"severed": false, "trauma_added": added, "trauma": int(enemy["dismemberment_trauma"]), "threshold": threshold}
    _apply_part_loss(enemy, part)
    enemy["dismemberment_trauma"] = maxi(0, int(enemy["dismemberment_trauma"]) - threshold)
    return {
        "severed": true,
        "trauma_added": added,
        "part_id": str(part.get("id", "")),
        "part_name": str(part.get("name", "membre")),
        "boss": _is_boss(enemy),
        "message": "%s perd %s." % [str(enemy.get("name", "L'ennemi")), str(part.get("name", "un membre"))]
    }

func status_text(enemy: Dictionary) -> String:
    ensure_state(enemy)
    if not eligible(enemy):
        return "Démembrement : impossible"
    var lost: Array = enemy.get("dismembered_parts", [])
    var threshold := int(data.get("mechanics", {}).get("boss_threshold" if _is_boss(enemy) else "normal_threshold", 100))
    var trauma := int(enemy.get("dismemberment_trauma", 0))
    if lost.is_empty():
        return "Trauma %d/%d" % [trauma, threshold]
    return "Trauma %d/%d · pertes : %s" % [trauma, threshold, ", ".join(lost)]

func _profile_id(enemy: Dictionary) -> String:
    if _is_boss(enemy):
        return "boss"
    var name := str(enemy.get("name", ""))
    var keywords: Dictionary = data.get("profile_keywords", {})
    for profile_id in ["arachnid", "beast", "aberration", "humanoid"]:
        for keyword_value in keywords.get(profile_id, []):
            if name.contains(str(keyword_value)):
                return profile_id
    return "humanoid"

func _profile(enemy: Dictionary) -> Dictionary:
    var profiles: Dictionary = data.get("profiles", {})
    return profiles.get(str(enemy.get("dismemberment_profile", "humanoid")), profiles.get("humanoid", {}))

func _next_part(enemy: Dictionary) -> Dictionary:
    var lost: Array = enemy.get("dismembered_parts", [])
    var alive := int(enemy.get("hp", 0)) > 0
    for part_value in _profile(enemy).get("parts", []):
        var part: Dictionary = part_value
        var part_id := str(part.get("id", ""))
        if lost.has(part_id):
            continue
        if bool(part.get("finisher_only", false)) and alive:
            continue
        return part
    return {}

func _apply_part_loss(enemy: Dictionary, part: Dictionary) -> void:
    var lost: Array = enemy.get("dismembered_parts", [])
    var part_id := str(part.get("id", ""))
    if not lost.has(part_id):
        lost.append(part_id)
    enemy["dismembered_parts"] = lost
    enemy["dismemberment_%s" % part_id] = true

    var multiplier := clampf(float(part.get("damage_multiplier", 1.0)), 0.25, 1.0)
    var damage_range: Array = enemy.get("damage", [1, 1])
    if damage_range.size() >= 2 and multiplier < 1.0:
        enemy["damage"] = [
            maxi(1, int(round(float(damage_range[0]) * multiplier))),
            maxi(1, int(round(float(damage_range[1]) * multiplier)))
        ]
    var fear_multiplier := clampf(float(part.get("fear_multiplier", 1.0)), 0.0, 1.0)
    enemy["fear"] = maxi(0, int(round(float(enemy.get("fear", 0)) * fear_multiplier)))
    if bool(part.get("stun", false)) and int(enemy.get("hp", 0)) > 0:
        enemy["stunned"] = true
    if _is_boss(enemy):
        enemy["boss_dismemberment_changed"] = true

func _is_boss(enemy: Dictionary) -> bool:
    return bool(enemy.get("boss", false)) or bool(enemy.get("is_boss", false)) or bool(enemy.get("deep_vestige_boss", false)) or str(enemy.get("chapter_boss_id", "")) != ""