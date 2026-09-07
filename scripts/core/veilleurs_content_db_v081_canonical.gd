extends "res://scripts/core/veilleurs_content_db_v07.gd"
class_name VeilleursContentDBV081Canonical

const CANONICAL_WATCHER_ULTIMATES_PATH := "res://data/veilleurs/v08/canonical_watcher_ultimates_12.json"

func _load_ultimates() -> void:
    ultimates_by_id.clear()
    ultimates_by_entity.clear()

    # v0.7 apporte 87 ultimes ennemis/boss valides, mais ses 12 lignes Veilleurs
    # appartiennent à un quatuor obsolète. Elles sont volontairement ignorées.
    var legacy_payload: Dictionary = _load_v07_dictionary(ULTIMATES_PATH)
    for value: Variant in legacy_payload.get("ultimates", []):
        if not (value is Dictionary):
            production_load_errors.append("ultimate_not_dictionary")
            continue
        var row: Dictionary = (value as Dictionary).duplicate(true)
        if str(row.get("entity_id", "")).begins_with("ENT_WATCHER_"):
            continue
        _index_canonical_or_production_ultimate(row)

    var watcher_payload: Dictionary = _load_v07_dictionary(CANONICAL_WATCHER_ULTIMATES_PATH)
    if int(watcher_payload.get("count", 0)) != 12:
        production_load_errors.append("canonical_watcher_ultimate_count")
    for value: Variant in watcher_payload.get("ultimates", []):
        if not (value is Dictionary):
            production_load_errors.append("canonical_watcher_ultimate_not_dictionary")
            continue
        _index_canonical_or_production_ultimate((value as Dictionary).duplicate(true))

func _index_canonical_or_production_ultimate(row: Dictionary) -> void:
    var ultimate_id := str(row.get("ultimate_id", ""))
    var entity_id := str(row.get("entity_id", ""))
    var slot := int(row.get("tree_slot", 0))
    if ultimate_id == "" or entity_id == "" or slot < 1 or slot > 3:
        production_load_errors.append("invalid_ultimate:%s" % ultimate_id)
        return
    if ultimates_by_id.has(ultimate_id):
        production_load_errors.append("duplicate_ultimate:%s" % ultimate_id)
        return
    if not watchers_by_id.has(entity_id) and not enemies_by_id.has(entity_id) and not bosses_by_id.has(entity_id):
        production_load_errors.append("unknown_ultimate_owner:%s" % entity_id)
        return
    ultimates_by_id[ultimate_id] = row
    if not ultimates_by_entity.has(entity_id):
        ultimates_by_entity[entity_id] = []
    (ultimates_by_entity[entity_id] as Array).append(row)
