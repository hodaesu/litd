extends RefCounted

const MAX_CHARACTER_LEVEL := 50
const DEFAULT_HERO_LEVEL := 3
const ROGUELIKE_RULES_PATH := "res://data/roguelike/roguelike_rules.json"

var _roguelike_rules: Dictionary = {}

func party_level_context(party_value: Array = []) -> Dictionary:
    var source: Array = party_value if not party_value.is_empty() else GameState.party
    var levels: Array[int] = []
    for hero_value in source:
        var hero: Dictionary = hero_value
        if int(hero.get("hp", 1)) <= 0:
            continue
        levels.append(clampi(int(hero.get("level", DEFAULT_HERO_LEVEL)), 1, MAX_CHARACTER_LEVEL))
    if levels.is_empty():
        return {"average": DEFAULT_HERO_LEVEL, "minimum": DEFAULT_HERO_LEVEL, "maximum": DEFAULT_HERO_LEVEL, "count": 0}
    var total := 0
    var minimum := MAX_CHARACTER_LEVEL
    var maximum := 1
    for level in levels:
        total += level
        minimum = mini(minimum, level)
        maximum = maxi(maximum, level)
    return {
        "average": clampi(int(round(float(total) / float(levels.size()))), 1, MAX_CHARACTER_LEVEL),
        "minimum": minimum,
        "maximum": maximum,
        "count": levels.size()
    }

func campaign_target_level(party_value: Array = []) -> int:
    return int(party_level_context(party_value).get("average", DEFAULT_HERO_LEVEL))

func campaign_reference_level(chapter_number: int, encounter_type: String) -> int:
    # Les ennemis ordinaires proviennent des gabarits de départ (niveau 3).
    # Les mini-boss et boss ont déjà des statistiques écrites par chapitre ; leur
    # niveau de référence suit donc la progression prévue de la campagne.
    if encounter_type in ["miniboss", "boss"]:
        return clampi(DEFAULT_HERO_LEVEL + maxi(0, chapter_number - 1) * 5, 1, MAX_CHARACTER_LEVEL)
    return DEFAULT_HERO_LEVEL

func apply_campaign_scaling(enemy: Dictionary, chapter_number: int, encounter_type: String, party_value: Array = []) -> Dictionary:
    if enemy.is_empty():
        return enemy
    var target_level := campaign_target_level(party_value)
    var reference_level := campaign_reference_level(chapter_number, encounter_type)
    var level_delta := target_level - reference_level
    var hp_multiplier := clampf(1.0 + float(level_delta) * 0.05, 0.35, 3.0)
    var damage_multiplier := clampf(1.0 + float(level_delta) * 0.035, 0.55, 2.25)
    var fear_multiplier := clampf(1.0 + float(level_delta) * 0.02, 0.65, 1.75)

    var base_hp := maxi(1, int(enemy.get("max_hp", enemy.get("hp", 1))))
    var scaled_hp := maxi(1, int(round(float(base_hp) * hp_multiplier)))
    enemy["hp"] = scaled_hp
    enemy["max_hp"] = scaled_hp

    var damage_value: Variant = enemy.get("damage", [1, 1])
    if damage_value is Array and (damage_value as Array).size() >= 2:
        var damage: Array = damage_value
        var low := maxi(1, int(round(float(damage[0]) * damage_multiplier)))
        var high := maxi(low, int(round(float(damage[1]) * damage_multiplier)))
        enemy["damage"] = [low, high]

    if enemy.has("fear"):
        enemy["fear"] = maxi(0, int(round(float(enemy.get("fear", 0)) * fear_multiplier)))

    enemy["level"] = target_level
    enemy["campaign_scaled"] = true
    enemy["campaign_reference_level"] = reference_level
    enemy["campaign_hp_multiplier"] = hp_multiplier
    enemy["campaign_damage_multiplier"] = damage_multiplier
    return enemy

func _load_roguelike_rules() -> Dictionary:
    if not _roguelike_rules.is_empty():
        return _roguelike_rules
    if not FileAccess.file_exists(ROGUELIKE_RULES_PATH):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROGUELIKE_RULES_PATH))
    if typeof(parsed) == TYPE_DICTIONARY:
        _roguelike_rules = parsed
    return _roguelike_rules

func dungeon_profile(dungeon_id: String = "") -> Dictionary:
    var data := _load_roguelike_rules()
    var selected_id := dungeon_id
    if selected_id == "":
        selected_id = str(data.get("default_dungeon_id", "first_veil_crypts"))
    var profiles: Dictionary = data.get("dungeons", {})
    var profile: Dictionary = profiles.get(selected_id, {}).duplicate(true)
    if profile.is_empty():
        return {}
    profile["id"] = selected_id
    return profile

func dungeon_entry_check(party_value: Array = [], dungeon_id: String = "") -> Dictionary:
    var profile := dungeon_profile(dungeon_id)
    if profile.is_empty():
        return {"allowed": false, "reason": "unknown_dungeon", "required_level": 1, "party_level": campaign_target_level(party_value)}
    var required_level := clampi(int(profile.get("required_level", 1)), 1, MAX_CHARACTER_LEVEL)
    var party_level := campaign_target_level(party_value)
    return {
        "allowed": party_level >= required_level,
        "reason": "ready" if party_level >= required_level else "level_too_low",
        "required_level": required_level,
        "party_level": party_level,
        "dungeon_id": str(profile.get("id", "")),
        "title": str(profile.get("title", "Donjon"))
    }

func dungeon_enemy_level(depth: int, room_type: String, dungeon_id: String = "") -> int:
    # Important : ce calcul ne consulte JAMAIS le niveau des héros.
    # Le niveau d'un donjon est fixé par son profil et sa profondeur.
    var profile := dungeon_profile(dungeon_id)
    if profile.is_empty():
        return DEFAULT_HERO_LEVEL
    var base_level := int(profile.get("enemy_base_level", DEFAULT_HERO_LEVEL))
    var per_depth := int(profile.get("enemy_level_per_depth", 0))
    var level := base_level + maxi(0, depth - 1) * per_depth
    if room_type == "elite":
        level += int(profile.get("elite_bonus_levels", 0))
    elif room_type == "boss":
        level += int(profile.get("boss_bonus_levels", 0))
    return clampi(level, 1, MAX_CHARACTER_LEVEL)

func apply_dungeon_scaling(enemy: Dictionary, depth: int, room_type: String, risk: Dictionary = {}, dungeon_id: String = "") -> Dictionary:
    if enemy.is_empty():
        return enemy
    var profile := dungeon_profile(dungeon_id)
    var fixed_level := dungeon_enemy_level(depth, room_type, dungeon_id)
    var reference_level := int(profile.get("template_reference_level", DEFAULT_HERO_LEVEL))
    var level_delta := fixed_level - reference_level
    var hp_multiplier := maxf(0.25, 1.0 + float(level_delta) * float(profile.get("hp_per_level", 0.07)))
    var damage_multiplier := maxf(0.25, 1.0 + float(level_delta) * float(profile.get("damage_per_level", 0.045)))
    var fear_multiplier := maxf(0.25, 1.0 + float(level_delta) * float(profile.get("fear_per_level", 0.025)))
    var danger_multiplier := maxf(0.25, float(risk.get("danger_multiplier", 1.0)))

    var base_hp := maxi(1, int(enemy.get("hp", 1)))
    var scaled_hp := maxi(1, int(round(float(base_hp) * hp_multiplier * danger_multiplier)))
    enemy["hp"] = scaled_hp
    enemy["max_hp"] = scaled_hp

    var damage_value: Variant = enemy.get("damage", [1, 1])
    if damage_value is Array and (damage_value as Array).size() >= 2:
        var damage: Array = damage_value
        var danger_damage_multiplier := 1.0 + (danger_multiplier - 1.0) * 0.65
        var low := maxi(1, int(round(float(damage[0]) * damage_multiplier * danger_damage_multiplier)))
        var high := maxi(low, int(round(float(damage[1]) * damage_multiplier * danger_damage_multiplier)))
        enemy["damage"] = [low, high]

    if enemy.has("fear"):
        enemy["fear"] = maxi(0, int(round(float(enemy.get("fear", 0)) * fear_multiplier)))

    enemy["level"] = fixed_level
    enemy["dungeon_fixed_level"] = true
    enemy["dungeon_id"] = str(profile.get("id", dungeon_id))
    enemy["dungeon_required_level"] = int(profile.get("required_level", 1))
    return enemy
