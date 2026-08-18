extends Node

var data: Dictionary = {}
var family_data: Dictionary = {}

func _ready() -> void:
    _load_data()

func _load_data() -> void:
    if data.is_empty():
        var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_anatomy_v2.json"))
        data = parsed if parsed is Dictionary else {}
    if family_data.is_empty():
        var parsed_family = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_family_tactics.json"))
        family_data = parsed_family if parsed_family is Dictionary else {}

func ensure_state(enemy: Dictionary) -> void:
    _load_data()
    enemy["anatomy_v2_enabled"] = true
    enemy["anatomy_part_trauma"] = enemy.get("anatomy_part_trauma", {})
    enemy["anatomy_part_states"] = enemy.get("anatomy_part_states", {})
    enemy["anatomy_injuries"] = enemy.get("anatomy_injuries", {})
    enemy["dismembered_parts"] = enemy.get("dismembered_parts", [])
    var available := targetable_parts(enemy)
    var selected := str(enemy.get("selected_anatomy_part", ""))
    if selected == "" or not _has_part(available, selected):
        enemy["selected_anatomy_part"] = str(available[0].get("id", "")) if not available.is_empty() else ""

func targetable_parts(enemy: Dictionary) -> Array:
    _load_data()
    var anatomy := _anatomy(enemy)
    var result: Array = []
    var lost: Array = enemy.get("dismembered_parts", [])
    for value in anatomy.get("parts", []):
        var part: Dictionary = value
        var part_id := str(part.get("id", ""))
        if part_id == "" or lost.has(part_id):
            continue
        if bool(part.get("finisher_only", false)) and int(enemy.get("hp", 0)) > 0:
            continue
        result.append(part.duplicate(true))
    return result

func select_part(enemy: Dictionary, part_id: String) -> bool:
    ensure_state(enemy)
    if not _has_part(targetable_parts(enemy), part_id):
        return false
    enemy["selected_anatomy_part"] = part_id
    return true

func cycle_part(enemy: Dictionary, direction: int) -> String:
    ensure_state(enemy)
    var parts := targetable_parts(enemy)
    if parts.is_empty():
        enemy["selected_anatomy_part"] = ""
        return ""
    var selected := str(enemy.get("selected_anatomy_part", ""))
    var index := 0
    for i in range(parts.size()):
        if str(parts[i].get("id", "")) == selected:
            index = i
            break
    index = posmod(index + direction, parts.size())
    selected = str(parts[index].get("id", ""))
    enemy["selected_anatomy_part"] = selected
    return selected

func selected_part(enemy: Dictionary) -> Dictionary:
    ensure_state(enemy)
    return part_definition(enemy, str(enemy.get("selected_anatomy_part", "")))

func part_definition(enemy: Dictionary, part_id: String) -> Dictionary:
    for value in _anatomy(enemy).get("parts", []):
        var part: Dictionary = value
        if str(part.get("id", "")) == part_id:
            return part.duplicate(true)
    return {}

func part_threshold(enemy: Dictionary, part: Dictionary) -> int:
    var base := 135 if _is_boss(enemy) else 100
    return maxi(25, int(round(float(base) * float(part.get("trauma_resistance", 1.0)))))

func part_hit_chance(hero: Dictionary, part: Dictionary, enemy: Dictionary = {}) -> int:
    _load_data()
    var chance := 75 + int(part.get("hit_modifier", 0))
    var specialization: Dictionary = data.get("hero_specializations", {}).get(str(hero.get("id", "")), {})
    var tags: Array = part.get("tags", [])
    if _tags_overlap(tags, specialization.get("tags", [])):
        chance += int(specialization.get("part_hit_bonus", 0))
    var precision := int(hero.get("precision", 0))
    chance += int(round(float(precision) * 0.25))
    if not enemy.is_empty() and str(enemy.get("protected_anatomy_part", "")) == str(part.get("id", "")):
        chance -= 15
    var targeting: Dictionary = data.get("targeting", {})
    return clampi(chance, int(targeting.get("part_hit_min", 35)), int(targeting.get("part_hit_max", 95)))

func register_targeted_hit(hero: Dictionary, enemy: Dictionary, action: String, damage: int, part_id: String = "", technique_id: String = "") -> Dictionary:
    ensure_state(enemy)
    var part := part_definition(enemy, part_id)
    if part.is_empty():
        part = selected_part(enemy)
    if part.is_empty():
        return {"severed": false, "trauma_added": 0, "message": "Aucune partie anatomique accessible."}

    var threshold := part_threshold(enemy, part)
    var chance := part_hit_chance(hero, part, enemy)
    var precision_success := randi_range(1, 100) <= chance
    var base_trauma := 8
    if action == "heavy":
        base_trauma = 35
    elif action == "technique":
        base_trauma = 18
    if technique_id == "malvor_guard_break":
        base_trauma += 35
    if int(enemy.get("broken", 0)) > 0:
        base_trauma += 25
    if bool(enemy.get("stunned", false)):
        base_trauma += 15
    if float(enemy.get("hp", 0)) / float(maxi(1, int(enemy.get("max_hp", 1)))) <= 0.25:
        base_trauma += 15
    base_trauma += clampi(int(round(float(damage) * 0.35)), 0, 20)

    var specialization: Dictionary = data.get("hero_specializations", {}).get(str(hero.get("id", "")), {})
    if _tags_overlap(part.get("tags", []), specialization.get("tags", [])):
        base_trauma = int(round(float(base_trauma) * float(specialization.get("trauma_multiplier", 1.0))))
    if not precision_success:
        base_trauma = maxi(1, int(round(float(base_trauma) * 0.35)))

    var trauma_map: Dictionary = enemy.get("anatomy_part_trauma", {})
    var current := int(trauma_map.get(str(part.get("id", "")), 0)) + base_trauma
    trauma_map[str(part.get("id", ""))] = current
    enemy["anatomy_part_trauma"] = trauma_map
    _update_injury_state(enemy, part, current, threshold)

    var can_sever := bool(part.get("severable", true)) and not bool(part.get("finisher_only", false))
    if current >= threshold and can_sever:
        _apply_part_loss(enemy, part)
        trauma_map[str(part.get("id", ""))] = threshold
        enemy["anatomy_part_trauma"] = trauma_map
        return {
            "severed": true,
            "precision_success": precision_success,
            "hit_chance": chance,
            "trauma_added": base_trauma,
            "trauma": threshold,
            "threshold": threshold,
            "part_id": str(part.get("id", "")),
            "part_name": str(part.get("name", "partie")),
            "boss": _is_boss(enemy),
            "message": "%s perd %s." % [str(enemy.get("name", "L'ennemi")), str(part.get("name", "une partie"))]
        }
    return {
        "severed": false,
        "precision_success": precision_success,
        "hit_chance": chance,
        "trauma_added": base_trauma,
        "trauma": current,
        "threshold": threshold,
        "part_id": str(part.get("id", "")),
        "part_name": str(part.get("name", "partie")),
        "state": str(enemy.get("anatomy_part_states", {}).get(str(part.get("id", "")), "intact"))
    }

func anatomy_status(enemy: Dictionary) -> Array:
    ensure_state(enemy)
    var rows: Array = []
    var trauma_map: Dictionary = enemy.get("anatomy_part_trauma", {})
    var states: Dictionary = enemy.get("anatomy_part_states", {})
    var lost: Array = enemy.get("dismembered_parts", [])
    for value in _anatomy(enemy).get("parts", []):
        var part: Dictionary = value
        var part_id := str(part.get("id", ""))
        rows.append({
            "id": part_id,
            "name": str(part.get("name", part_id)),
            "trauma": int(trauma_map.get(part_id, 0)),
            "threshold": part_threshold(enemy, part),
            "state": "lost" if lost.has(part_id) else str(states.get(part_id, "intact")),
            "consequence": str(part.get("consequence", "")),
            "selected": str(enemy.get("selected_anatomy_part", "")) == part_id,
            "hit_modifier": int(part.get("hit_modifier", 0)),
            "tags": part.get("tags", []),
            "protected": str(enemy.get("protected_anatomy_part", "")) == part_id
        })
    return rows

func _update_injury_state(enemy: Dictionary, part: Dictionary, trauma: int, threshold: int) -> void:
    var ratio := float(trauma) / float(maxi(1, threshold))
    var state := "intact"
    for entry_value in data.get("injury_thresholds", []):
        var entry: Dictionary = entry_value
        if ratio >= float(entry.get("ratio", 2.0)):
            state = str(entry.get("state", state))
    var states: Dictionary = enemy.get("anatomy_part_states", {})
    var old_state := str(states.get(str(part.get("id", "")), "intact"))
    states[str(part.get("id", ""))] = state
    enemy["anatomy_part_states"] = states
    if state != old_state and state != "intact":
        var injuries: Dictionary = enemy.get("anatomy_injuries", {})
        injuries[str(part.get("id", ""))] = state
        enemy["anatomy_injuries"] = injuries

func _apply_part_loss(enemy: Dictionary, part: Dictionary) -> void:
    var part_id := str(part.get("id", ""))
    var lost: Array = enemy.get("dismembered_parts", [])
    if not lost.has(part_id):
        lost.append(part_id)
    enemy["dismembered_parts"] = lost
    enemy["dismemberment_%s" % part_id] = true
    var tags: Array = part.get("tags", [])
    if tags.has("attack") or tags.has("weapon"):
        var damage: Array = enemy.get("damage", [1, 1])
        if damage.size() >= 2:
            enemy["damage"] = [maxi(1, int(round(float(damage[0]) * 0.78))), maxi(1, int(round(float(damage[1]) * 0.78)))]
    if tags.has("fear") or tags.has("sensor"):
        enemy["fear"] = maxi(0, int(round(float(enemy.get("fear", 0)) * 0.8)))
    if tags.has("mobility") and int(enemy.get("hp", 0)) > 0:
        enemy["stunned"] = true
    if tags.has("anchor"):
        enemy["anatomy_anchor_lost"] = true
    if _is_boss(enemy):
        enemy["boss_dismemberment_changed"] = true

func _anatomy(enemy: Dictionary) -> Dictionary:
    _load_data()
    var encounter_id := _encounter_id(enemy)
    var boss_anatomies: Dictionary = data.get("boss_anatomies", {})
    if encounter_id != "" and boss_anatomies.has(encounter_id):
        return boss_anatomies.get(encounter_id, {})
    var profile_id := _profile_id(enemy)
    return data.get("generic_profiles", {}).get(profile_id, data.get("generic_profiles", {}).get("humanoid", {}))

func _profile_id(enemy: Dictionary) -> String:
    if _is_boss(enemy) or bool(enemy.get("is_miniboss", false)):
        return "boss"
    var enemy_id := int(enemy.get("id", -1))
    for family_value in family_data.get("generic_enemy_ids", {}).keys():
        var family_id := str(family_value)
        if family_data.get("generic_enemy_ids", {}).get(family_id, []).has(enemy_id):
            return family_id
    return str(enemy.get("dismemberment_profile", "humanoid"))

func _encounter_id(enemy: Dictionary) -> String:
    for key in ["chapter_boss_id", "chapter_miniboss_id", "encounter_id"]:
        var value := str(enemy.get(key, ""))
        if value != "":
            return value
    return ""

func _is_boss(enemy: Dictionary) -> bool:
    return bool(enemy.get("boss", false)) or bool(enemy.get("is_boss", false)) or bool(enemy.get("deep_vestige_boss", false)) or str(enemy.get("chapter_boss_id", "")) != ""

func _has_part(parts: Array, part_id: String) -> bool:
    for value in parts:
        if str(value.get("id", "")) == part_id:
            return true
    return false

func _tags_overlap(left: Array, right: Array) -> bool:
    for value in left:
        if right.has(value):
            return true
    return false
