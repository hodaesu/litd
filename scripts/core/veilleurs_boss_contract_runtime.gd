extends RefCounted

const PROFILE_PATH := "res://data/veilleurs/boss_contract_profiles.json"

var profiles: Dictionary = {}

func _init() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
    if parsed is Dictionary:
        profiles = parsed

func ishar_phase_1_transition(hp_ratio: float, crossing_methods: Array) -> Dictionary:
    var profile: Dictionary = profiles.get("ishar", {})
    var threshold := float(profile.get("phase_1_hp_ratio", 0.70))
    var required_methods := int(profile.get("distinct_crossing_methods", 2))
    var distinct: Array[String] = []
    for value: Variant in crossing_methods:
        var method := str(value)
        if method != "" and not distinct.has(method):
            distinct.append(method)
    var hp_ready := hp_ratio <= threshold
    var method_ready := distinct.size() >= required_methods
    return {
        "transition": hp_ready and method_ready,
        "hp_ready": hp_ready,
        "methods_ready": method_ready,
        "distinct_methods": distinct,
        "required_methods": required_methods,
        "threshold": threshold
    }

func ishar_record_family(memory: Dictionary, family: String) -> Dictionary:
    var state := memory.duplicate(true)
    var counts: Dictionary = state.get("family_counts", {})
    var previous := int(counts.get(family, 0))
    counts[family] = previous + 1
    state["family_counts"] = counts
    var profile: Dictionary = profiles.get("ishar", {})
    var step := float(profile.get("memory_repeat_step", 0.25))
    var cap := float(profile.get("memory_cap", 0.75))
    var adaptation := minf(cap, maxf(0.0, float(previous) * step))
    return {
        "state": state,
        "family": family,
        "previous_uses": previous,
        "adaptation": adaptation,
        "counter_strength": adaptation,
        "new_family_bypasses": previous == 0
    }

func orateur_echo(action: Dictionary, context: Dictionary = {}) -> Dictionary:
    var profile: Dictionary = profiles.get("orateur", {})
    var forbidden: Array = profile.get("echo_forbidden_fields", [])
    var echo := {
        "family": str(action.get("family", action.get("action_family", "unknown"))),
        "target_mode": str(action.get("target_mode", action.get("target", "same_pattern"))),
        "timing": str(action.get("timing", "delayed")),
        "tags": (action.get("tags", []) as Array).duplicate(true),
        "telegraphed": true,
        "structural_copy": true
    }
    for field_value: Variant in forbidden:
        echo.erase(str(field_value))
    var context_valid := bool(context.get("context_valid", true))
    return {
        "echo": echo,
        "can_resolve": context_valid,
        "failed_by_context": not context_valid,
        "copied_asset": false,
        "copied_weapon": false,
        "copied_stats": false
    }

func orateur_apply_silence(actions: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var profile: Dictionary = profiles.get("orateur", {})
    var collective_reliability := float(profile.get("silence_collective_reliability", 0.55))
    for value: Variant in actions:
        if not (value is Dictionary):
            continue
        var action: Dictionary = (value as Dictionary).duplicate(true)
        var collective := bool(action.get("requires_voice", false)) or str(action.get("coordination", "individual")) in ["collective", "verbal"]
        action["enabled"] = true
        action["reliability_multiplier"] = collective_reliability if collective else 1.0
        action["silence_affected"] = collective
        result.append(action)
    return result

func mother_redistribute_damage(amount: float, connections: Array) -> Dictionary:
    var profile: Dictionary = profiles.get("mere_des_veines", {})
    var active_visible: Array[Dictionary] = []
    for value: Variant in connections:
        if not (value is Dictionary):
            continue
        var connection: Dictionary = value
        if bool(connection.get("active", false)) and bool(connection.get("visible", false)):
            active_visible.append(connection.duplicate(true))
    var per_connection := float(profile.get("redistribution_per_connection", 0.20))
    var cap := float(profile.get("redistribution_cap", 0.60))
    var share := minf(cap, per_connection * float(active_visible.size()))
    var redistributed_total := amount * share
    var per_target := redistributed_total / float(active_visible.size()) if not active_visible.is_empty() else 0.0
    var transfers: Array[Dictionary] = []
    for connection: Dictionary in active_visible:
        transfers.append({
            "connection_id": str(connection.get("id", "")),
            "target_id": str(connection.get("target_id", "")),
            "damage": per_target
        })
    return {
        "incoming_damage": amount,
        "direct_damage": amount - redistributed_total,
        "redistributed_damage": redistributed_total,
        "active_visible_connections": active_visible.size(),
        "transfers": transfers
    }

func mother_mark_dead_zone(state: Dictionary, zone_id: String) -> Dictionary:
    var next := state.duplicate(true)
    var zones: Array = next.get("dead_zones", [])
    if zone_id != "" and not zones.has(zone_id):
        zones.append(zone_id)
    next["dead_zones"] = zones
    return next

func mother_advance_phase(state: Dictionary, next_phase: int) -> Dictionary:
    var next := state.duplicate(true)
    next["phase"] = next_phase
    next["dead_zones"] = (state.get("dead_zones", []) as Array).duplicate(true)
    return next

func porte_cendres_efface(elements: Array) -> Dictionary:
    var profile: Dictionary = profiles.get("porte_cendres", {})
    var irreversible: Array = profile.get("irreversible_kinds", [])
    var erased: Array[Dictionary] = []
    var protected: Array[Dictionary] = []
    for value: Variant in elements:
        if not (value is Dictionary):
            continue
        var element: Dictionary = (value as Dictionary).duplicate(true)
        var kind := str(element.get("kind", "temporary_mark"))
        var anchored := bool(element.get("anchored", false))
        if irreversible.has(kind) or anchored:
            protected.append(element)
        else:
            erased.append(element)
    return {"erased": erased, "protected": protected}

func procession_initial_state() -> Dictionary:
    var profile: Dictionary = profiles.get("porte_cendres", {})
    return {
        "route_width": int(profile.get("procession_initial_route", 4)),
        "announced": false,
        "defended": false,
        "pending_step": 0
    }

func procession_announce(state: Dictionary) -> Dictionary:
    var next := state.duplicate(true)
    var profile: Dictionary = profiles.get("porte_cendres", {})
    next["announced"] = true
    next["defended"] = false
    next["pending_step"] = int(profile.get("procession_step", 1))
    return next

func procession_defend(state: Dictionary, method: String) -> Dictionary:
    var next := state.duplicate(true)
    if bool(next.get("announced", false)) and method != "":
        next["defended"] = true
        next["defense_method"] = method
    return next

func procession_resolve(state: Dictionary) -> Dictionary:
    var next := state.duplicate(true)
    var profile: Dictionary = profiles.get("porte_cendres", {})
    var before := int(next.get("route_width", profile.get("procession_initial_route", 4)))
    var minimum := int(profile.get("procession_min_route", 1))
    var announced := bool(next.get("announced", false))
    var defended := bool(next.get("defended", false))
    var step := int(next.get("pending_step", profile.get("procession_step", 1)))
    var after := before
    if announced and not defended:
        after = maxi(minimum, before - step)
    next["route_width"] = after
    next["announced"] = false
    next["pending_step"] = 0
    return {
        "state": next,
        "route_before": before,
        "route_after": after,
        "reduced": after < before,
        "defended": defended,
        "was_announced": announced
    }

func copiste_copy_recent(actions: Array) -> Dictionary:
    var profile: Dictionary = profiles.get("copiste", {})
    var limit := int(profile.get("copy_recent_family_count", 3))
    var families: Array[String] = []
    for index in range(actions.size() - 1, -1, -1):
        if not (actions[index] is Dictionary):
            continue
        var action: Dictionary = actions[index]
        var family := str(action.get("family", action.get("action_family", "")))
        if family != "" and not families.has(family):
            families.append(family)
        if families.size() >= limit:
            break
    return {
        "families": families,
        "copied_player_stats": false,
        "copied_damage_values": false,
        "copy_kind": "structure_only"
    }

func copiste_start_correction_window() -> Dictionary:
    return {"used": 0, "window_open": true}

func copiste_correct(window: Dictionary, consequence: Dictionary) -> Dictionary:
    var profile: Dictionary = profiles.get("copiste", {})
    var maximum := int(profile.get("corrections_per_window", 1))
    var heavy: Array = profile.get("heavy_consequence_kinds", [])
    var kind := str(consequence.get("kind", "temporary_mark"))
    if not bool(window.get("window_open", false)):
        return {"corrected": false, "reason": "window_closed", "window": window.duplicate(true)}
    if int(window.get("used", 0)) >= maximum:
        return {"corrected": false, "reason": "window_budget_spent", "window": window.duplicate(true)}
    if heavy.has(kind) or bool(consequence.get("anchored", false)):
        return {"corrected": false, "reason": "heavy_consequence_protected", "window": window.duplicate(true)}
    var next := window.duplicate(true)
    next["used"] = int(next.get("used", 0)) + 1
    return {"corrected": true, "reason": "corrected_one_light_consequence", "window": next}

func copiste_palimpseste(light_stable: bool, chosen_version: String = "A") -> Dictionary:
    var profile: Dictionary = profiles.get("copiste", {})
    var count := int(profile.get("palimpsest_versions", 2))
    var versions: Array[Dictionary] = [
        {"id": "A", "anchor_ids": ["north", "center", "south"], "coherent": true},
        {"id": "B", "anchor_ids": ["north", "center", "south"], "coherent": true}
    ]
    if count < 2:
        versions.resize(maxi(1, count))
    var stable_version := chosen_version if light_stable and chosen_version in ["A", "B"] else ""
    return {
        "versions": versions,
        "version_count": versions.size(),
        "stable_version": stable_version,
        "light_stabilized": light_stable,
        "random_teleport": false,
        "shared_anchors": true
    }

func copiste_finale(observed_behaviors: Array, new_sequence: Array) -> Dictionary:
    var profile: Dictionary = profiles.get("copiste", {})
    var limit := int(profile.get("finale_behavior_count", 3))
    var counts: Dictionary = {}
    for value: Variant in observed_behaviors:
        var behavior := str(value)
        if behavior != "":
            counts[behavior] = int(counts.get(behavior, 0)) + 1
    var ranked: Array[String] = []
    for key_value: Variant in counts.keys():
        ranked.append(str(key_value))
    ranked.sort_custom(func(left: String, right: String) -> bool:
        var left_count := int(counts.get(left, 0))
        var right_count := int(counts.get(right, 0))
        if left_count == right_count:
            return left < right
        return left_count > right_count
    )
    if ranked.size() > limit:
        ranked.resize(limit)
    var novel: Array[String] = []
    for value: Variant in new_sequence:
        var behavior := str(value)
        if behavior != "" and not ranked.has(behavior) and not novel.has(behavior):
            novel.append(behavior)
    return {
        "synthesis": ranked,
        "novel_sequence": novel,
        "synthesis_broken": not novel.is_empty(),
        "copied_player_stats": false,
        "new_sequence_can_beat": not novel.is_empty()
    }
