extends Node

signal traits_changed(character: Dictionary)
signal trait_evolved(character: Dictionary, negative_id: String, positive_id: String)

const PATH := "res://data/character_traits.json"

var data: Dictionary = {}
var by_id: Dictionary = {}

func _ready() -> void:
    reload()

func reload() -> bool:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    data = parsed if parsed is Dictionary else {}
    by_id.clear()
    for group: String in ["positives", "negatives"]:
        for value: Variant in data.get(group, []):
            if value is Dictionary:
                by_id[str((value as Dictionary).get("id", ""))] = value
    return not by_id.is_empty()

func prepare_character(character: Dictionary, seed_key: String = "", manual := false) -> void:
    if character.has("positive_traits") and character.has("negative_traits"):
        _ensure_progress(character)
        return
    character["trait_seed"] = int(character.get("trait_seed", _stable_seed(seed_key if seed_key != "" else str(character.get("id", character.get("name", "character"))))))
    character["positive_traits"] = []
    character["negative_traits"] = []
    character["trait_history"] = []
    _ensure_progress(character)
    if not manual:
        randomize_traits(character)

func randomize_traits(character: Dictionary) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = int(character.get("trait_seed", 1))
    var rules: Dictionary = data.get("random_rules", {})
    var positive_count := rng.randi_range(int(rules.get("minimum_positive", 1)), int(rules.get("maximum_positive", 2)))
    var negative_count := rng.randi_range(int(rules.get("minimum_negative", 0)), int(rules.get("maximum_negative", 2)))
    character["positive_traits"] = _draw_ids(data.get("positives", []), positive_count, rng)
    character["negative_traits"] = _draw_ids(data.get("negatives", []), negative_count, rng)
    traits_changed.emit(character)

func set_starter_traits(character: Dictionary, positive_ids: Array, negative_ids: Array) -> Dictionary:
    var max_positive := int(data.get("max_positive", 2))
    var max_negative := int(data.get("max_negative", 2))
    if positive_ids.size() > max_positive or negative_ids.size() > max_negative:
        return {"ok": false, "reason": "maximum_two_per_polarity"}
    if positive_ids.size() == 2 and negative_ids.is_empty():
        return {"ok": false, "reason": "two_positive_requires_one_negative"}
    if not _all_valid(positive_ids, "positive") or not _all_valid(negative_ids, "negative"):
        return {"ok": false, "reason": "invalid_trait"}
    character["positive_traits"] = positive_ids.duplicate()
    character["negative_traits"] = negative_ids.duplicate()
    character["traits_manually_chosen"] = true
    _ensure_progress(character)
    traits_changed.emit(character)
    return {"ok": true}

func add_exposure(character: Dictionary, exposure_id: String, amount: int = 1) -> Array:
    _ensure_progress(character)
    var progress: Dictionary = character.get("trait_exposure", {})
    progress[exposure_id] = maxi(0, int(progress.get(exposure_id, 0)) + amount)
    character["trait_exposure"] = progress
    var evolved: Array = []
    for negative_id: Variant in (character.get("negative_traits", []) as Array).duplicate():
        var trait: Dictionary = by_id.get(str(negative_id), {})
        var evolution: Variant = trait.get("evolution", null)
        if not evolution is Dictionary:
            continue
        if str(evolution.get("exposure", "")) != exposure_id:
            continue
        if int(progress.get(exposure_id, 0)) < int(evolution.get("threshold", 999)):
            continue
        var positive_id := str(evolution.get("evolves_to", ""))
        _evolve(character, str(negative_id), positive_id)
        evolved.append({"from": str(negative_id), "to": positive_id})
    return evolved

func record_enemy_encounter(characters: Array, enemies: Array, survived_only := true) -> Array:
    var exposures: Dictionary = {}
    var family_map: Dictionary = data.get("enemy_family_map", {})
    for enemy_value: Variant in enemies:
        if not enemy_value is Dictionary:
            continue
        var exposure := str(family_map.get(str((enemy_value as Dictionary).get("id", "")), ""))
        if exposure != "":
            exposures[exposure] = int(exposures.get(exposure, 0)) + 1
    var results: Array = []
    for character_value: Variant in characters:
        if not character_value is Dictionary:
            continue
        var character: Dictionary = character_value
        if survived_only and int(character.get("hp", 0)) <= 0:
            continue
        for exposure: Variant in exposures.keys():
            results.append_array(add_exposure(character, str(exposure), int(exposures[exposure])))
    return results

func modifiers(character: Dictionary, context: Dictionary = {}) -> Dictionary:
    var result: Dictionary = {}
    var ids: Array = []
    ids.append_array(character.get("positive_traits", []))
    ids.append_array(character.get("negative_traits", []))
    for trait_id: Variant in ids:
        var trait: Dictionary = by_id.get(str(trait_id), {})
        for key: Variant in (trait.get("effects", {}) as Dictionary).keys():
            var effect_key := str(key)
            if _effect_applies(effect_key, context):
                result[effect_key] = float(result.get(effect_key, 0.0)) + float(trait.get("effects", {}).get(key, 0.0))
    return result

func trait_names(character: Dictionary) -> Dictionary:
    return {
        "positive": _names(character.get("positive_traits", [])),
        "negative": _names(character.get("negative_traits", []))
    }

func _evolve(character: Dictionary, negative_id: String, positive_id: String) -> void:
    var negatives: Array = character.get("negative_traits", [])
    negatives.erase(negative_id)
    character["negative_traits"] = negatives
    var positives: Array = character.get("positive_traits", [])
    if not positives.has(positive_id):
        while positives.size() >= int(data.get("max_positive", 2)):
            var replaced: Variant = positives.pop_front()
            (character.get("trait_history", []) as Array).append({"replaced": str(replaced), "reason": "evolution"})
        positives.append(positive_id)
    character["positive_traits"] = positives
    (character.get("trait_history", []) as Array).append({"evolved_from": negative_id, "evolved_to": positive_id})
    trait_evolved.emit(character, negative_id, positive_id)
    traits_changed.emit(character)

func _draw_ids(source: Array, count: int, rng: RandomNumberGenerator) -> Array:
    var pool: Array = source.duplicate(true)
    var result: Array = []
    while result.size() < count and not pool.is_empty():
        var index := rng.randi_range(0, pool.size() - 1)
        result.append(str((pool.pop_at(index) as Dictionary).get("id", "")))
    return result

func _all_valid(ids: Array, polarity: String) -> bool:
    var seen: Dictionary = {}
    for value: Variant in ids:
        var trait: Dictionary = by_id.get(str(value), {})
        if trait.is_empty() or str(trait.get("polarity", "")) != polarity or seen.has(str(value)):
            return false
        seen[str(value)] = true
    return true

func _ensure_progress(character: Dictionary) -> void:
    if not character.has("trait_exposure"):
        character["trait_exposure"] = {}
    if not character.has("trait_history"):
        character["trait_history"] = []

func _names(ids: Array) -> Array:
    var result: Array = []
    for value: Variant in ids:
        result.append(str((by_id.get(str(value), {}) as Dictionary).get("name", str(value))))
    return result

func _effect_applies(effect_key: String, context: Dictionary) -> bool:
    if "_vs_arachnid" in effect_key or "_arachnid" in effect_key:
        return str(context.get("family", "")) == "arachnid"
    if "_darkness" in effect_key:
        return bool(context.get("darkness", false))
    if "_undead" in effect_key:
        return str(context.get("family", "")) == "undead"
    if "_blood" in effect_key:
        return bool(context.get("blood", false))
    if "_fire" in effect_key:
        return bool(context.get("fire", false))
    if "_confined" in effect_key:
        return bool(context.get("confined", false))
    return true

func _stable_seed(text: String) -> int:
    return abs(text.hash()) + 1
