extends RefCounted

static func create_state(sources: Array) -> Dictionary:
    var normalized: Array[Dictionary] = []
    for value: Variant in sources:
        if not (value is Dictionary):
            continue
        var source: Dictionary = (value as Dictionary).duplicate(true)
        source["id"] = str(source.get("id", "light_%d" % normalized.size()))
        source["zone_id"] = str(source.get("zone_id", source.get("id", "")))
        source["active"] = bool(source.get("active", true))
        source["stable"] = bool(source.get("stable", false))
        source["destroyed"] = bool(source.get("destroyed", false))
        normalized.append(source)
    return {"sources": normalized, "revision": 0}

static func destroy_source(state: Dictionary, source_id: String) -> Dictionary:
    var sources: Array = state.get("sources", [])
    var changed := false
    for value: Variant in sources:
        if not (value is Dictionary):
            continue
        var source: Dictionary = value
        if str(source.get("id", "")) != source_id:
            continue
        source["active"] = false
        source["destroyed"] = true
        changed = true
        break
    if changed:
        state["revision"] = int(state.get("revision", 0)) + 1
    return {"ok": changed, "source_id": source_id, "state": state}

static func active_source_count(state: Dictionary) -> int:
    var count := 0
    for value: Variant in state.get("sources", []):
        if value is Dictionary and bool((value as Dictionary).get("active", false)):
            count += 1
    return count

static func stable_zone_count(state: Dictionary) -> int:
    var zones: Dictionary = {}
    for value: Variant in state.get("sources", []):
        if not (value is Dictionary):
            continue
        var source: Dictionary = value
        if not bool(source.get("active", false)) or not bool(source.get("stable", false)):
            continue
        zones[str(source.get("zone_id", source.get("id", "")))] = true
    return zones.size()

static func information_view(state: Dictionary, observation: Dictionary) -> Dictionary:
    var active := active_source_count(state)
    var stable := stable_zone_count(state)
    var precision := "qualitative"
    var confidence := 0.40
    if stable >= 2:
        precision = "confirmed"
        confidence = 1.0
    elif stable == 1:
        precision = "estimated"
        confidence = 0.72
    elif active > 0:
        precision = "partial"
        confidence = 0.55

    var result := {
        "precision": precision,
        "confidence": confidence,
        "stable_zones": stable,
        "active_sources": active,
        "confirmed_facts": (observation.get("confirmed_facts", {}) as Dictionary).duplicate(true),
        "qualitative": str(observation.get("qualitative", "Présence ou intention perceptible, détails incertains.")),
        "exact_values": {}
    }
    if precision == "confirmed":
        result["exact_values"] = (observation.get("exact_values", {}) as Dictionary).duplicate(true)
    elif precision == "estimated":
        var estimates: Dictionary = {}
        for key_value: Variant in (observation.get("exact_values", {}) as Dictionary).keys():
            estimates[str(key_value)] = "estimation"
        result["estimated_values"] = estimates
    return result

static func porte_cendres_phase1_condition(state: Dictionary) -> Dictionary:
    var stable := stable_zone_count(state)
    return {
        "recognized": stable >= 2,
        "stable_zone_count": stable,
        "required_stable_zones": 2,
        "condition_id": "porte_cendres_two_stable_light_zones"
    }
