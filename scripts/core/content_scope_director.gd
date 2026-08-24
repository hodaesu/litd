extends Node

const DATA_PATH := "res://data/content_scope.json"

var scope: Dictionary = {}

func _ready() -> void:
    reload()

func reload() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    scope = parsed if parsed is Dictionary else {}

func tier_for(feature_id: String) -> String:
    for tier_id_value: Variant in scope.get("tiers", {}).keys():
        var tier_id := str(tier_id_value)
        if feature_id in scope.get("tiers", {}).get(tier_id, {}).get("features", []):
            return tier_id
    return "unknown"

func is_first_map_visible(feature_id: String) -> bool:
    return feature_id in scope.get("first_map", {}).get("visible_features", [])

func is_first_map_background(feature_id: String) -> bool:
    return feature_id in scope.get("first_map", {}).get("background_features", [])

func is_first_map_deferred(feature_id: String) -> bool:
    return feature_id in scope.get("first_map", {}).get("deferred_features", [])

func active_first_map_roles() -> Array:
    return scope.get("first_map", {}).get("active_player_roles", ["scout"]).duplicate()

func first_map_trap_allowed(trap_type: String) -> bool:
    return trap_type in scope.get("first_map", {}).get("allowed_trap_types", [])

func farming_required_for_story() -> bool:
    return bool(scope.get("farming", {}).get("required_for_main_story", false))

func max_primary_choices() -> int:
    return int(scope.get("presentation", {}).get("max_primary_choices_per_screen", 4))

func system_exposure(feature_id: String, first_map: bool = true) -> String:
    if first_map:
        if is_first_map_visible(feature_id):
            return "visible"
        if is_first_map_background(feature_id):
            return "background"
        if is_first_map_deferred(feature_id):
            return "deferred"
    return tier_for(feature_id)
