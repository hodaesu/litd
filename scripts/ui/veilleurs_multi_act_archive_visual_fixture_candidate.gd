extends RefCounted
class_name VeilleursMultiActArchiveVisualFixtureCandidate

const FIXTURES_PATH := "res://data/veilleurs/parallel_content/multi_act_archive_visual_fixtures_v1.json"
const VALID_PROFILES := ["phone", "tablet", "desktop", "controller"]

var fixtures: Dictionary = {}

func _init() -> void:
    fixtures = _load_dictionary(FIXTURES_PATH)

func validation_report() -> Dictionary:
    var errors: Array[String] = []
    var records: Array = fixtures.get("fixtures", [])
    var profiles: Dictionary = fixtures.get("profiles", {})
    if bool(fixtures.get("enabled_by_default", true)):
        errors.append("fixtures_must_remain_inactive")
    if records.size() != 8:
        errors.append("fixture_count:%d" % records.size())
    for profile_name: String in VALID_PROFILES:
        if not profiles.has(profile_name):
            errors.append("missing_profile:%s" % profile_name)
    var ids: Dictionary = {}
    for value: Variant in records:
        if not (value is Dictionary):
            errors.append("invalid_fixture_record")
            continue
        var record: Dictionary = value
        var chain_id := str(record.get("chain_id", ""))
        if chain_id.is_empty():
            errors.append("empty_chain_id")
        elif ids.has(chain_id):
            errors.append("duplicate_chain_id:%s" % chain_id)
        else:
            ids[chain_id] = true
        if str(record.get("knowledge_state_source", "")) != "PRESERVE_CURRENT_ARCHIVE_STATE":
            errors.append("knowledge_state_not_preserved:%s" % chain_id)
        if (record.get("cards", []) as Array).is_empty():
            errors.append("missing_cards:%s" % chain_id)
    var rules: Dictionary = fixtures.get("rules", {})
    if int(rules.get("touch_target_min_points", 0)) < 48:
        errors.append("touch_target_below_48")
    if bool(rules.get("long_press_required", true)):
        errors.append("long_press_required")
    if bool(rules.get("hover_required", true)):
        errors.append("hover_required")
    if not bool(rules.get("visual_fixture_may_not_upgrade_knowledge", false)):
        errors.append("knowledge_upgrade_guard_missing")
    return {
        "ok": errors.is_empty(),
        "errors": errors,
        "fixture_count": records.size(),
        "profiles": VALID_PROFILES.duplicate()
    }

func fixture_view(chain_id: String, profile_name: String, current_knowledge_state: String = "UNKNOWN") -> Dictionary:
    if not profile_name in VALID_PROFILES:
        return {"ok": false, "reason": "unknown_profile", "profile": profile_name}
    var record := _fixture_by_chain(chain_id)
    if record.is_empty():
        return {"ok": false, "reason": "unknown_chain", "chain_id": chain_id}
    var profile: Dictionary = ((fixtures.get("profiles", {}) as Dictionary).get(profile_name, {}) as Dictionary).duplicate(true)
    return {
        "ok": true,
        "chain_id": chain_id,
        "fixture_id": record.get("id", ""),
        "profile": profile_name,
        "layout": profile,
        "knowledge_state": current_knowledge_state,
        "knowledge_state_changed": false,
        "summary_mode": record.get("summary_mode", ""),
        "primary_sections": (record.get("primary_sections", []) as Array).duplicate(),
        "visible_sections": (record.get("expected_visible_sections", []) as Array).duplicate(),
        "cards": (record.get("cards", []) as Array).duplicate(true),
        "visual_assertions": (record.get("visual_assertions", []) as Array).duplicate(),
        "canonical_text_generated": false
    }

func fixture_ids() -> Array[String]:
    var result: Array[String] = []
    for value: Variant in fixtures.get("fixtures", []):
        if value is Dictionary:
            result.append(str((value as Dictionary).get("chain_id", "")))
    result.sort()
    return result

func _fixture_by_chain(chain_id: String) -> Dictionary:
    for value: Variant in fixtures.get("fixtures", []):
        if value is Dictionary and str((value as Dictionary).get("chain_id", "")) == chain_id:
            return (value as Dictionary).duplicate(true)
    return {}

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
